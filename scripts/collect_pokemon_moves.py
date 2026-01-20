"""
Collect Pokémon moveset information from PokemonDB.

Source:
- Pokemon pages: https://pokemondb.net/pokedex/<pokemon-slug>

Outputs:
- data/pokemon_moves.json : map pokemon name -> variant -> generation -> move categories

Run:
    python scripts/collect_pokemon_moves.py

Dependencies:
    pip install requests beautifulsoup4 lxml
"""
from __future__ import annotations

import json
import pathlib
import re
import time
import unicodedata
from typing import Dict, List, Optional

import requests
from bs4 import BeautifulSoup

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
BASE_URL = "https://pokemondb.net"
POKEMON_JSON = DATA_DIR / "pokemon.json"

HEADERS = {
    "User-Agent": "ChampionDex/1.0 (+https://github.com/kevinbuckley) Python requests",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def fetch_html(url: str) -> BeautifulSoup:
    """Fetch and parse HTML from the given URL."""
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "lxml")


def clean_text(text: str) -> str:
    """Clean and normalize text."""
    return text.strip().replace('\n', ' ').replace('\r', '').replace('  ', ' ')


def make_pokemon_url(base_name: str) -> str:
    """Convert Pokemon base name to URL slug.
    
    Handles special characters like accents, gender symbols, etc.
    """
    slug = base_name.lower()
    
    # Handle special Pokemon symbols
    slug = slug.replace('♀', 'f').replace('♂', 'm')
    slug = slug.replace('é', 'e').replace('è', 'e')
    
    # Normalize Unicode (decompose accented characters)
    slug = unicodedata.normalize('NFD', slug)
    slug = ''.join(char for char in slug if unicodedata.category(char) != 'Mn')
    
    # Remove special characters and replace spaces with dashes
    slug = slug.replace("'", "").replace(".", "").replace(":", "")
    slug = slug.replace(" ", "-")
    
    return f"{BASE_URL}/pokedex/{slug}"


def parse_move_table(table: BeautifulSoup, method: str) -> List[Dict]:
    """Parse a move table and extract move information.
    
    Args:
        table: BeautifulSoup table element
        method: The learn method (level, tm, egg, evolution, etc.)
    
    Returns:
        List of move dicts with name, level/tm_number, type, category, power, accuracy, etc.
    """
    moves = []
    tbody = table.find('tbody')
    if not tbody:
        return moves
    
    for row in tbody.find_all('tr'):
        cells = row.find_all('td')
        if len(cells) < 2:
            continue
        
        move_data = {}
        
        # Different table structures for different learn methods
        if method == 'level':
            # Level up tables: Level | Move | Type | Cat. | Power | Acc.
            if len(cells) < 6:
                continue
            level = clean_text(cells[0].get_text())
            move_link = cells[1].find('a', class_='ent-name')
            if not move_link:
                continue
            move_name = clean_text(move_link.get_text())
            
            move_data = {
                'name': move_name,
                'level': level,
                'type': clean_text(cells[2].get_text()) if len(cells) > 2 else None,
                'category': clean_text(cells[3].get_text()) if len(cells) > 3 else None,
                'power': clean_text(cells[4].get_text()) if len(cells) > 4 else None,
                'accuracy': clean_text(cells[5].get_text()) if len(cells) > 5 else None,
            }
            
        elif method in ('tm', 'hm', 'tr'):
            # TM/HM/TR tables: TM | Move | Type | Cat. | Power | Acc.
            if len(cells) < 6:
                continue
            tm_number = clean_text(cells[0].get_text())
            move_link = cells[1].find('a', class_='ent-name')
            if not move_link:
                continue
            move_name = clean_text(move_link.get_text())
            
            move_data = {
                'name': move_name,
                'tm_number': tm_number,
                'type': clean_text(cells[2].get_text()) if len(cells) > 2 else None,
                'category': clean_text(cells[3].get_text()) if len(cells) > 3 else None,
                'power': clean_text(cells[4].get_text()) if len(cells) > 4 else None,
                'accuracy': clean_text(cells[5].get_text()) if len(cells) > 5 else None,
            }
            
        elif method == 'egg':
            # Egg move tables: Move | Type | Cat. | Power | Acc.
            if len(cells) < 5:
                continue
            move_link = cells[0].find('a', class_='ent-name')
            if not move_link:
                continue
            move_name = clean_text(move_link.get_text())
            
            move_data = {
                'name': move_name,
                'type': clean_text(cells[1].get_text()) if len(cells) > 1 else None,
                'category': clean_text(cells[2].get_text()) if len(cells) > 2 else None,
                'power': clean_text(cells[3].get_text()) if len(cells) > 3 else None,
                'accuracy': clean_text(cells[4].get_text()) if len(cells) > 4 else None,
            }
            
        elif method == 'evolution':
            # Evolution move tables: Move | Type | Cat. | Power | Acc.
            if len(cells) < 5:
                continue
            move_link = cells[0].find('a', class_='ent-name')
            if not move_link:
                continue
            move_name = clean_text(move_link.get_text())
            
            move_data = {
                'name': move_name,
                'type': clean_text(cells[1].get_text()) if len(cells) > 1 else None,
                'category': clean_text(cells[2].get_text()) if len(cells) > 2 else None,
                'power': clean_text(cells[3].get_text()) if len(cells) > 3 else None,
                'accuracy': clean_text(cells[4].get_text()) if len(cells) > 4 else None,
            }
        
        if move_data:
            moves.append(move_data)
    
    return moves


def _parse_move_sections(panel, gen_moves_dict):
    """Parse all move sections (level up, TM, egg, evolution) within a panel.
    
    Args:
        panel: BeautifulSoup element containing move tables
        gen_moves_dict: Dictionary to populate with move data
    """
    # Find all h3 headings (which precede move tables)
    headings = panel.find_all('h3')
    
    for heading in headings:
        heading_text = clean_text(heading.get_text()).lower()
        
        # Determine the learn method from the heading
        if 'level up' in heading_text or 'level-up' in heading_text:
            method_key = 'level_up'
            method_type = 'level'
        elif 'tm' in heading_text or 'hm' in heading_text or 'tr' in heading_text:
            method_key = 'tm'
            if 'tm' in heading_text:
                method_type = 'tm'
            elif 'hm' in heading_text:
                method_type = 'hm'
            else:
                method_type = 'tr'
        elif 'egg' in heading_text:
            method_key = 'egg'
            method_type = 'egg'
        elif 'evolution' in heading_text:
            method_key = 'evolution'
            method_type = 'evolution'
        else:
            continue
        
        # Find the next table after this heading
        table = heading.find_next('table', class_='data-table')
        if table:
            moves = parse_move_table(table, method_type)
            if moves:
                gen_moves_dict[method_key] = moves


def parse_pokemon_moves(soup: BeautifulSoup, pokemon_name: str) -> Dict:
    """Parse all move data for a Pokemon from its page.
    
    Args:
        soup: BeautifulSoup parsed HTML
        pokemon_name: The full Pokemon name (e.g., "Raticate" or "Alolan Raticate")
    
    Returns a nested dict structure:
    {
        "full_pokemon_name": {
            "generation": {
                "level_up": [...],
                "tm": [...],
                "egg": [...],
                "evolution": [...]
            }
        }
    }
    """
    all_moves = {}
    
    # Find the "Moves learned by..." heading
    moves_heading = soup.find('h2', string=lambda text: text and 'Moves learned by' in text)
    if not moves_heading:
        print(f"  WARNING: No 'Moves learned by' heading found")
        return all_moves
    
    # Find the sv-tabs-wrapper after the moves heading (contains generation tabs)
    moves_section = moves_heading.find_next('div', class_='sv-tabs-wrapper')
    if not moves_section:
        print(f"  WARNING: No moves section found")
        return all_moves
    
    # Get generation tab names
    gen_tab_list = moves_section.find('div', class_='sv-tabs-tab-list')
    generation_names = []
    if gen_tab_list:
        gen_links = gen_tab_list.find_all('a')
        generation_names = [clean_text(link.get_text()) for link in gen_links]
    
    # Get generation tab panels - they're inside a sv-tabs-panel-list container
    panel_container = moves_section.find('div', class_='sv-tabs-panel-list')
    if not panel_container:
        print(f"  WARNING: No panel container found")
        return all_moves
    
    gen_panels = panel_container.find_all('div', class_='sv-tabs-panel', recursive=False)
    
    for gen_idx, gen_panel in enumerate(gen_panels):
        generation = generation_names[gen_idx] if gen_idx < len(generation_names) else f"Generation {gen_idx + 1}"
        
        # Within each generation panel, check if there are form tabs
        form_tabs_wrapper = gen_panel.find('div', class_='sv-tabs-wrapper')
        
        if form_tabs_wrapper:
            # Multiple forms exist (e.g., Alolan, Galarian)
            form_tab_list = form_tabs_wrapper.find('div', class_='sv-tabs-tab-list')
            form_names = []
            if form_tab_list:
                form_links = form_tab_list.find_all('a')
                form_names = [clean_text(link.get_text()) for link in form_links]
            
            form_panels = form_tabs_wrapper.find_all('div', class_='sv-tabs-panel', recursive=False)
            
            for form_idx, form_panel in enumerate(form_panels):
                form_name = form_names[form_idx] if form_idx < len(form_names) else f"Form {form_idx + 1}"
                
                # Create the full variant name: e.g., "Raticate Alolan Raticate"
                if form_name.lower() != form_name and form_name not in pokemon_name:
                    # This is a variant like "Alolan" that needs to be combined with base name
                    full_variant_name = pokemon_name  # Use the passed-in name which may include variant
                else:
                    full_variant_name = pokemon_name
                
                if full_variant_name not in all_moves:
                    all_moves[full_variant_name] = {}
                if generation not in all_moves[full_variant_name]:
                    all_moves[full_variant_name][generation] = {}
                
                # Parse move tables in this form panel
                _parse_move_sections(form_panel, all_moves[full_variant_name][generation])
        else:
            # No form tabs, use the pokemon_name as the key
            if pokemon_name not in all_moves:
                all_moves[pokemon_name] = {}
            if generation not in all_moves[pokemon_name]:
                all_moves[pokemon_name][generation] = {}
            
            # Parse move tables directly from the generation panel
            _parse_move_sections(gen_panel, all_moves[pokemon_name][generation])
    
    return all_moves


def parse_pokemon_moves_multiple_variants(soup: BeautifulSoup, base_name: str, variant_names: List[str]) -> Dict:
    """Parse all move data for a Pokemon with multiple variants from its page.
    
    Args:
        soup: BeautifulSoup parsed HTML
        base_name: The base Pokemon name (e.g., "Raticate")
        variant_names: List of all variant names including base (e.g., ["Raticate", "Alolan Raticate"])
    
    Returns a nested dict structure keyed by variant name
    """
    all_moves = {}
    
    # Find the "Moves learned by..." heading
    moves_heading = soup.find('h2', string=lambda text: text and 'Moves learned by' in text)
    if not moves_heading:
        return all_moves
    
    # Find the sv-tabs-wrapper after the moves heading (contains generation tabs)
    moves_section = moves_heading.find_next('div', class_='sv-tabs-wrapper')
    if not moves_section:
        return all_moves
    
    # Get generation tab names
    gen_tab_list = moves_section.find('div', class_='sv-tabs-tab-list')
    generation_names = []
    if gen_tab_list:
        gen_links = gen_tab_list.find_all('a')
        generation_names = [clean_text(link.get_text()) for link in gen_links]
    
    # Get generation tab panels - they're inside a sv-tabs-panel-list container
    panel_container = moves_section.find('div', class_='sv-tabs-panel-list')
    if not panel_container:
        return all_moves
    
    gen_panels = panel_container.find_all('div', class_='sv-tabs-panel', recursive=False)
    
    for gen_idx, gen_panel in enumerate(gen_panels):
        generation = generation_names[gen_idx] if gen_idx < len(generation_names) else f"Generation {gen_idx + 1}"
        
        # Within each generation panel, check if there are form tabs
        form_tabs_wrapper = gen_panel.find('div', class_='sv-tabs-wrapper')
        
        if form_tabs_wrapper:
            # Multiple forms exist (e.g., Alolan, Galarian)
            form_tab_list = form_tabs_wrapper.find('div', class_='sv-tabs-tab-list')
            form_names = []
            if form_tab_list:
                form_links = form_tab_list.find_all('a')
                form_names = [clean_text(link.get_text()) for link in form_links]
            
            form_panels = form_tabs_wrapper.find_all('div', class_='sv-tabs-panel', recursive=False)
            
            # Map form tab names to variant names from the JSON
            # Form tab names are like "Raticate" and "Alolan Raticate" (or just the variant part)
            for form_idx, form_panel in enumerate(form_panels):
                form_name = form_names[form_idx] if form_idx < len(form_names) else f"Form {form_idx + 1}"
                
                # Find the matching variant name from our list
                # The variant_names list should contain exact matches
                matching_variant = None
                for variant in variant_names:
                    # Check if form_name matches part of the variant name
                    if form_name in variant or variant.endswith(form_name):
                        matching_variant = variant
                        break
                
                # Default to the form_name if no match found
                pokemon_name = matching_variant or form_name
                
                if pokemon_name not in all_moves:
                    all_moves[pokemon_name] = {}
                if generation not in all_moves[pokemon_name]:
                    all_moves[pokemon_name][generation] = {}
                
                # Parse move tables in this form panel
                _parse_move_sections(form_panel, all_moves[pokemon_name][generation])
        else:
            # No form tabs - use the first (or only) variant name
            pokemon_name = variant_names[0] if variant_names else base_name
            
            if pokemon_name not in all_moves:
                all_moves[pokemon_name] = {}
            if generation not in all_moves[pokemon_name]:
                all_moves[pokemon_name][generation] = {}
            
            # Parse move tables directly from the generation panel
            _parse_move_sections(gen_panel, all_moves[pokemon_name][generation])
    
    return all_moves


def main():
    """Main function to collect Pokemon move data."""
    print("Loading Pokemon data...")
    with open(POKEMON_JSON, 'r', encoding='utf-8') as f:
        pokemon_list = json.load(f)
    
    # Group Pokemon by base_name to get all variants that share the same URL
    pokemon_by_base = {}
    for pokemon in pokemon_list:
        base_name = pokemon.get('base_name')
        name = pokemon.get('name')
        if base_name:
            if base_name not in pokemon_by_base:
                pokemon_by_base[base_name] = []
            pokemon_by_base[base_name].append(name)
    
    print(f"Found {len(pokemon_by_base)} unique Pokemon base forms to process")
    
    all_pokemon_moves = {}
    
    for i, (base_name, variant_names) in enumerate(pokemon_by_base.items(), 1):
        print(f"[{i}/{len(pokemon_by_base)}] Fetching moves for: {base_name}")
        
        try:
            url = make_pokemon_url(base_name)
            soup = fetch_html(url)
            
            # Pass all variant names for this base form so they can be mapped to the form tabs
            moves = parse_pokemon_moves_multiple_variants(soup, base_name, variant_names)
            if moves:
                all_pokemon_moves.update(moves)
            
            # Be polite to the server
            time.sleep(0.5)
            
        except Exception as e:
            print(f"  Error fetching {base_name}: {e}")
            continue
    
    # Save to JSON
    output_path = DATA_DIR / "pokemon_moves.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(all_pokemon_moves, f, indent=2, ensure_ascii=False)
    
    print(f"\nSaved move data for {len(all_pokemon_moves)} Pokemon to {output_path}")


if __name__ == "__main__":
    main()
