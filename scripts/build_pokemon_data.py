"""
Build a consolidated Pokémon dataset from the complete stats table.

Sources:
- Stats table: https://pokemondb.net/pokedex/all (contains all Pokémon including variants)

Outputs:
- data/pokemon.json : list of Pokémon dicts with number, name, base_name, variant, generation, types, stats
- data/pokemon_by_number.json : map number -> list of Pokémon (handles variants)
- data/pokemon_by_name.json : map lowercase name -> Pokémon
- data/pokemon_by_base_name.json : map lowercase base_name -> list of variants

Run:
    python scripts/build_pokemon_data.py

Dependencies:
    pip install requests beautifulsoup4
"""

from __future__ import annotations

import json
import pathlib
import re
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Tuple

import requests
from bs4 import BeautifulSoup

STATS_URL = "https://pokemondb.net/pokedex/all"

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"


@dataclass
class Stats:
    total: int
    hp: int
    attack: int
    defense: int
    sp_atk: int
    sp_def: int
    speed: int


@dataclass
class Pokemon:
    number: int
    name: str
    base_name: str  # Name without variant prefix (e.g., "Rattata" for "Alolan Rattata")
    variant: Optional[str]  # Variant name like "Alolan", "Galarian", "Hisuian", or None for base form
    generation: int
    types: List[str]
    stats: Stats


def fetch_html(url: str) -> BeautifulSoup:
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return BeautifulSoup(response.text, "html.parser")


def extract_variant(name: str) -> Tuple[str, Optional[str]]:
    """
    Extract variant from Pokémon name.
    Returns (base_name, variant) where variant is None for base forms.
    
    Examples:
        "Rattata" -> ("Rattata", None)
        "Alolan Rattata" -> ("Rattata", "Alolan")
        "Mega Charizard X" -> ("Charizard", "Mega X")
        "Ogerpon (Teal Mask)" -> ("Ogerpon", "Teal Mask")
        "Terapagos (Normal Form)" -> ("Terapagos", "Normal Form")
        "Urshifu Single Strike Style" -> ("Urshifu", "Single Strike Style")
    """
    name = name.strip()
    
    # Handle parentheses format: "BaseName (Form Name)"
    paren_match = re.match(r"^(.+?)\s*\((.+?)\)\s*$", name)
    if paren_match:
        base_name = paren_match.group(1).strip()
        variant = paren_match.group(2).strip()
        return (base_name, variant)
    
    # Handle prefix variants (Mega, regional forms) - order matters (more specific first)
    prefix_patterns = [
        (r"^(Mega\s+X|Mega\s+Y)\s+(.+)$", True),  # Mega X/Y first (more specific)
        (r"^(Mega)\s+(.+)$", True),
        (r"^(Alolan|Galarian|Hisuian|Paldean)\s+(.+)$", True),
    ]
    
    for pattern, prefix_is_variant in prefix_patterns:
        match = re.match(pattern, name, re.IGNORECASE)
        if match:
            if prefix_is_variant:
                variant = match.group(1).strip()
                base_name = match.group(2).strip()
            else:
                base_name = match.group(1).strip()
                variant = match.group(2).strip()
            return (base_name, variant)
    
    # Handle cases where base name appears first, then variant text that includes the base name
    # Pattern: "BaseName VariantText" where VariantText starts with variant prefix and contains base name
    # Examples: "Venusaur Mega Venusaur", "Charizard Mega Charizard X"
    # This happens when HTML has link text + following text
    variant_prefixes = [
        "Mega X", 
        "Mega Y", 
        "Mega", 
        "Alolan", 
        "Galarian", 
        "Hisuian", 
        "Paldean",
        "Partner",
        "Primal",
        "White",
        "Black",
    ]
    
    for prefix in variant_prefixes:
        if name.lower().startswith("darmanitan"):
            break  # Special case handled in suffix patterns below

        # Pattern: "BaseName Prefix ..." where the rest contains the base name
        # Split the name at the variant prefix
        prefix_pattern = rf"\s+{re.escape(prefix)}\s+"
        if re.search(prefix_pattern, name, re.IGNORECASE):
            parts = re.split(prefix_pattern, name, 1, flags=re.IGNORECASE)
            if len(parts) == 2:
                potential_base = parts[0].strip()
                variant_text = f"{prefix} {parts[1].strip()}"
                
                # Check if variant_text contains the base name (confirming it's a duplicate pattern)
                if potential_base.lower() in variant_text.lower():
                    base_name = potential_base
                    variant = variant_text
                    return (base_name, variant)
    
    # Handle suffix variants
    suffix_patterns = [
        r"^(.+?)\s+(Single Strike Style|Rapid Strike Style)$",
        r"^(.+?)\s+(Dawn Wings Necrozma|Dusk Mane Necrozma|Ultra Necrozma|Ice Rider|Shadow Rider)$",
        r"^(.+?)\s+(Amped Form|Low Key Form)$",
        r"^(.+?)\s+(Baile Style|Pom-Pom Style|Pa'u Style|Sensu Style)$",
        r"^(.+?)\s+(Red-Striped|Blue-Striped)$",
        r"^(.+?)\s+(Normal Form|Terastal Form|Stellar Form)$",
        r"^(.+?)\s+(10% Forme|50% Forme|Complete Forme)$",
        r"^(.+?)\s+(Combat Breed|Blaze Breed|Aqua Breed)$",
        r"^(.+?)\s+(Sunny Form|Rainy Form|Snowy Form)$",
        r"^(.+?)\s+(Normal Forme|Attack Forme|Defense Forme|Speed Forme)$",
        r"^(.+?)\s+(Plant Cloak|Sandy Cloak|Trash Cloak)$",
        r"^(.+?)\s+(Altered Forme|Origin Forme)$",
        r"^(.+?)\s+(Land Forme|Sky Forme)$",
        r"^(.+?)\s+(Red-Striped Form|Blue-Striped Form|White-Striped Form)$",
        r"^(.+?)\s+(Ash-Greninja|Bloodmoon)$",
        r"^(.+?)\s+(Incarnate Forme|Therian Forme)$",
        r"^(.+?)\s+(Ordinary Form|Resolute Form)$",
        r"^(.+?)\s+(Aria Forme|Pirouette Forme)$",
        r"^(.+?)\s+(Male|Female)$",
        r"^(.+?)\s+(Shield Forme|Blade Forme)$",
        r"^(.+?)\s+(Average Size|Small Size|Large Size|Super Size)$",
        r"^(.+?)\s+(Hoopa Confined|Hoopa Unbound)$",
        r"^(.+?)\s+(Midday Form|Midnight Form|Dusk Form)$",
        r"^(.+?)\s+(Solo Form|School Form)$",
        r"^(.+?)\s+(Meteor Form|Core Form)$",
        r"^(.+?)\s+(Ice Face|Noice Face)$",
        r"^(.+?)\s+(Full Belly Mode|Hangry Mode)$",
        r"^(.+?)\s+(Hero of Many Battles|Crowned Sword|Crowned Shield|Eternamax)$",
        r"^(.+?)\s+(Family of Four|Family of Three)$",
        r"^(.+?)\s+(Green Plumage|Blue Plumage|Yellow Plumage|White Plumage)$",
        r"^(.+?)\s+(Zero Form|Hero Form)$",
        r"^(.+?)\s+(Curly Form|Droopy Form|Stretchy Form)$",
        r"^(.+?)\s+(Two-Segment Form|Three-Segment Form)$",
        r"^(.+?)\s+(Chest Form|Roaming Form)$",
        r"^(.+?)\s+(Teal Mask|Wellspring Mask|Hearthflame Mask|Cornerstone Mask)$",
        r"^(.+?)\s+(Heat Rotom|Wash Rotom|Frost Rotom|Fan Rotom|Mow Rotom)$",
        r"^(.+?)\s+(Galarian Standard Mode|Galarian Zen Mode|Standard Mode|Zen Mode)$",
    ]
    
    for pattern in suffix_patterns:
        match = re.match(pattern, name, re.IGNORECASE)
        if match:
            base_name = match.group(1).strip()
            variant = match.group(2).strip()
            return (base_name, variant)
    
    # No variant found, return original name
    return (name, None)


def infer_generation_from_number(number: int) -> int:
    """
    Infer generation from Pokédex number ranges.
    """
    if number <= 151:
        return 1
    elif number <= 251:
        return 2
    elif number <= 386:
        return 3
    elif number <= 493:
        return 4
    elif number <= 649:
        return 5
    elif number <= 721:
        return 6
    elif number <= 809:
        return 7
    elif number <= 905:
        return 8
    else:
        return 9


def parse_stats() -> Dict[Tuple[int, Optional[str]], Tuple[str, Stats, List[str]]]:
    """
    Parse the stats table into a map of (dex number, variant) -> (name, Stats, types).
    Parses HTML directly to get full display names including forms.
    Returns: Dict mapping (number, variant) -> (full_name, stats, types)
    """
    # Parse HTML directly to get full display names (pandas might only get link text)
    soup = fetch_html(STATS_URL)
    table = soup.select_one("table.data-table")
    if not table:
        raise RuntimeError("Could not find stats table")
    
    rows = table.select("tbody tr")
    stats_map: Dict[Tuple[int, Optional[str]], Tuple[str, Stats, List[str]]] = {}
    
    for row in rows:
        cells = row.select("td")
        if len(cells) < 9:
            continue
        
        # Parse number
        number_cell = cells[0]
        number_text = number_cell.get_text(strip=True)
        try:
            number = int(number_text)
        except ValueError:
            continue
        
        # Parse name - get full text including form indicators
        name_cell = cells[1]
        # Get all text from the cell (includes link text + any text after link)
        # BeautifulSoup get_text() will include all text content
        name = name_cell.get_text(separator=" ", strip=True)
        # Clean up extra spaces
        name = re.sub(r'\s+', ' ', name).strip()
        
        # Extract variant
        base_name, variant = extract_variant(name)
        
        # Parse types
        type_cell = cells[2]
        type_links = type_cell.select("a")
        types = [link.get_text(strip=True) for link in type_links if link.get_text(strip=True)]
        
        # Parse stats
        try:
            total = int(cells[3].get_text(strip=True))
            hp = int(cells[4].get_text(strip=True))
            attack = int(cells[5].get_text(strip=True))
            defense = int(cells[6].get_text(strip=True))
            sp_atk = int(cells[7].get_text(strip=True))
            sp_def = int(cells[8].get_text(strip=True))
            speed = int(cells[9].get_text(strip=True))
        except (ValueError, IndexError):
            continue
        
        key = (number, variant)
        stats_map[key] = (
            name,  # Full display name
            Stats(
                total=total,
                hp=hp,
                attack=attack,
                defense=defense,
                sp_atk=sp_atk,
                sp_def=sp_def,
                speed=speed,
            ),
            types
        )
    
    return stats_map


def build_dataset(stats_map: Dict[Tuple[int, Optional[str]], Tuple[str, Stats, List[str]]]) -> List[Pokemon]:
    """
    Build dataset using stats table as source of truth (includes all variants).
    Generation is inferred from Pokédex number ranges.
    """
    dataset: List[Pokemon] = []
    
    # Process all entries from stats table (source of truth)
    for (number, variant), (stats_name, stats, stats_types) in stats_map.items():
        # Extract base_name from stats_name
        base_name, _ = extract_variant(stats_name)
        
        # Use stats table data for name and types
        name = stats_name
        types = stats_types
        
        # Infer generation from number ranges
        generation = infer_generation_from_number(number)
        
        dataset.append(Pokemon(number, name, base_name, variant, generation, types, stats))
    
    # Sort by number, then by variant (None first, then alphabetical)
    dataset.sort(key=lambda p: (p.number, (p.variant is not None, p.variant or "")))
    
    return dataset


def write_outputs(pokemon: List[Pokemon]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    list_payload = [asdict(p) for p in pokemon]
    
    # Group by number to handle variants (multiple entries per number)
    by_number: Dict[int, List[dict]] = {}
    for p in pokemon:
        if p.number not in by_number:
            by_number[p.number] = []
        by_number[p.number].append(asdict(p))
    
    # Single entry per name (names should be unique)
    by_name = {p.name.lower(): asdict(p) for p in pokemon}
    
    # Also create a map by base_name for hierarchical access
    by_base_name: Dict[str, List[dict]] = {}
    for p in pokemon:
        key = p.base_name.lower()
        if key not in by_base_name:
            by_base_name[key] = []
        by_base_name[key].append(asdict(p))

    (DATA_DIR / "pokemon.json").write_text(json.dumps(list_payload, indent=2), encoding="utf-8")
    (DATA_DIR / "pokemon_by_number.json").write_text(json.dumps(by_number, indent=2), encoding="utf-8")
    (DATA_DIR / "pokemon_by_name.json").write_text(json.dumps(by_name, indent=2), encoding="utf-8")
    (DATA_DIR / "pokemon_by_base_name.json").write_text(json.dumps(by_base_name, indent=2), encoding="utf-8")


def validate_entry_count(stats_map: Dict[Tuple[int, Optional[str]], Tuple[str, Stats, List[str]]], 
                         pokemon: List[Pokemon]) -> None:
    """
    Validate that all entries from stats table are captured.
    """
    stats_count = len(stats_map)
    pokemon_count = len(pokemon)
    
    print(f"\nValidation:")
    print(f"  Stats table entries: {stats_count}")
    print(f"  Generated Pokémon entries: {pokemon_count}")
    
    if stats_count != pokemon_count:
        print(f"  WARNING: Count mismatch! Missing {stats_count - pokemon_count} entries")
        
        # Find missing entries
        pokemon_keys = {(p.number, p.variant) for p in pokemon}
        stats_keys = set(stats_map.keys())
        missing = stats_keys - pokemon_keys
        
        if missing:
            print(f"\n  Missing entries:")
            for number, variant in sorted(missing)[:20]:  # Show first 20
                name, _, _ = stats_map[(number, variant)]
                print(f"    #{number} {name} (variant: {variant})")
            if len(missing) > 20:
                print(f"    ... and {len(missing) - 20} more")
    else:
        print(f"  ✓ All entries captured successfully")


def main() -> None:
    print("Fetching stats table...")
    stats_map = parse_stats()
    print(f"Found {len(stats_map)} entries in stats table")
    
    print("Building dataset...")
    pokemon = build_dataset(stats_map)
    
    print("Validating...")
    validate_entry_count(stats_map, pokemon)
    
    print("\nWriting outputs...")
    write_outputs(pokemon)
    print(f"Wrote {len(pokemon)} Pokémon entries to data/")


if __name__ == "__main__":
    main()


