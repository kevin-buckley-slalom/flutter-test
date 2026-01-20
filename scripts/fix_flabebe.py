#!/usr/bin/env python3
"""
Fix Flabébé moves by fetching with the correct URL (no accent).
"""

import json
import pathlib
import sys

# Add scripts directory to path for relative imports
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from collect_pokemon_moves_serebii import fetch_html, parse_serebii_moves

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
POKEMON_JSON = DATA_DIR / "pokemon.json"

def fix_flabebe():
    """Fix Flabébé by fetching Gen 8 and Gen 9 moves."""
    
    # Load pokemon.json to get variant names
    with open(POKEMON_JSON) as f:
        pokemon_data = json.load(f)
    
    # Find Flabébé entry
    flabebe_entry = None
    for entry in pokemon_data:
        if entry.get("base_name") == "Flabébé":
            flabebe_entry = entry
            break
    
    if not flabebe_entry:
        print("ERROR: Flabébé not found in pokemon.json")
        return
    
    base_name = flabebe_entry["base_name"]
    variant_names = flabebe_entry.get("variants", [base_name])
    
    print(f"Fixing {base_name}...")
    print(f"  Variants: {variant_names}")
    
    output_data = {}
    
    # Gen 8
    print("  Fetching Gen 8 (pokedex-swsh)...")
    gen8_url = "https://www.serebii.net/pokedex-swsh/flabebe/"
    try:
        soup = fetch_html(gen8_url)
        gen8_moves = parse_serebii_moves(soup, base_name, variant_names, url=gen8_url)
        if gen8_moves:
            # Flatten the structure (parse_serebii_moves returns {pokemon_name: {gen_key: {game: moves}}}
            for pokemon_name, gen_data in gen8_moves.items():
                for gen_key, games in gen_data.items():
                    output_data.setdefault(gen_key, {}).update(games)
            print(f"    ✓ Gen 8 fetched successfully")
        else:
            print(f"    ✗ Gen 8 failed to parse")
    except Exception as e:
        print(f"    ✗ Gen 8 error: {e}")
    
    # Gen 9
    print("  Fetching Gen 9 (pokedex-sv)...")
    gen9_url = "https://www.serebii.net/pokedex-sv/flabebe/"
    try:
        soup = fetch_html(gen9_url)
        gen9_moves = parse_serebii_moves(soup, base_name, variant_names, url=gen9_url)
        if gen9_moves:
            # Flatten the structure
            for pokemon_name, gen_data in gen9_moves.items():
                for gen_key, games in gen_data.items():
                    output_data.setdefault(gen_key, {}).update(games)
            print(f"    ✓ Gen 9 fetched successfully")
        else:
            print(f"    ✗ Gen 9 failed to parse")
    except Exception as e:
        print(f"    ✗ Gen 9 error: {e}")
    
    # Add URL references
    if "gen_8" in output_data:
        output_data["url_gen8"] = gen8_url
    if "gen_9" in output_data:
        output_data["url_gen9"] = gen9_url
    
    # Write to file
    output_file = DATA_DIR / "pokemon_moves" / f"{base_name}.json"
    with open(output_file, "w") as f:
        json.dump(output_data, f, indent=2)
    
    print(f"  ✓ Written to {output_file}")
    print(f"  Generations: {' + '.join(output_data.keys())}")

if __name__ == "__main__":
    fix_flabebe()
