import os
from pathlib import Path
import json

assets_dir = Path(__file__).parent.parent / "assets" / "images" / "pokemon"
assets_large_dir = Path(__file__).parent.parent / "assets" / "images_large" / "pokemon"
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

def transform_img_name(name):
    name = name[:-4]  # remove extension
    name = name.lower().replace(' ', '_')
    name = name.replace('-', '_')
    name = ''.join(c for c in name if c.isalnum() or c == '_')
    return name + '.png'

def rename_image_files(image_dir: Path):
    for img_file in image_dir.iterdir():
        if img_file.is_file():
            transformed_name = transform_img_name(img_file.name)
            if img_file.name != transformed_name:
                new_path = image_dir / transformed_name
                img_file.rename(new_path)
                print(f'Renamed {img_file.name} to {transformed_name}')

def fix_png_extensions():
    for img_file in assets_large_dir.iterdir():
        if img_file.is_file() and img_file.suffix.lower() != '.png' and img_file.name.endswith('png'):
            new_path = img_file.name[:-3]
            new_path = Path(assets_large_dir / new_path).with_suffix('.png')
            img_file.rename(new_path)
            print(f'Fixed extension for {img_file.name} to .png')
    
if __name__ == "__main__":
    # rename_image_files(assets_dir)
    # fix_png_extensions()
    # map_image_assets(pokemon_data, image_assets)
    # copy_image_to_large()
    list_missing = []
    list_missing_shiny = []
    list_missing_large = []
    list_missing_shiny_large = []
    transforming = {}
    for p in pokemon_data:
        image = p.get("image")
        image_shiny = p.get("image_shiny")
        image_large = p.get("image_large")
        image_shiny_large = p.get("image_shiny_large")
        if image and not Path(assets_dir / image).is_file():
            transformed = transform_img_name(image)
            if Path(assets_dir / transformed).is_file():
                print(f'Image filename for {p.get("base_name")} will be transformed to {transformed}')
                p["image"] = transformed
                transforming.setdefault(p.get("name"), {})["image"] = transformed
            else:
                list_missing.append(p)
        elif not image:
            print(f'No image field for {p.get("base_name")}')
        if image_shiny and not Path(assets_dir / image_shiny).is_file():
            transformed_shiny = transform_img_name(image_shiny)
            if Path(assets_dir / transformed_shiny).is_file():
                print(f'Image_shiny filename for {p.get("base_name")} will be transformed to {transformed_shiny}')
                p["image_shiny"] = transformed_shiny
                transforming.setdefault(p.get("name"), {})["image_shiny"] = transformed_shiny
            else:
                list_missing_shiny.append(p)
        elif not image_shiny:
            print(f'No image_shiny field for {p.get("base_name")}')
        if image_large and  not Path(assets_large_dir / image_large).is_file():
            transformed_large = transform_img_name(image_large)
            if Path(assets_large_dir / transformed_large).is_file():
                print(f'Image_large filename for {p.get("base_name")} will be transformed to {transformed_large}')
                p["image_large"] = transformed_large
                transforming.setdefault(p.get("name"), {})["image_large"] = transformed_large
            else:
                list_missing_large.append(p)
        elif not image_large:
            print(f'No image_large field for {p.get("base_name")}')
        if image_shiny_large and not Path(assets_large_dir / image_shiny_large).is_file():
            transformed_shiny_large = transform_img_name(image_shiny_large)
            if Path(assets_large_dir / transformed_shiny_large).is_file():
                print(f'Image_shiny_large filename for {p.get("base_name")} will be transformed to {transformed_shiny_large}')
                p["image_shiny_large"] = transformed_shiny_large
                transforming.setdefault(p.get("name"), {})["image_shiny_large"] = transformed_shiny_large
            else:
                list_missing_shiny_large.append(p)
        elif not image_shiny_large:
            print(f'No image_shiny_large field for {p.get("base_name")}')

    # list_missing = [p for p in pokemon_data if "image" not in p]
    # list_missing_shiny = [p for p in pokemon_data if "image_shiny" not in p]
    # list_missing_large = [p for p in pokemon_data if "image_large" not in p]
    # list_missing_shiny_large = [p for p in pokemon_data if "image_shiny_large" not in p]

    print("\nPokemon missing regular sprites:")
    for p in list_missing:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    print("\nPokemon missing shiny sprites:")
    for p in list_missing_shiny:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    print("\nPokemon missing large images:")
    for p in list_missing_large:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")
    print("\nPokemon missing shiny large images:")
    for p in list_missing_shiny_large:
        print(f"- {p.get('base_name')} (variant: {p.get('variant')})")

    if all((not list_missing, not list_missing_shiny, not list_missing_large, not list_missing_shiny_large, not transforming)):
        print("✅ All pokemon have images mapped!")
    #     print("✅ All pokemon have images mapped!")
    #     with open(pokemon_json_file, "w", encoding="utf-8") as f:
    #         json.dump(pokemon_data, f, indent=2, ensure_ascii=False)