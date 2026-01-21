#!/usr/bin/env python3
"""
Add abilities mapping to pokemon.json from abilities.json
Maps each pokemon form to its regular and hidden abilities for fast bidirectional lookup.
"""
import json
from pathlib import Path

def main():
    # Load files
    project_root = Path(__file__).parent.parent
    abilities_path = project_root / "data" / "abilities.json"
    pokemon_path = project_root / "assets" / "data" / "pokemon.json"
    
    with open(abilities_path) as f:
        abilities_data = json.load(f)
    
    with open(pokemon_path) as f:
        pokemon_data = json.load(f)
    
    # Create reverse mapping: pokemon name -> abilities
    pokemon_abilities = {}
    
    for ability_name, ability_info in abilities_data.items():
        # Add regular abilities
        for pokemon_name in ability_info["pokemon"]["regular"]:
            if pokemon_name not in pokemon_abilities:
                pokemon_abilities[pokemon_name] = {"regular": [], "hidden": []}
            if ability_name not in pokemon_abilities[pokemon_name]["regular"]:
                pokemon_abilities[pokemon_name]["regular"].append(ability_name)
        
        # Add hidden abilities
        for pokemon_name in ability_info["pokemon"]["hidden"]:
            if pokemon_name not in pokemon_abilities:
                pokemon_abilities[pokemon_name] = {"regular": [], "hidden": []}
            if ability_name not in pokemon_abilities[pokemon_name]["hidden"]:
                pokemon_abilities[pokemon_name]["hidden"].append(ability_name)
    
    # Add abilities to each pokemon in pokemon.json
    updated_count = 0
    not_found_count = 0
    not_found_pokemon = []
    
    for pokemon in pokemon_data:
        pokemon_name = pokemon["name"]
        pokemon_variant = pokemon.get("variant")
        pokemon_base_name = pokemon.get("base_name")
        
        # Try multiple matching strategies
        matched_name = None
        
        # Strategy 1: Exact match on full name
        if pokemon_name in pokemon_abilities:
            matched_name = pokemon_name
        # Strategy 2: Match on variant name only
        elif pokemon_variant and pokemon_variant in pokemon_abilities:
            matched_name = pokemon_variant
        # Strategy 3: Match on "base_name variant" format
        elif pokemon_base_name and pokemon_variant and f'{pokemon_base_name} {pokemon_variant}' in pokemon_abilities:
            matched_name = f'{pokemon_base_name} {pokemon_variant}'
        # Strategy 4: Match on "variant base_name" format (for reversed order like "Trash Cloak Burmy")
        elif pokemon_base_name and pokemon_variant and f'{pokemon_variant} {pokemon_base_name}' in pokemon_abilities:
            matched_name = f'{pokemon_variant} {pokemon_base_name}'
        
        if matched_name:
            # Add abilities field
            pokemon["abilities"] = {
                "regular": sorted(pokemon_abilities[matched_name]["regular"]),
                "hidden": sorted(pokemon_abilities[matched_name]["hidden"])
            }
            updated_count += 1
        else:
            # Pokemon not found in abilities data - add empty structure
            pokemon["abilities"] = {
                "regular": [],
                "hidden": []
            }
            not_found_count += 1
            not_found_pokemon.append(pokemon_name)
    
    # Save updated pokemon.json
    with open(pokemon_path, 'w') as f:
        json.dump(pokemon_data, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Successfully updated pokemon.json")
    print(f"   - {updated_count} pokemon updated with abilities")
    print(f"   - {not_found_count} pokemon not found in abilities data")
    
    print(f"\n   Total abilities mapped: {len(pokemon_abilities)}")
    print(f"   Total pokemon in pokemon.json: {len(pokemon_data)}")
    
    # Show all pokemon without abilities
    if not_found_pokemon:
        print(f"\n⚠️  Pokemon forms without abilities ({not_found_count}):")
        print("="*70)
        for name in sorted(not_found_pokemon):
            print(f"   - {name}")
        
        # Save to file for easier analysis
        report_path = project_root / "data" / "pokemon_without_abilities.txt"
        with open(report_path, 'w') as f:
            f.write(f"Pokemon forms without abilities mapping ({not_found_count} total)\n")
            f.write("="*70 + "\n\n")
            for name in sorted(not_found_pokemon):
                f.write(f"{name}\n")
        print(f"\n📄 Full list saved to: {report_path}")

if __name__ == "__main__":
    main()
