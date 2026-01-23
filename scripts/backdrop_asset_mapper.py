import os
from pathlib import Path
import json

assets_dir = Path(__file__).parent.parent / "assets" / "images" / "backdrops"
pokemon_json_file = Path(__file__).parent.parent / "data" / "pokemon.json"

with open(pokemon_json_file, "r", encoding="utf-8") as f:
    pokemon_data = json.load(f)

image_assets = [item.name for item in assets_dir.iterdir() if item.is_file()]

# Water types to fix later:
# - Kyogre (stormy special backdrop)
# - Piplup line (iceberg backdrop)
# - Hero form palafin not underwater

underwater_pokemon = [
    "Tentacool",
    "Tentacruel",
    "Seel",
    "Dewgong",
    "Shellder",
    "Cloyster",
    "Horsea",
    "Seadra",
    "Goldeen",
    "Seaking",
    "Magikarp",
    "Gyarados",
    "Chinchou",
    "Lanturn",
    "Qwilfish",
    "Corsola",
    "Cursola",
    "Remoraid",
    "Octillery",
    "Mantine",
    "Kingdra",
    "Carvanha",
    "Sharpedo",
    "Wailmer",
    "Wailord",
    "Omanite",
    "Omastar",
    "Barboach",
    "Whiscash",
    "Feebas",
    "Clamperl",
    "Huntail",
    "Gorebyss",
    "Relicanth",
    "Luvdisc",
    "Kyogre",
    "Finneon",
    "Lumineon",
    "Mantyke",
    "Basculin",
    "Frillish",
    "Jellicent",
    "Alomomola",
    "Skrelp",
    "Dragalge",
    "Clauncher",
    "Clawitzer",
    "Wishiwashi",
    "Bruxish",
    "Arrokuda",
    "Barraskewda",
    "Basculegion",
    "Finizen",
    "Palafin",
    "Veluza",
    "Dondozo",
]

def map_backdrop_assets(pokemon_data, image_assets):
    for pokemon in pokemon_data:
        base_name = pokemon.get("base_name")
        default_type = pokemon.get("types", [])[0] if pokemon.get("types") else None
        # variant = pokemon.get("variant")

        if base_name in underwater_pokemon:
            backdrop_filename = "underwater.png"
            if backdrop_filename in image_assets:
                pokemon["backdrop"] = backdrop_filename
                print(f'Mapped underwater backdrop for {base_name}')
            else:
                print(f'Underwater backdrop image not found for {base_name}')
        elif default_type != None and f'{default_type.lower()}.png' in image_assets:
            backdrop_filename = f'{default_type.lower()}.png'
            pokemon["backdrop"] = backdrop_filename
            print(f'Mapped {default_type} backdrop for {base_name}')
        else:
            backdrop_filename = "grass.png"
            if backdrop_filename in image_assets:
                pokemon["backdrop"] = backdrop_filename
                print(f'Mapped default grass backdrop for {base_name}')
            else:
                print(f"Could not find backdrop for {base_name} (type: {default_type}), default grass.png")


if __name__ == "__main__":
    map_backdrop_assets(pokemon_data, image_assets)
    list_missing = [p for p in pokemon_data if "backdrop" not in p]
    if list_missing:
        print("\nPokemon without mapped images:")
        for p in list_missing:
            print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    with open(pokemon_json_file, "w", encoding="utf-8") as f:
        json.dump(pokemon_data, f, indent=2, ensure_ascii=False)