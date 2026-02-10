#!/usr/bin/env python3
"""
Normalize StatChangeEffect entries in moves.json to use consistent schema.
- Ensures all StatChangeEffect have probability field (default 100)
- Consolidates stats into 'stats' map with canonical keys
- Removes direct stat keys from effect object
"""

import json
from pathlib import Path

def canonical_stat_key(key):
    """Convert stat key variants to canonical form"""
    mapping = {
        'atk': 'attack',
        'def': 'defense',
        'spa': 'spAtk',
        'spd': 'spDef',
        'spe': 'speed',
        'acc': 'accuracy',
        'eva': 'evasion',
        'attack': 'attack',
        'defense': 'defense',
        'spAtk': 'spAtk',
        'spDef': 'spDef',
        'speed': 'speed',
        'accuracy': 'accuracy',
        'evasion': 'evasion'
    }
    return mapping.get(key, key)

def normalize_move(move):
    """Normalize StatChangeEffect entries in a move"""
    if 'structuredEffects' not in move:
        return move
    
    effects = move['structuredEffects']
    if not isinstance(effects, list):
        return move
    
    for effect in effects:
        if not isinstance(effect, dict):
            continue
            
        if effect.get('type') != 'StatChangeEffect':
            continue
        
        # Add default probability if missing
        if 'probability' not in effect:
            effect['probability'] = 100
        
        # Collect stats from both 'stats' map and direct keys
        stats_map = {}
        
        # Get existing stats map
        if 'stats' in effect and isinstance(effect['stats'], dict):
            for key, value in effect['stats'].items():
                canonical_key = canonical_stat_key(key)
                stats_map[canonical_key] = value
        
        # Check for direct stat keys
        direct_stat_keys = ['accuracy', 'evasion', 'attack', 'defense', 
                           'spAtk', 'spDef', 'speed', 'atk', 'def', 'spa', 'spd', 'spe']
        
        for key in direct_stat_keys:
            if key in effect and key not in ['type', 'target', 'probability', 'stats', 'self']:
                canonical_key = canonical_stat_key(key)
                stats_map[canonical_key] = effect[key]
                # Remove the direct key
                del effect[key]
        
        # Update stats map
        if stats_map:
            effect['stats'] = stats_map
    
    return move

def main():
    # Path to moves.json
    moves_path = Path(__file__).parent.parent / 'assets' / 'data' / 'moves.json'
    
    print(f"Reading {moves_path}")
    with open(moves_path, 'r', encoding='utf-8') as f:
        moves_dict = json.load(f)
    
    print(f"Normalizing {len(moves_dict)} moves...")
    normalized_count = 0
    
    for move_name, move in moves_dict.items():
        original = json.dumps(move.get('structuredEffects', []))
        normalize_move(move)
        if json.dumps(move.get('structuredEffects', [])) != original:
            normalized_count += 1
    
    print(f"Normalized {normalized_count} moves")
    print(f"Writing {moves_path}")
    
    with open(moves_path, 'w', encoding='utf-8') as f:
        json.dump(moves_dict, f, indent=2, ensure_ascii=False)
    
    print("Done!")

if __name__ == '__main__':
    main()
