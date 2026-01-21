#!/usr/bin/env python3
import json

with open('data/abilities.json') as f:
    abilities = json.load(f)

all_pokemon = set()
for ability_data in abilities.values():
    all_pokemon.update(ability_data['pokemon']['regular'])
    all_pokemon.update(ability_data['pokemon']['hidden'])

# Check for base names and forms
for base in ['Dragonite', 'Hawlucha', 'Malamar', 'Victreebel', 'Eevee', 'Pikachu', 'Eternatus', 'Tatsugiri']:
    found = sorted([p for p in all_pokemon if base in p])
    if found:
        print(f'\n{base}:')
        for p in found:
            print(f'  - {p}')
    else:
        print(f'\n{base}: NOT FOUND')
