#!/usr/bin/env python3
"""Analyze and categorize multi-hit moves from moves.json."""

import json

# Load moves data
with open('assets/data/moves.json', 'r') as f:
    moves = json.load(f)

# Find multi-hit moves by analyzing in_depth_effect and secondary_effect
multi_hit_moves = []

for move in moves:
    name = move.get('name', '')
    in_depth = move.get('in_depth_effect', '') or ''
    secondary = move.get('secondary_effect', '') or ''
    effect = move.get('effect', '') or ''
    
    # Look for multi-hit indicators
    multi_hit_keywords = [
        'two to five times', '2-5 times', '2 to 5 times',
        'twice', 'two times', 'two hits', 'double hit',
        'three times', 'hits three times',
        'five times', 'hits five times',
        'multiple times', 'several times',
        'two separate hits', 'hits 2 times'
    ]
    
    combined_text = (in_depth + ' ' + secondary + ' ' + effect).lower()
    
    if any(keyword in combined_text for keyword in multi_hit_keywords):
        multi_hit_moves.append({
            'name': name,
            'type': move.get('type'),
            'power': move.get('power'),
            'in_depth_effect': in_depth,
            'secondary_effect': secondary,
            'effect': effect
        })

print(f"Found {len(multi_hit_moves)} multi-hit moves:\n")
print("=" * 80)

# Categorize by hit pattern
two_hit = []
two_five_hit = []
three_hit = []
other = []

for move in multi_hit_moves:
    name = move['name']
    combined = (move['in_depth_effect'] + ' ' + move['secondary_effect']).lower()
    
    if 'twice' in combined or 'two times' in combined or 'two hits' in combined or 'double' in combined or 'hits 2' in combined:
        two_hit.append(move)
    elif '2-5' in combined or 'two to five' in combined or '2 to 5' in combined:
        two_five_hit.append(move)
    elif 'three times' in combined or 'hits three' in combined:
        three_hit.append(move)
    else:
        other.append(move)

print(f"\n2-HIT MOVES ({len(two_hit)}):")
print("-" * 80)
for move in two_hit:
    print(f"  • {move['name']} ({move['type']}, Power: {move['power']})")
    if move['in_depth_effect']:
        print(f"    In-depth: {move['in_depth_effect'][:100]}...")

print(f"\n\n2-5 HIT MOVES ({len(two_five_hit)}):")
print("-" * 80)
for move in two_five_hit:
    print(f"  • {move['name']} ({move['type']}, Power: {move['power']})")
    if move['in_depth_effect']:
        print(f"    In-depth: {move['in_depth_effect'][:100]}...")

print(f"\n\n3-HIT MOVES ({len(three_hit)}):")
print("-" * 80)
for move in three_hit:
    print(f"  • {move['name']} ({move['type']}, Power: {move['power']})")
    if move['in_depth_effect']:
        print(f"    In-depth: {move['in_depth_effect'][:100]}...")

print(f"\n\nOTHER PATTERNS ({len(other)}):")
print("-" * 80)
for move in other:
    print(f"  • {move['name']} ({move['type']}, Power: {move['power']})")
    if move['in_depth_effect']:
        print(f"    In-depth: {move['in_depth_effect'][:150]}...")

print("\n" + "=" * 80)
print(f"\nTOTAL: {len(multi_hit_moves)} multi-hit moves")
