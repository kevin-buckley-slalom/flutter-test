#!/usr/bin/env python3
"""
Collect Pokémon moveset information from Serebii for both Gen 8 and Gen 9.

This script:
1. Fetches moves from both /pokedex-swsh/ (Gen 8) and /pokedex-sv/ (Gen 9)
2. Only includes generations where the Pokemon exists (skips 404s)
3. Merges data into single JSON file with gen_8 and gen_9 keys
4. Handles all games: SWSH, BDSP, PLA (Gen 8) and Legends: Z-A, SV (Gen 9)

Outputs:
- data/pokemon_moves/<Pokemon>.json for each Pokemon
"""

import json
import pathlib
import time
import requests
import sys
from typing import Dict, Optional

# Add scripts directory to path for relative imports
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from collect_pokemon_moves_serebii import (
    fetch_html, parse_serebii_moves
)

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
POKEMON_JSON = DATA_DIR / "pokemon.json"


def fetch_pokemon_moves(base_name: str, variant_names: list, generation: int) -> Optional[Dict]:
    """
    Fetch moves for a Pokemon in a specific generation.
    
    Args:
        base_name: Base Pokemon name
        variant_names: List of variant names for this Pokemon
        generation: 8 for SWSH, 9 for SV
        
    Returns:
        Dict with gen_X key containing move data, or None if 404
    """
    # Build URL based on generation
    if generation == 9:
        slug = base_name.lower().replace(" ", "").replace("♀", "f").replace("♂", "m")
        url = f"https://www.serebii.net/pokedex-sv/{slug}/"
    else:  # generation 8
        slug = base_name.lower().replace(" ", "").replace("♀", "f").replace("♂", "m")
        url = f"https://www.serebii.net/pokedex-swsh/{slug}/"
    
    try:
        soup = fetch_html(url)
        moves = parse_serebii_moves(soup, base_name, variant_names, url=url)
        
        if moves:
            return moves
        else:
            return None
            
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            return None
        else:
            raise
    except Exception as e:
        print(f"\n    Error: {e}")
        raise


def main():
    """Main function to collect Pokemon moves for both Gen 8 and Gen 9."""
    print("Loading Pokemon data...")
    with open(POKEMON_JSON, 'r', encoding='utf-8') as f:
        pokemon_list = json.load(f)
    
    # Group Pokemon by base_name
    pokemon_by_base = {}
    for pokemon in pokemon_list:
        base_name = pokemon.get('base_name')
        name = pokemon.get('name')
        if base_name:
            if base_name not in pokemon_by_base:
                pokemon_by_base[base_name] = []
            pokemon_by_base[base_name].append(name)
    
    print(f"Found {len(pokemon_by_base)} unique Pokemon base forms\n")
    
    # Create output directory
    output_dir = DATA_DIR / "pokemon_moves"
    output_dir.mkdir(exist_ok=True)
    
    successful_count = 0
    failed = []
    errors = []
    
    for i, (base_name, variant_names) in enumerate(pokemon_by_base.items(), 1):
        print(f"[{i}/{len(pokemon_by_base)}] {base_name:<30}", end=" ", flush=True)
        
        try:
            output_data = {}
            has_gen8 = False
            has_gen9 = False
            
            # Try Gen 8 first
            print("(Gen8", end="", flush=True)
            try:
                gen8_moves = fetch_pokemon_moves(base_name, variant_names, 8)
                if gen8_moves:
                    for pokemon_name, move_data in gen8_moves.items():
                        if pokemon_name not in output_data:
                            output_data[pokemon_name] = {}
                        output_data[pokemon_name].update(move_data)
                    has_gen8 = True
                    print("✓", end="", flush=True)
                else:
                    print("—", end="", flush=True)
            except Exception as e:
                print(f"E", end="", flush=True)
                errors.append({
                    'base_name': base_name,
                    'generation': 8,
                    'error': str(e)
                })
            
            # Try Gen 9
            print(" Gen9", end="", flush=True)
            try:
                gen9_moves = fetch_pokemon_moves(base_name, variant_names, 9)
                if gen9_moves:
                    for pokemon_name, move_data in gen9_moves.items():
                        if pokemon_name not in output_data:
                            output_data[pokemon_name] = {}
                        output_data[pokemon_name].update(move_data)
                    has_gen9 = True
                    print("✓", end="", flush=True)
                else:
                    print("—", end="", flush=True)
            except Exception as e:
                print(f"E", end="", flush=True)
                errors.append({
                    'base_name': base_name,
                    'generation': 9,
                    'error': str(e)
                })
            
            # Save if we got data from at least one generation
            if output_data:
                # Add URLs for reference
                if has_gen8:
                    slug = base_name.lower().replace(" ", "").replace("♀", "f").replace("♂", "m")
                    for pokemon_name in output_data.keys():
                        if 'url_gen8' not in output_data[pokemon_name]:
                            output_data[pokemon_name]['url_gen8'] = f"https://www.serebii.net/pokedex-swsh/{slug}/"
                
                if has_gen9:
                    slug = base_name.lower().replace(" ", "").replace("♀", "f").replace("♂", "m")
                    for pokemon_name in output_data.keys():
                        if 'url_gen9' not in output_data[pokemon_name]:
                            output_data[pokemon_name]['url_gen9'] = f"https://www.serebii.net/pokedex-sv/{slug}/"
                
                # Save to file
                output_file = output_dir / f"{base_name}.json"
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(output_data, f, indent=2, ensure_ascii=False)
                
                successful_count += 1
                print(") ✓")
            else:
                failed.append({
                    'base_name': base_name,
                    'reason': 'No data from either generation'
                })
                print(") ✗")
            
            # Be polite to server
            time.sleep(0.3)
            
        except Exception as e:
            errors.append({
                'base_name': base_name,
                'error': str(e)
            })
            print(f") ✗ {str(e)[:30]}")
    
    # Save failures summary
    if failed or errors:
        failures_file = DATA_DIR / "pokemon_moves_failures.json"
        with open(failures_file, 'w', encoding='utf-8') as f:
            json.dump({
                'failed': failed,
                'errors': errors,
                'summary': {
                    'total_failed': len(failed),
                    'total_errors': len(errors)
                }
            }, f, indent=2, ensure_ascii=False)
    
    print(f"\n{'='*70}")
    print(f"=== SUMMARY ===")
    print(f"{'='*70}")
    print(f"✓ Successful: {successful_count}/{len(pokemon_by_base)} Pokemon")
    print(f"✗ Failed: {len(failed)}")
    if failed:
        print(f"  Examples: {', '.join([f['base_name'] for f in failed[:5]])}")
    print(f"✗ Errors: {len(errors)}")
    if errors:
        for err_info in errors[:3]:
            print(f"  {err_info.get('base_name', 'Unknown')}: {str(err_info.get('error', 'Unknown'))[:50]}")
    print(f"\nIndividual files saved to: {output_dir}/")


if __name__ == "__main__":
    main()
