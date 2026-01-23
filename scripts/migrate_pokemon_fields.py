import os
from pathlib import Path
import json


pokemon_asset = Path(__file__).parent.parent / "assets" / "data" / "pokemon.json"
pokemon_data_file = Path(__file__).parent.parent / "data" / "pokemon.json"

fields_to_migrate = [
    # "image",
    # "image_shiny",
    # "image_large",
    # "image_shiny_large",
    "backdrop",
    # "classification",
    # "capture_rate",
    # "height_imperial",
    # "height_metric",
    # "weight_imperial",
    # "weight_metric",
    # "gender_ratio"
]

with open(pokemon_asset, "r", encoding="utf-8") as f:
    pokemon_asset_data = json.load(f)

with open(pokemon_data_file, "r", encoding="utf-8") as f:
    pokemon_data = json.load(f)

# Create a mapping from pokemon name to its asset data
asset_data_map = {p["name"]: p for p in pokemon_asset_data}

# Migrate fields from pokemon.json in data folder to assets data
for pokemon in pokemon_data:
    name = pokemon["name"]
    asset_data = asset_data_map.get(name)
    if not asset_data:
        print(f"WARNING: No asset data found for {name}")
        continue

    for field in fields_to_migrate:
        if field in pokemon:
            asset_data[field] = pokemon.get(field)


# Save the updated asset data back to the file
with open(pokemon_asset, "w", encoding="utf-8") as f:
    json.dump(pokemon_asset_data, f, indent=2, ensure_ascii=False)
    print(f"✅ Successfully migrated fields to {pokemon_asset}")
