#!/usr/bin/env python3
"""
Generate a reverse index mapping moves to pokemon for fast lookup.
This creates a moves_by_pokemon.json file that can be loaded instantly
instead of scanning through 1000+ pokemon move files.
"""

import json
import os
from collections import defaultdict

POKEMON_MOVES_DIR = 'assets/data/pokemon_moves'
OUTPUT_FILE = 'assets/data/moves_by_pokemon.json'

def generate_moves_index():
    """Generate a move -> pokemon mapping from all pokemon move files."""
    moves_index = defaultdict(lambda: defaultdict(list))
    
    # Get all pokemon move files
    if not os.path.exists(POKEMON_MOVES_DIR):
        print(f"Error: {POKEMON_MOVES_DIR} not found")
        return
    
    move_files = [f for f in os.listdir(POKEMON_MOVES_DIR) if f.endswith('.json')]
    print(f"Processing {len(move_files)} pokemon move files...")
    
    for i, filename in enumerate(move_files):
        if (i + 1) % 100 == 0:
            print(f"  Processed {i + 1}/{len(move_files)}...")
        
        filepath = os.path.join(POKEMON_MOVES_DIR, filename)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                pokemon_data = json.load(f)
            
            # Extract pokemon name from filename (remove .json)
            pokemon_base_name = filename[:-5]
            
            # Traverse the structure: pokemon -> variant -> generation -> game -> learnType -> moves
            for variant, variant_data in pokemon_data.items():
                if not isinstance(variant_data, dict):
                    continue
                
                for generation, gen_data in variant_data.items():
                    if not isinstance(gen_data, dict):
                        continue
                    
                    for game, game_data in gen_data.items():
                        if not isinstance(game_data, dict):
                            continue
                        
                        for learn_type, moves_list in game_data.items():
                            if not isinstance(moves_list, list):
                                continue
                            
                            for move_entry in moves_list:
                                if isinstance(move_entry, dict) and 'name' in move_entry:
                                    move_name = move_entry['name'].lower()
                                    pokemon_name = variant if variant else pokemon_base_name
                                    
                                    # Store the move entry with learn type info
                                    move_info = {
                                        'learnType': learn_type,
                                        'level': move_entry.get('level', '—'),
                                    }
                                    if 'tm_id' in move_entry:
                                        move_info['tmId'] = move_entry['tm_id']
                                    
                                    moves_index[move_name][pokemon_name].append(move_info)
        
        except Exception as e:
            print(f"  Error processing {filename}: {e}")
    
    # Convert defaultdicts to regular dicts
    result = {}
    for move_name, pokemon_dict in moves_index.items():
        result[move_name] = dict(pokemon_dict)
    
    # Write output file
    print(f"Writing index to {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    
    print(f"Done! Generated index with {len(result)} moves")
    print(f"File size: {os.path.getsize(OUTPUT_FILE) / 1024 / 1024:.2f} MB")

if __name__ == '__main__':
    generate_moves_index()
