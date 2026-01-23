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

def copy_image_to_large():
    for p in pokemon_data:
        if "image" in p and "image_large" not in p:
            p["image_large"] = p["image"]
            print(f'Copied image to image_large for {p.get("base_name")}')
            
        if "image_shiny" in p and "image_shiny_large" not in p:
            p["image_shiny_large"] = p["image_shiny"]
            print(f'Copied image_shiny to image_shiny_large for {p.get("base_name")}')
    
if __name__ == "__main__":
    # map_image_assets(pokemon_data, image_assets)
    copy_image_to_large()
    list_missing = [p for p in pokemon_data if "image" not in p]
    list_missing_shiny = [p for p in pokemon_data if "image_shiny" not in p]
    list_missing_large = [p for p in pokemon_data if "image_large" not in p]
    list_missing_shiny_large = [p for p in pokemon_data if "image_shiny_large" not in p]

    print("\nPokemon without mapped images:")
    for p in list_missing:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    print("\nPokemon without mapped shiny images:")
    for p in list_missing_shiny:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    print("\nPokemon without mapped large images:")
    for p in list_missing_large:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    print("\nPokemon without mapped shiny large images:")
    for p in list_missing_shiny_large:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")

    # if list_missing:
    #     print("\nPokemon without mapped images:")
    #     for p in list_missing:
    #         print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    if all((not list_missing, not list_missing_shiny, not list_missing_large, not list_missing_shiny_large)):
        print("✅ All pokemon have images mapped!")
        with open(pokemon_json_file, "w", encoding="utf-8") as f:
            json.dump(pokemon_data, f, indent=2, ensure_ascii=False)