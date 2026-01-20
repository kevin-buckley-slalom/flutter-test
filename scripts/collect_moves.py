"""
Collect Pokémon move information from PokemonDB.

Source:
- Move list: https://pokemondb.net/move/all
- Move details: https://pokemondb.net/move/<move-slug>

Outputs:
- data/moves.json : map move name -> full move data including type, category, power, accuracy, pp, max_pp, priority, makes_contact, generation, targets, effect, z_move_effect, etc.

Run:
    python scripts/collect_moves.py

Dependencies:
    pip install requests beautifulsoup4 lxml
"""
from __future__ import annotations

import json
import pathlib
import re
import time
from typing import Dict, Optional, Tuple, List

import requests
from bs4 import BeautifulSoup

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
BASE_URL = "https://pokemondb.net"
MOVES_URL = f"{BASE_URL}/move/all"

HEADERS = {
    "User-Agent": "ChampionDex/1.0 (+https://github.com/kevinbuckley) Python requests",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# Track unknown fields found in move data tables
UNKNOWN_FIELDS = set()


def fetch_html(url: str) -> BeautifulSoup:
    """Fetch and parse HTML from the given URL."""
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "lxml")


def clean_text(text: str) -> str:
    """Clean and normalize text."""
    return text.strip().replace('\n', ' ').replace('\r', '')


def parse_int_or_none(value: str) -> Optional[int]:
    """Parse integer from string, return None if it's a dash or can't be parsed."""
    value = clean_text(value)
    if value in ('—', '-', '∞', ''):
        return None
    # Remove any non-digit characters and try to parse
    digits = re.sub(r'[^\d]', '', value)
    if digits:
        return int(digits)
    return None


def parse_moves_table(soup: BeautifulSoup) -> Dict[str, Tuple[dict, str]]:
    """Parse the moves table and extract basic move data plus URLs.
    Returns dict mapping move_name -> (basic_data, detail_url)
    """
    moves = {}
    
    # Find the main data table - it has class 'data-table'
    table = soup.find('table', class_='data-table')
    if not table:
        print("Error: Could not find moves table")
        return moves
    
    # Find all rows in tbody
    tbody = table.find('tbody')
    if not tbody:
        print("Error: Could not find table body")
        return moves
    
    rows = tbody.find_all('tr')
    print(f"Found {len(rows)} moves")
    
    for row in rows:
        cells = row.find_all('td')
        if len(cells) < 7:
            continue
        
        # Extract data from each cell
        # Cell 0: Move name (contains link)
        name_cell = cells[0]
        name_link = name_cell.find('a', class_='ent-name')
        if not name_link:
            continue
        move_name = clean_text(name_link.get_text())
        move_url = BASE_URL + name_link.get('href') if name_link.get('href') else None
        
        # Cell 1: Type (contains icon with title attribute)
        type_cell = cells[1]
        type_link = type_cell.find('a')
        move_type = clean_text(type_link.get_text()) if type_link else None
        
        # Cell 2: Category (Physical/Special/Status)
        category_cell = cells[2]
        category_img = category_cell.find('img')
        move_category = category_img.get('title') if category_img and category_img.get('title') else clean_text(category_cell.get_text())
        if not move_category:
            move_category = None
        
        # Cell 3: Power
        power = parse_int_or_none(cells[3].get_text())
        
        # Cell 4: Accuracy
        accuracy = parse_int_or_none(cells[4].get_text())
        
        # Cell 5: PP
        pp = parse_int_or_none(cells[5].get_text())
        
        # Cell 6: Effect description
        effect_cell = cells[6]
        effect_text = clean_text(effect_cell.get_text())
        if not effect_text or effect_text == '—':
            effect_text = None
        
        # Extract effect chance from effect text if present
        effect_chance = None
        if effect_text:
            # Look for percentage patterns like "10% chance", "30% chance to"
            chance_match = re.search(r'(\d+)%\s+chance', effect_text, re.IGNORECASE)
            if chance_match:
                effect_chance = int(chance_match.group(1))
        
        # Build move data object
        move_data = {
            "type": move_type,
            "category": move_category,
            "power": power,
            "accuracy": accuracy,
            "pp": pp,
            "effect": effect_text,
            "effect_chance": effect_chance
        }
        
        moves[move_name] = (move_data, move_url)
        
    return moves


def parse_move_detail_page(soup: BeautifulSoup, move_name: str) -> dict:
    """Parse a move's detail page to extract additional information.
    
    Returns a dict with additional fields:
    - max_pp
    - priority
    - makes_contact
    - generation
    - targets
    - full_effect
    - z_move_effect
    - any other fields found in Move Data table
    """
    details = {}
    
    # Find the "Move Data" table (vitals-table)
    vitals_table = soup.find('table', class_='vitals-table')
    if vitals_table:
        for row in vitals_table.find_all('tr'):
            th = row.find('th')
            td = row.find('td')
            if not th or not td:
                continue
            
            field_name = clean_text(th.get_text()).lower()
            field_value = clean_text(td.get_text())
            
            # Normalize field names by removing question marks and other special chars
            field_name_normalized = field_name.replace('?', '').strip()
            
            # Map known fields
            if field_name_normalized == 'type':
                details['type'] = field_value
            elif field_name_normalized == 'category':
                details['category'] = field_value
            elif field_name_normalized == 'power' or field_name_normalized == 'base power':
                details['power'] = parse_int_or_none(field_value)
            elif field_name_normalized == 'accuracy':
                details['accuracy'] = parse_int_or_none(field_value)
            elif field_name_normalized == 'pp' or field_name_normalized == 'power points':
                # PP might be listed as "X (max Y)" or "X (max. Y)" format
                pp_match = re.match(r'(\d+)\s*(?:\(max\.?\s*(\d+)\))?', field_value)
                if pp_match:
                    details['pp'] = int(pp_match.group(1))
                    if pp_match.group(2):
                        details['max_pp'] = int(pp_match.group(2))
                else:
                    details['pp'] = parse_int_or_none(field_value)
            elif field_name_normalized == 'priority':
                details['priority'] = parse_int_or_none(field_value)
            elif field_name_normalized == 'target':
                details['targets'] = field_value
            elif field_name_normalized in ('makes contact', 'contact'):
                details['makes_contact'] = field_value.lower() in ('yes', 'true', '✓')
            elif field_name_normalized in ('introduced', 'generation'):
                # Extract generation number
                gen_match = re.search(r'(?:generation\s*)?(\d+|[ivxIVX]+)', field_value, re.IGNORECASE)
                if gen_match:
                    gen_str = gen_match.group(1)
                    # Convert roman numerals if needed
                    roman_map = {'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9}
                    details['generation'] = roman_map.get(gen_str.upper(), parse_int_or_none(gen_str))
            else:
                # Log unknown fields
                if field_name_normalized not in ['effect', 'name']:
                    UNKNOWN_FIELDS.add(field_name)
                    details[field_name_normalized.replace(' ', '_')] = field_value
    
    # Extract full effect description from "Effect" section
    for heading in soup.find_all(['h2', 'h3']):
        if clean_text(heading.get_text()).lower() == 'effect':
            # Get the next paragraph or content
            next_elem = heading.find_next_sibling()
            while next_elem and next_elem.name in ['p', 'div']:
                effect_text = clean_text(next_elem.get_text())
                if effect_text and effect_text != '—':
                    details['full_effect'] = effect_text
                    break
                next_elem = next_elem.find_next_sibling()
            break
    
    # Extract target information from "Move target" section
    for heading in soup.find_all(['h2', 'h3', 'h4']):
        if 'move target' in clean_text(heading.get_text()).lower():
            # Look for the target description paragraph in the parent container
            parent = heading.parent
            if parent:
                target_descr = parent.find('p', class_='mt-descr')
                if target_descr:
                    details['targets'] = clean_text(target_descr.get_text())
            break
    
    # Extract Z-Move effect if present
    for heading in soup.find_all(['h2', 'h3', 'h4']):
        heading_text = clean_text(heading.get_text()).lower()
        if 'z-move' in heading_text or 'z-crystal' in heading_text:
            next_elem = heading.find_next_sibling()
            while next_elem and next_elem.name in ['p', 'div', 'table']:
                if next_elem.name == 'p':
                    z_text = clean_text(next_elem.get_text())
                    if z_text and z_text != '—':
                        details['z_move_effect'] = z_text
                        break
                elif next_elem.name == 'table':
                    # Sometimes Z-move info is in a table
                    z_text = clean_text(next_elem.get_text())
                    if z_text:
                        details['z_move_effect'] = z_text
                        break
                next_elem = next_elem.find_next_sibling()
            break
    
    return details


def enrich_move_data(basic_data: dict, detail_url: str, move_name: str) -> dict:
    """Fetch the detail page and merge with basic data."""
    if not detail_url:
        return basic_data
    
    try:
        detail_soup = fetch_html(detail_url)
        detail_data = parse_move_detail_page(detail_soup, move_name)
        
        # Merge: detail_data takes precedence over basic_data
        enriched = {**basic_data, **detail_data}
        return enriched
    except Exception as e:
        print(f"  Warning: Failed to fetch details for {move_name}: {e}")
        return basic_data
        
        moves[move_name] = move_data
        
    return moves


def main():
    """Main function to collect move data."""
    print("Fetching move data from PokemonDB...")
    soup = fetch_html(MOVES_URL)
    
    print("Parsing moves table...")
    moves_with_urls = parse_moves_table(soup)
    
    if not moves_with_urls:
        print("Error: No moves collected!")
        return
    
    print(f"Collected basic data for {len(moves_with_urls)} moves")
    print("Now fetching detailed data for each move (this will take a while)...")
    
    final_moves = {}
    total = len(moves_with_urls)
    
    for i, (move_name, (basic_data, detail_url)) in enumerate(moves_with_urls.items(), 1):
        print(f"[{i}/{total}] Fetching details for: {move_name}")
        enriched_data = enrich_move_data(basic_data, detail_url, move_name)
        final_moves[move_name] = enriched_data
        
        # Be polite to the server - add a small delay
        if i % 10 == 0:
            time.sleep(1)
        else:
            time.sleep(0.2)
    
    print(f"\nCollected complete data for {len(final_moves)} moves")
    
    # Report any unknown fields found
    if UNKNOWN_FIELDS:
        print(f"\nUnknown fields found in Move Data tables: {sorted(UNKNOWN_FIELDS)}")
    
    # Save to JSON file
    output_path = DATA_DIR / "moves.json"
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(final_moves, f, indent=2, ensure_ascii=False)
    
    print(f"Saved moves data to {output_path}")
    
    # Print a sample
    sample_moves = list(final_moves.items())[:2]
    print("\nSample moves:")
    for name, data in sample_moves:
        print(f"\n{name}:")
        for key, value in data.items():
            if isinstance(value, str) and len(value) > 80:
                print(f"  {key}: {value[:80]}...")
            else:
                print(f"  {key}: {value}")


if __name__ == "__main__":
    main()
