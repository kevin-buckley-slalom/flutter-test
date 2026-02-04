#!/usr/bin/env python3
"""
Merge enhanced move data from Serebii into the existing moves.json file.

This script takes the enhanced data collected from Serebii and adds the new fields
to each move without overwriting existing data.
"""

import json
import pathlib
import shutil
from datetime import datetime


# Paths
ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
ASSETS_DIR = ROOT / "assets" / "data"


def main():
    """Main execution function."""
    print("=== Merge Enhanced Move Data ===\n")
    
    # Load existing moves
    moves_path = ASSETS_DIR / "moves.json"
    print(f"Loading existing moves from: {moves_path}")
    
    with open(moves_path, 'r', encoding='utf-8') as f:
        moves = json.load(f)
    
    print(f"Loaded {len(moves)} moves")
    
    # Load enhanced data
    enhanced_path = DATA_DIR / "moves_enhanced.json"
    print(f"Loading enhanced data from: {enhanced_path}")
    
    if not enhanced_path.exists():
        print(f"Error: Enhanced data file not found at {enhanced_path}")
        return
    
    with open(enhanced_path, 'r', encoding='utf-8') as f:
        enhanced_data = json.load(f)
    
    print(f"Loaded enhanced data for {len(enhanced_data)} moves\n")
    
    # Create backup
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = ASSETS_DIR / f"moves_backup_{timestamp}.json"
    print(f"Creating backup: {backup_path}")
    shutil.copy(moves_path, backup_path)
    
    # Merge data
    print("\nMerging enhanced data...")
    merged_count = 0
    missing_count = 0
    
    for move_name, move_data in moves.items():
        if move_name in enhanced_data:
            enhanced = enhanced_data[move_name]
            
            # Add new fields
            if enhanced.get('in_depth_effect'):
                move_data['in_depth_effect'] = enhanced['in_depth_effect']
            
            if enhanced.get('secondary_effect'):
                move_data['secondary_effect'] = enhanced['secondary_effect']
            
            if enhanced.get('effect_rate') is not None:
                move_data['effect_chance'] = enhanced['effect_rate']
            
            if enhanced.get('base_critical_hit_rate'):
                move_data['crit_rate'] = enhanced['base_critical_hit_rate']
            
            if enhanced.get('boolean_attributes'):
                # Flatten boolean attributes into the move data
                for key, value in enhanced['boolean_attributes'].items():
                    new_key = key
                    if '_details' in key:
                        new_key = key.replace('_details', '')
                    move_data[new_key] = value
            
            merged_count += 1
        else:
            missing_count += 1
    
    print(f"✓ Merged data for {merged_count} moves")
    print(f"⚠ {missing_count} moves not found in enhanced data")
    
    # Save merged data
    print(f"\nSaving merged data to: {moves_path}")
    with open(moves_path, 'w', encoding='utf-8') as f:
        json.dump(moves, f, indent=2, ensure_ascii=False)
    
    print("\n=== Summary ===")
    print(f"✓ Successfully merged {merged_count} moves")
    print(f"✓ Backup saved to: {backup_path}")
    print(f"⚠ {missing_count} moves missing enhanced data")
    
    # Load and display unusable moves
    unusable_path = DATA_DIR / "moves_unusable.json"
    if unusable_path.exists():
        with open(unusable_path, 'r', encoding='utf-8') as f:
            unusable = json.load(f)
        print(f"\nℹ {len(unusable)} moves marked as unusable:")
        for move in unusable[:10]:
            print(f"  - {move['name']}")
        if len(unusable) > 10:
            print(f"  ... and {len(unusable) - 10} more")


if __name__ == "__main__":
    main()
