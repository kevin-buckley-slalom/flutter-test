#!/usr/bin/env python3
import json

with open('assets/data/pokemon.json') as f:
    pokemon_list = json.load(f)

with open('data/abilities.json') as f:
    abilities = json.load(f)

# Collect all pokemon names in abilities file
all_ability_pokemon = set()
for ability_data in abilities.values():
    all_ability_pokemon.update(ability_data['pokemon']['regular'])
    all_ability_pokemon.update(ability_data['pokemon']['hidden'])

# The 9 remaining forms without abilities
missing = [
    'Dragonite Mega Dragonite',
    'Eevee Partner Eevee',
    'Eternatus Eternamax',
    'Hawlucha Mega Hawlucha',
    'Malamar Mega Malamar',
    'Pikachu Partner Pikachu',
    'Tatsugiri Droopy Form',
    'Tatsugiri Stretchy Form',
    'Victreebel Mega Victreebel'
]

print("POKEMON FORMS NOT IN ABILITIES FILE")
print("=" * 80)
print()

for target_name in missing:
    for p in pokemon_list:
        if p['name'] == target_name:
            base_name = p.get('base_name')
            variant = p.get('variant')
            
            print(f"NAME: {target_name}")
            print(f"  base_name: {base_name}")
            print(f"  variant: {variant}")
            
            # Check what's available for the base form
            base_abilities = []
            for ability_data in abilities.values():
                if base_name in ability_data['pokemon']['regular']:
                    base_abilities.append((ability_data['name'], 'regular'))
                elif base_name in ability_data['pokemon']['hidden']:
                    base_abilities.append((ability_data['name'], 'hidden'))
            
            if base_abilities:
                print(f"  Base form '{base_name}' abilities:")
                for ability, ability_type in base_abilities:
                    print(f"    - {ability} ({ability_type})")
            else:
                print(f"  Base form '{base_name}' has NO abilities in file")
            
            # Check what's available for the variant specifically
            variant_in_file = variant in all_ability_pokemon if variant else False
            print(f"  Variant '{variant}' in abilities file: {variant_in_file}")
            
            print()
            break
