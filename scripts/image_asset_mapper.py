import os
from pathlib import Path
import json

assets_dir = Path(__file__).parent.parent / "assets" / "images_large" / "pokemon"
pokemon_json_file = Path(__file__).parent.parent / "assets" / "data" / "pokemon.json"

with open(pokemon_json_file, "r", encoding="utf-8") as f:
    pokemon_data = json.load(f)

image_assets = [item.name for item in assets_dir.iterdir() if item.is_file()]

def map_image_assets(pokemon_data, image_assets):
    for pokemon in pokemon_data:
        base_name = pokemon.get("base_name")
        variant = pokemon.get("variant")

        if not variant and f'{base_name.replace(" ", "_").lower()}.png' in image_assets:
            pokemon["image_large"] = f'{base_name.replace(" ", "_").lower()}.png'
            pokemon["image_shiny_large"] = f'{base_name.replace(" ", "_").lower()}_shiny.png' if f'{base_name.replace(" ", "_").lower()}_shiny.png' in image_assets else None
            print(f'Mapped base image for {base_name}')

        elif variant and f'{variant.replace(" ", "_").lower()}.png' in image_assets:
            pokemon["image_large"] = f'{variant.replace(" ", "_").lower()}.png'
            pokemon["image_shiny_large"] = f'{variant.replace(" ", "_").lower()}_shiny.png' if f'{variant.replace(" ", "_").lower()}_shiny.png' in image_assets else None
            print(f'Mapped variant image for {base_name} ({variant})')

        elif variant and f'{base_name.replace(" ", "_").lower()}_{variant.replace(" ", "_").lower()}.png' in image_assets:
            pokemon["image_large"] = f'{base_name.replace(" ", "_").lower()}_{variant.replace(" ", "_").lower()}.png'
            pokemon["image_shiny_large"] = f'{base_name.replace(" ", "_").lower()}_{variant.replace(" ", "_").lower()}_shiny.png' if f'{base_name.replace(" ", "_").lower()}_{variant.replace(" ", "_").lower()}_shiny.png' in image_assets else None
            print(f'Mapped variant image for {base_name} ({variant})')

        else:
            print(f"Could not find image for {base_name} (variant: {variant})")

if __name__ == "__main__":
    map_image_assets(pokemon_data, image_assets)
    list_missing = [p for p in pokemon_data if "image_large" not in p]
    if list_missing:
        print("\nPokemon without mapped images:")
        for p in list_missing:
            print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    with open(pokemon_json_file, "w", encoding="utf-8") as f:
        json.dump(pokemon_data, f, indent=2, ensure_ascii=False)