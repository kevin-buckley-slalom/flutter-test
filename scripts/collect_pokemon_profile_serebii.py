#!/usr/bin/env python3
"""
Collect Pokémon profile information from Serebii for Generation 9 (Scarlet/Violet),
with fallback to Generation 8 (Sword/Shield) if the SV page returns 404.

Data captured per Pokémon form (when unique across forms):
- Gender Ratio
- Classification
- Height
- Weight
- Capture Rate

Identification of the target table:
Locate the dextable whose first <tr> contains the following headers:
  Name | Other Names | No. | Gender Ratio | Type

Notes on multiple values:
- Some pages group multiple forms together and fields (Classification, Height, etc.)
  can differ per form. For now, if a field has multiple distinct values on a page,
  record that base_name under `data/pokemon_profile_multiples.json` for case-by-case
  handling later. The per-form values are only assigned when a unique value exists.

Outputs:
- data/pokemon_profiles/<base_name>.json : map variant name -> profile fields + url + gen
- data/pokemon_profile_failures.json     : failures or errors
- data/pokemon_profile_multiples.json    : bases with fields that have multiple distinct values
"""

import json
import pathlib
import re
import time
from typing import Dict, List, Optional, Tuple

import requests
from bs4 import BeautifulSoup

# Reuse helpers and header style from the moves script
from scripts.collect_pokemon_moves_serebii import (
    HEADERS as REQUEST_HEADERS,
    fetch_html,
    make_pokemon_url,
    clean_text,
)

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
POKEMON_JSON = DATA_DIR / "pokemon.json"

# Fields we care about within the target dextable
PROFILE_LABELS = {
    "Classification": "classification",
    "Height": "height",
    "Weight": "weight",
    "Capture Rate": "capture_rate",
}


def extract_form_order(soup: BeautifulSoup) -> List[str]:
    """
    Extract the ordered list of form titles from the sprite-select div.
    Returns list like: ['Regular Form', 'Paldean Form', 'Blaze Breed', 'Aqua Breed']
    """
    form_titles = []
    for link in soup.find_all('a', class_='sprite-select'):
        title = link.get('title', '').strip()
        if title:
            form_titles.append(title)
    return form_titles


def split_height(raw_height: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Split height into imperial and metric.
    Uses regex so it tolerates nested tables (Standard/Min/Max/Alpha) and multi-form
    values separated by " / ". For multi-form values, we keep the slash-joined list so
    later logic can map them to form order.
    """
    text = raw_height.replace('\xa0', ' ').replace('\n', ' ').strip()
    imperial_matches = re.findall(r"\d+'(?:\d{2})\"", text)
    metric_matches = re.findall(r"\d+(?:\.\d+)?m", text)

    imperial = None
    metric = None

    if ' / ' in raw_height and len(imperial_matches) > 1:
        imperial = ' / '.join(imperial_matches)
    elif imperial_matches:
        imperial = imperial_matches[0]

    if ' / ' in raw_height and len(metric_matches) > 1:
        metric = ' / '.join(metric_matches)
    elif metric_matches:
        metric = metric_matches[0]

    return imperial, metric


def split_weight(raw_weight: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Split weight into imperial and metric.
    Handles nested Standard/Min/Max/Alpha rows and multi-form values separated by
    " / ".
    """
    text = raw_weight.replace('\xa0', ' ').replace('\n', ' ').strip()
    imperial_matches = re.findall(r"\d+(?:\.\d+)?lbs", text)
    metric_matches = re.findall(r"\d+(?:\.\d+)?kg", text)

    imperial = None
    metric = None

    if ' / ' in raw_weight and len(imperial_matches) > 1:
        imperial = ' / '.join(imperial_matches)
    elif imperial_matches:
        imperial = imperial_matches[0]

    if ' / ' in raw_weight and len(metric_matches) > 1:
        metric = ' / '.join(metric_matches)
    elif metric_matches:
        metric = metric_matches[0]

    return imperial, metric


def parse_multiple_values(value_str: str) -> List[str]:
    """
    Split a string like '194.9lbs / 253.5lbs / 187.4lbs' into individual values.
    Returns: ['194.9lbs', '253.5lbs', '187.4lbs']
    """
    return [v.strip() for v in value_str.split(' / ') if v.strip()]


def validate_and_clean_profile(profile: Dict, variant_name: str) -> Tuple[Dict, Dict]:
    """
    Validate profile fields and replace invalid values with None.
    Returns: (cleaned_profile, validation_failures)
    
    Validation rules:
    - classification: string, non-empty
    - capture_rate: int
    - height_imperial: format X'YY" or similar (feet/inches)
    - height_metric: format X.Xm (number followed by 'm')
    - weight_imperial: format X.Xlbs (number followed by 'lbs')
    - weight_metric: format X.Xkg (number followed by 'kg')
    - gender_ratio: dict with male/female as valid floats (0-100)
    """
    cleaned = {}
    failures = {}
    
    # Classification validation
    if 'classification' in profile:
        val = profile['classification']
        if isinstance(val, str) and val.strip():
            cleaned['classification'] = val
        else:
            failures['classification'] = f"Invalid: {repr(val)}"
            cleaned['classification'] = None
    
    # Capture rate validation
    if 'capture_rate' in profile:
        val = profile['capture_rate']
        if isinstance(val, int) or (isinstance(val, str) and val.isdigit()):
            cleaned['capture_rate'] = int(val)
        elif isinstance(val, str):
            # Sometimes Serebii lists multiple games: "235 (SV)204 (Legends: Z-A)".
            # Prefer the first integer and ignore the rest.
            if any(token in val for token in ["'", '"', 'm', 'lbs', 'kg']):
                failures['capture_rate'] = f"Invalid: {repr(val)}"
                cleaned['capture_rate'] = None
            else:
                match = re.search(r"\d+", val)
                if match:
                    cleaned['capture_rate'] = int(match.group(0))
                else:
                    failures['capture_rate'] = f"Invalid: {repr(val)}"
                    cleaned['capture_rate'] = None
        else:
            failures['capture_rate'] = f"Invalid: {repr(val)}"
            cleaned['capture_rate'] = None
    
    # Height imperial validation: X'YY" format (allow slash-separated multiples)
    if 'height_imperial' in profile:
        val = profile['height_imperial']
        if isinstance(val, str):
            if ' / ' in val:
                heights = [h.strip() for h in val.split(' / ')]
                if all(re.match(r"^\d+['\"]?\d{2}[\"']?$", h.replace(' ', '')) for h in heights):
                    cleaned['height_imperial'] = val
                else:
                    failures['height_imperial'] = f"Invalid format: {repr(val)}"
                    cleaned['height_imperial'] = None
            elif re.match(r"^\d+['\"]?\d{2}[\"']?$", val.replace(' ', '')):
                cleaned['height_imperial'] = val
            else:
                failures['height_imperial'] = f"Invalid format: {repr(val)}"
                cleaned['height_imperial'] = None
        else:
            failures['height_imperial'] = f"Invalid format: {repr(val)}"
            cleaned['height_imperial'] = None
    
    # Height metric validation: X.Xm format (allow slash-separated multiples)
    if 'height_metric' in profile:
        val = profile['height_metric']
        if isinstance(val, str):
            if ' / ' in val:
                heights = [h.strip() for h in val.split(' / ')]
                if all(re.match(r"^\d+(?:\.\d+)?m$", h.strip()) for h in heights):
                    cleaned['height_metric'] = val
                else:
                    failures['height_metric'] = f"Invalid format: {repr(val)}"
                    cleaned['height_metric'] = None
            elif re.match(r"^\d+(?:\.\d+)?m$", val.strip()):
                cleaned['height_metric'] = val
            else:
                failures['height_metric'] = f"Invalid format: {repr(val)}"
                cleaned['height_metric'] = None
        else:
            failures['height_metric'] = f"Invalid format: {repr(val)}"
            cleaned['height_metric'] = None
    
    # Weight imperial validation: X.Xlbs format
    if 'weight_imperial' in profile:
        val = profile['weight_imperial']
        if isinstance(val, str):
            # Handle multiple values separated by /
            if ' / ' in val:
                weights = [w.strip() for w in val.split(' / ')]
                if all(re.match(r"^\d+(?:\.\d+)?lbs$", w) for w in weights):
                    cleaned['weight_imperial'] = val
                else:
                    failures['weight_imperial'] = f"Invalid format: {repr(val)}"
                    cleaned['weight_imperial'] = None
            elif re.match(r"^\d+(?:\.\d+)?lbs$", val.strip()):
                cleaned['weight_imperial'] = val
            else:
                failures['weight_imperial'] = f"Invalid format: {repr(val)}"
                cleaned['weight_imperial'] = None
        else:
            failures['weight_imperial'] = f"Invalid: {repr(val)}"
            cleaned['weight_imperial'] = None
    
    # Weight metric validation: X.Xkg format
    if 'weight_metric' in profile:
        val = profile['weight_metric']
        if isinstance(val, str):
            # Handle multiple values separated by /
            if ' / ' in val:
                weights = [w.strip() for w in val.split(' / ')]
                if all(re.match(r"^\d+(?:\.\d+)?kg$", w) for w in weights):
                    cleaned['weight_metric'] = val
                else:
                    failures['weight_metric'] = f"Invalid format: {repr(val)}"
                    cleaned['weight_metric'] = None
            elif re.match(r"^\d+(?:\.\d+)?kg$", val.strip()):
                cleaned['weight_metric'] = val
            else:
                failures['weight_metric'] = f"Invalid format: {repr(val)}"
                cleaned['weight_metric'] = None
        else:
            failures['weight_metric'] = f"Invalid: {repr(val)}"
            cleaned['weight_metric'] = None
    
    # Gender ratio validation
    if 'gender_ratio' in profile:
        val = profile['gender_ratio']
        if isinstance(val, dict):
            male = val.get('male')
            female = val.get('female')
            valid = True
            
            # Check male
            if male is not None:
                if not isinstance(male, (int, float)) or male < 0 or male > 100:
                    valid = False
            
            # Check female
            if female is not None:
                if not isinstance(female, (int, float)) or female < 0 or female > 100:
                    valid = False
            
            if valid and (male is not None or female is not None):
                cleaned['gender_ratio'] = val
            else:
                failures['gender_ratio'] = f"Invalid values: male={repr(male)}, female={repr(female)}"
                cleaned['gender_ratio'] = None
        else:
            failures['gender_ratio'] = f"Invalid: {repr(val)}"
            cleaned['gender_ratio'] = None
    
    return cleaned, failures


def detect_generation(url: str) -> int:
    if "pokedex-sv" in url:
        return 9
    elif "pokedex-swsh" in url:
        return 8
    return 9


def find_target_table(soup: BeautifulSoup) -> Optional[BeautifulSoup]:
    """Find the dextable whose first row matches the specified headers."""
    for table in soup.find_all("table", class_="dextable"):
        rows = table.find_all("tr")
        if not rows:
            continue
        first = rows[0]
        header_cells = [clean_text(c.get_text()) for c in first.find_all(["td", "th"])]
        if header_cells[:5] == ["Name", "Other Names", "No.", "Gender Ratio", "Type"]:
            return table
    return None


def extract_gender_ratio(table: BeautifulSoup) -> List[Tuple[Optional[float], Optional[float]]]:
    """
    Extract gender ratio from the table. Gender ratio appears in a nested table structure:
    <td class="fooinfo"><table>...<tr><td>Male ♂:</td><td>100%</td></tr>...</table></td>
    
    When text is extracted, it comes as: 'Male ♂:100%Female ♀:0%'
    Returns list containing a single (male%, female%) tuple.
    """
    import re
    
    # Look for td with class="fooinfo" which contains the gender ratio nested table
    for cell in table.find_all("td", class_="fooinfo"):
        # Get all text from this cell
        text = clean_text(cell.get_text())
        
        # Check if this cell contains gender ratio (has both Male and Female symbols)
        if '♂' not in text or '♀' not in text:
            continue
        
        male_pct = None
        female_pct = None
        
        # Use regex to find percentages near male/female symbols
        # Pattern: (number)% near ♂ or ♀
        male_match = re.search(r'♂[:\s]*(\d+(?:\.\d+)?)', text)
        female_match = re.search(r'♀[:\s]*(\d+(?:\.\d+)?)', text)
        
        if male_match:
            male_pct = float(male_match.group(1))
        if female_match:
            female_pct = float(female_match.group(1))
        
        if male_pct is not None or female_pct is not None:
            return [(male_pct, female_pct)]
    
    return []


def extract_profile_fields(table: BeautifulSoup, form_order: List[str]) -> Dict[str, any]:
    """
    Extract profile fields from the table, handling multiple forms.
    Returns a dict with:
    - Single values: field_key -> value
    - Multiple values: field_key -> {form_title: value}

    Serebii structures profile data as:
    Row N: ['Classification', 'Height', 'Weight', 'Capture Rate', 'Base Egg Steps']
    Row N+1: ['Wild Bull Pokémon', '4\'07"...', '194.9lbs...', '45', '2,560...']
    
    We find the label row, then extract values from the next row using cell indices.
    """
    result = {}
    rows = table.find_all("tr")
    
    for i, row in enumerate(rows):
        tds = row.find_all("td", recursive=False)
        if not tds:
            continue
        texts = [clean_text(td.get_text()) for td in tds]
        if not texts:
            continue
        
        # Look for row that starts with "Classification" and has our labels
        if "Classification" in texts[0] and i + 1 < len(rows):
            # This is the label row; next row should have values
            value_row = rows[i + 1]
            value_tds = value_row.find_all("td", recursive=False)
            value_texts = [clean_text(td.get_text()) for td in value_tds]
            
            # Map labels to their cell indices
            label_to_idx = {}
            for j, label_text in enumerate(texts):
                for label, key in PROFILE_LABELS.items():
                    if label in label_text:
                        label_to_idx[key] = j
            
            # Extract values for each label
            for key, idx in label_to_idx.items():
                if idx < len(value_texts):
                    raw_val = value_texts[idx]
                    if not raw_val:
                        continue
                    
                    # Special handling for height and weight
                    if key == 'height':
                        imperial, metric = split_height(raw_val)
                        if imperial:
                            result['height_imperial'] = imperial
                        if metric:
                            result['height_metric'] = metric
                    elif key == 'weight':
                        imperial, metric = split_weight(raw_val)
                        if imperial:
                            result['weight_imperial'] = imperial
                        if metric:
                            result['weight_metric'] = metric
                    else:
                        result[key] = raw_val
    
    # Now check if any field has multiple values (separated by ' / ')
    # If so, split them and match to form_order
    for field_key in list(result.keys()):
        value = result[field_key]
        if isinstance(value, str) and ' / ' in value:
            values = parse_multiple_values(value)
            if len(values) > 1 and len(values) == len(form_order):
                # Create a mapping of form_title -> value
                result[field_key] = {form_order[i]: values[i] for i in range(len(values))}
    
    return result


def choose_unique(values: List[str]) -> Optional[str]:
    """Return the unique value if the list contains exactly one distinct value."""
    if not values:
        return None
    # filter out empties
    filtered = [v for v in values if v]
    uniq = list(dict.fromkeys(filtered))
    if len(uniq) == 1:
        return uniq[0]
    return None


def create_form_to_variant_map(form_order: List[str], variant_names: List[str], base_name: str) -> Dict[str, str]:
    """
    Create a mapping from form titles to variant names.
    Returns dict: form_title -> variant_name
    """
    mapping = {}
    used_variants = set()
    
    # First pass: handle "Regular Form" and exact matches
    for form_title in form_order:
        form_lower = form_title.lower()
        
        # Handle "Regular Form" -> base name
        if form_lower == "regular form" or form_lower == "normal form":
            for variant in variant_names:
                if variant == base_name:
                    mapping[form_title] = variant
                    used_variants.add(variant)
                    break
            continue
        
        # Check for exact or close matches
        for variant in variant_names:
            if variant in used_variants:
                continue
            variant_lower = variant.lower()
            
            # Extract meaningful words from form_title (excluding "Form")
            form_words = [w for w in form_lower.replace("form", "").split() if w]
            
            # Check if all form words appear in variant name
            if all(w in variant_lower for w in form_words):
                mapping[form_title] = variant
                used_variants.add(variant)
                break
    
    # Second pass: assign unmapped forms to unused variants
    for form_title in form_order:
        if form_title not in mapping:
            for variant in variant_names:
                if variant not in used_variants:
                    mapping[form_title] = variant
                    used_variants.add(variant)
                    break
    
    return mapping


def collect_profile_for_base(base_name: str, variant_names: List[str]) -> Dict:
    """
    Fetch and parse profile info for a base name, assign to variants.
    Returns mapping variant_name -> profile dict and auxiliary info.
    """
    # Try SV first, then fallback to SWSH
    urls = [make_pokemon_url(base_name), make_pokemon_url(base_name).replace("pokedex-sv", "pokedex-swsh")]
    soup = None
    used_url = None
    gen = None
    for url in urls:
        try:
            soup = fetch_html(url)
            used_url = url
            gen = detect_generation(url)
            break
        except requests.exceptions.HTTPError as e:
            if e.response is not None and e.response.status_code == 404:
                continue
            else:
                raise
    if soup is None:
        raise requests.exceptions.HTTPError(f"404 Not Found for {base_name} (SV and SWSH)")

    # Extract form order from sprite-select div
    form_order = extract_form_order(soup)
    
    table = find_target_table(soup)
    if not table:
        # Could not find target table
        return {
            "data": {},
            "url": used_url,
            "generation": gen,
            "form_order": form_order,
            "multiples": {},
            "note": "Target dextable not found"
        }

    # Extract values
    gender_pairs = extract_gender_ratio(table)
    fields = extract_profile_fields(table, form_order)

    # Create form-to-variant mapping
    form_to_variant = create_form_to_variant_map(form_order, variant_names, base_name)

    multiples = {}

    # Handle gender ratio
    unique_gender = gender_pairs[0] if len(gender_pairs) == 1 else None
    if unique_gender is None and len(gender_pairs) > 1:
        multiples["gender_ratio"] = [
            {"male": m, "female": f} for (m, f) in gender_pairs if m is not None or f is not None
        ]

    # Build result per variant
    result = {}
    validation_failures = {}
    
    for variant in variant_names:
        profile = {}
        
        # Auto-set gender ratio for Male/Female variants
        variant_lower = variant.lower()
        if "male" in variant_lower and "female" not in variant_lower:
            profile["gender_ratio"] = {"male": 100.0, "female": 0.0}
        elif "female" in variant_lower:
            profile["gender_ratio"] = {"male": 0.0, "female": 100.0}
        elif unique_gender is not None:
            m, f = unique_gender
            profile["gender_ratio"] = {"male": m, "female": f}
        
        # Apply profile fields
        for field_key, field_value in fields.items():
            if isinstance(field_value, dict):
                # Multiple values per form - find value for this variant
                for form_title, val in field_value.items():
                    if form_to_variant.get(form_title) == variant:
                        if field_key == 'capture_rate':
                            try:
                                profile[field_key] = int(val)
                            except:
                                profile[field_key] = val
                        else:
                            profile[field_key] = val
                        break
                # If no per-form value found, mark as multiple
                if field_key not in profile:
                    if field_key not in multiples:
                        multiples[field_key] = field_value
            else:
                # Single value for all forms
                if field_key == 'capture_rate':
                    try:
                        profile[field_key] = int(field_value)
                    except:
                        profile[field_key] = field_value
                else:
                    profile[field_key] = field_value
        
        # Validate and clean the profile
        cleaned_profile, failures = validate_and_clean_profile(profile, variant)
        result[variant] = {
            "profile": cleaned_profile,
            "url": used_url,
            "gen": gen,
        }
        
        if failures:
            validation_failures[variant] = failures

    return {"data": result, "url": used_url, "generation": gen, "form_order": form_order, "multiples": multiples, "validation_failures": validation_failures}


def main():
    """Main function to collect Pokemon profile data from Serebii and update pokemon.json."""
    print("Loading Pokemon data...")
    with open(POKEMON_JSON, "r", encoding="utf-8") as f:
        pokemon_list = json.load(f)

    # Create a lookup map: name -> pokemon object
    pokemon_by_name = {p["name"]: p for p in pokemon_list}

    # Group by base_name to get variants on same page
    pokemon_by_base: Dict[str, List[str]] = {}
    for p in pokemon_list:
        base = p.get("base_name")
        name = p.get("name")
        if base:
            pokemon_by_base.setdefault(base, []).append(name)

    print(f"Found {len(pokemon_by_base)} unique Pokemon base forms")

    successful = 0
    failed: List[Dict] = []
    errors: List[Dict] = []
    multiples_summary: List[Dict] = []
    validation_issues: List[Dict] = []
    profiles_applied = 0

    for i, (base_name, variants) in enumerate(pokemon_by_base.items(), 1):
        print(f"[{i}/{len(pokemon_by_base)}] Fetching profile for: {base_name}")
        try:
            result = collect_profile_for_base(base_name, variants)
            data = result["data"]
            if data:
                # Update pokemon.json entries for each variant
                for variant_name, profile_data in data.items():
                    if variant_name in pokemon_by_name:
                        # Add profile fields to the pokemon object
                        profile = profile_data["profile"]
                        for key, value in profile.items():
                            pokemon_by_name[variant_name][key] = value
                        profiles_applied += 1
                successful += 1
                print(f"  ✓ Updated: {', '.join(list(data.keys()))}")
            else:
                failed.append({
                    "base_name": base_name,
                    "variants": variants,
                    "reason": "No profile data found",
                    "url": result.get("url"),
                })
                print("  ✗ No profile data found")

            # Record multiples for case-by-case processing
            if result.get("multiples"):
                multiples_summary.append({
                    "base_name": base_name,
                    "multiples": result["multiples"],
                    "url": result.get("url"),
                })

            # Record validation failures
            if result.get("validation_failures"):
                validation_issues.append({
                    "base_name": base_name,
                    "validation_failures": result["validation_failures"],
                    "url": result.get("url"),
                })
                for variant, failures in result["validation_failures"].items():
                    print(f"  ⚠ Validation issues for {variant}: {', '.join(failures.keys())}")

            time.sleep(0.3)
        except requests.exceptions.HTTPError as e:
            failed.append({
                "base_name": base_name,
                "variants": variants,
                "reason": "404 Not Found" if getattr(e, "response", None) and e.response.status_code == 404 else str(e),
                "url": make_pokemon_url(base_name),
            })
            print(f"  ✗ Error: {e}")
        except Exception as e:
            errors.append({
                "base_name": base_name,
                "variants": variants,
                "error": str(e),
                "url": make_pokemon_url(base_name),
            })
            print(f"  ✗ Error: {e}")

    # Save updated pokemon.json
    print(f"\n✓ Saving updated pokemon.json with {profiles_applied} profiles...")
    with open(POKEMON_JSON, "w", encoding="utf-8") as f:
        json.dump(pokemon_list, f, indent=2, ensure_ascii=False)
    print(f"✓ Saved to {POKEMON_JSON}")

    # Save failure and multiples summaries
    if failed or errors or validation_issues:
        failures_file = DATA_DIR / "pokemon_profile_failures.json"
        with open(failures_file, "w", encoding="utf-8") as f:
            json.dump({
                "failed": failed,
                "errors": errors,
                "validation_issues": validation_issues,
                "summary": {
                    "total_failed": len(failed),
                    "total_errors": len(errors),
                    "total_validation_issues": len(validation_issues),
                }
            }, f, indent=2, ensure_ascii=False)
        print(f"✓ Saved failures to {failures_file}")

    if multiples_summary:
        multiples_file = DATA_DIR / "pokemon_profile_multiples.json"
        with open(multiples_file, "w", encoding="utf-8") as f:
            json.dump({
                "multiples": multiples_summary,
                "summary": {"total": len(multiples_summary)}
            }, f, indent=2, ensure_ascii=False)
        print(f"✓ Saved multiples to {multiples_file}")

    print("\n=== Summary ===")
    print(f"✓ Successful: {successful}/{len(pokemon_by_base)} Pokemon")
    print(f"✓ Profiles applied: {profiles_applied}")
    print(f"✗ Failed (404 or no data): {len(failed)}")
    if failed[:5]:
        print(f"  Examples: {', '.join([f['base_name'] for f in failed[:5]])}")
    print(f"✗ Errors: {len(errors)}")
    if errors[:3]:
        for err_info in errors[:3]:
            print(f"  {err_info['base_name']}: {err_info['error'][:50]}")
    print(f"⚠ Validation issues: {len(validation_issues)}")
    if validation_issues[:3]:
        for val_info in validation_issues[:3]:
            issue_summary = ", ".join([f"{v}: {', '.join(f.keys())}" for v, f in val_info['validation_failures'].items()])
            print(f"  {val_info['base_name']}: {issue_summary[:60]}")


if __name__ == "__main__":
    main()
