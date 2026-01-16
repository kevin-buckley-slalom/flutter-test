# Pokémon Dataset

Generated from:
- National Pokédex ordering and generation grouping: https://pokemondb.net/pokedex/national
- Stats table: https://pokemondb.net/pokedex/all

Run the builder to regenerate:

```bash
python scripts/build_pokemon_data.py
```

## Schema
- `number` (int): National Pokédex number (shared by variants)
- `name` (string): Full display name (e.g., "Alolan Rattata" or "Rattata")
- `base_name` (string): Base Pokémon name without variant prefix (e.g., "Rattata")
- `variant` (string|null): Variant identifier like "Alolan", "Galarian", "Hisuian", or `null` for base form
- `generation` (int): 1–9
- `types` (string[]): one or two types, in site order
- `stats` (object):
  - `total`, `hp`, `attack`, `defense`, `sp_atk`, `sp_def`, `speed`

Outputs
- `data/pokemon.json`: ordered list of all Pokémon objects (including variants)
- `data/pokemon_by_number.json`: map number -> list of Pokémon (handles multiple variants per number)
- `data/pokemon_by_name.json`: map lowercase name -> Pokémon (single entry per unique name)
- `data/pokemon_by_base_name.json`: map lowercase base_name -> list of variants (hierarchical access)

## Example objects

Base form:
```json
{
  "number": 19,
  "name": "Rattata",
  "base_name": "Rattata",
  "variant": null,
  "generation": 1,
  "types": ["Normal"],
  "stats": {
    "total": 253,
    "hp": 30,
    "attack": 56,
    "defense": 35,
    "sp_atk": 25,
    "sp_def": 35,
    "speed": 72
  }
}
```

Variant form:
```json
{
  "number": 19,
  "name": "Alolan Rattata",
  "base_name": "Rattata",
  "variant": "Alolan",
  "generation": 7,
  "types": ["Dark", "Normal"],
  "stats": {
    "total": 253,
    "hp": 30,
    "attack": 56,
    "defense": 35,
    "sp_atk": 25,
    "sp_def": 35,
    "speed": 72
  }
}
```

## Variant Support

Pokémon variants (regional forms, alternate forms) share the same National Pokédex number but have distinct types and/or stats. Each variant is a separate entry in the dataset:
- Same `number` identifies the base Pokémon species
- `variant` field distinguishes forms (null for base, string for variants)
- `base_name` provides hierarchical grouping
- Use `pokemon_by_base_name.json` to get all variants of a Pokémon

