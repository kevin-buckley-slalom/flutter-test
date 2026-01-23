import os
from pathlib import Path
import json

assets_dir = Path(__file__).parent.parent / "assets" / "images" / "backdrops"
pokemon_json_file = Path(__file__).parent.parent / "assets" / "data" / "pokemon.json"

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
    "Overqwil",
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
    "Kabuto",
    "Kabutops",
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
    "Arctovish",
]

use_secondary_type_for_backdrop = [
    "Pidgey",
    "Pidgeotto",
    "Pidgeot",
    "Spearow",
    "Fearow",
    "Igglybuff",
    "Jigglypuff",
    "Wigglytuff",
    "Dewgong",
    "Lapras",
    "Hoothoot",
    "Noctowl",
    "Sneasel",
    "Weavile",
    "Skarmory",
    "Lugia",
    "Ho-Oh",
    "Celebi",
    "Lotad",
    "Lombre",
    "Tailow",
    "Swellow",
    "Swablu",
    "Altaria",
    "Tropius",
    "Salamence",
    "Rayquaza",
    "Jirachi",
    "Staravia",
    "Staraptor",
    "Bibarel",
    "Wormadam",
    "Stunky",
    "Skuntank",
    "Skorupi",
    "Snover",
    "Abomasnow",
    "Rotom",
    "Dialga",
    "Palkia",
    "Cottonee",
    "Whimsicott",
    "Dwebble",
    "Crustle",
    "Deerling",
    "Sawsbuck",
    # "Pawniard",
    # "Bisharp",
    # "Kingambit",
    "Rufflet",
    "Braviary",
    "Deino",
    "Zweilous",
    "Hydreigon",
    "Larvesta",
    "Volcarona",
    "Reshiram",
    "Zekrom",
    "Kyurem",
    "Meloetta",
    "Diggersby",
    "Fletchinder",
    "Talonflame",
    "Pangoro",
    "Honedge",
    "Doublade",
    "Aegislash",
    "Binacle",
    "Barbaracle",
    "Amaura",
    "Aurorus",
    "Dedenne",
    "Noibat",
    "Noivern",
    "Yveltal",
    "Zygarde",
    "Crabominable",
    "Cutiefly",
    "Ribombee",
    "Mareanie",
    "Toxapex",
    "Salandit",
    "Salazzle",
    "Oranguru",
    "Wimpod",
    "Golisopod",
    "Celesteela",
    "Magearna",
    "Marshadow",
    "Carkoal",
    "Coalossal",
    "Cramorant",
    "Morpeko",
    "Arctozolt",
    "Dreepy",
    "Drakloak",
    "Dragapult",
    "Eternatus",
    "Zarude",
    "Kleavor",
    "Squawkabilly",
    "Armarouge",
    "Ceruledge",
    "Wattrel",
    "Kilowattrel",
    "Rabsca",
    "Tinkatink",
    "Tinkatuff",
    "Tinkaton",
    "Cyclizar",
    "Tatsugiri",
    "Annihilape",
    "Brute Bonnet",
    "Iron Treads",
    "Iron Hands",
    "Frigibax",
    "Arctibax",
    "Baxcalibur",
    "Wo-Chien",
    "Chien-Pao",
    "Ting-Lu",
    "Chi-Yu",
    "Koraidon",
    "Miraidon",
]

form_specific_backdrops = {
    "Diglett Alolan Diglett": "steel.png",
    "Dugtrio Alolan Dugtrio": "steel.png",
    "Palafin Hero Form": "water.png",
    "Exeggutor Alolan Exeggutor": "water.png",
    "Tauros Aqua Breed": "water.png",
    "Tauros Blaze Breed": "fire.png",
    "Latias": "flying.png",
    "Latios": "flying.png",
    "Latias Mega Latias": "flying.png",
    "Latios Mega Latios": "flying.png",
    "Groudon": "fire.png",
    "Groudon Primal Groudon": "fire.png",
    "Piplup": "ice.png",
    "Prinplup": "ice.png",
    "Empoleon": "ice.png",
    "Kyogre Primal Kyogre": "dragon.png",
    "Arceus": "sky_pillar.png",
    "Rayquaza": "sky_pillar.png",
    "Rayquaza Mega Rayquaza": "sky_pillar.png",
    "Audino Mega Audino": "fairy.png",
    "Darmanitian Zen Mode": "psychic.png",
    "Darmanitan Galarian Zen Mode": "fire.png",
    "Zorua Hisuian Zorua": "ghost.png",
    "Zoroark Hisuian Zoroark": "ghost.png",
    "Sliggoo Hisuian Sliggoo": "dragon.png",
    "Goodra Hisuian Goodra": "dragon.png",
    "Pikipek": "water.png",
    "Trumbeak": "water.png",
    "Toucannon": "water.png",
    "Crabrawler": "water.png",
    "Sandyghast": "water.png",
    "Palossand": "water.png",
    "Calyrex Ice Rider": "ice.png",
    "Calyrex Shadow Rider": "ghost.png",
    "Brambleghast": "ground.png",
    "Bramblin": "ground.png",
    "Rellor": "ground.png",
    "Glimmet": "dragon.png",
    "Glimmora": "dragon.png",
    "Ogerpon Wellspring Mask": "water.png",
    "Ogerpon Hearthflame Mask": "fire.png",
    "Ogerpon Cornerstone Mask": "rock.png",
    "Terapagos Normal Form": "dragon.png",
    "Terapagos Terastal Form": "dragon.png",
    "Terapagos Stellar Form": "dragon.png",
    "Palkia Origin Forme": "sky_pillar.png",
    "Dialga Origin Forme": "sky_pillar.png",
    "Giratina Altered Forme": "sky_pillar.png",
    "Giratina Origin Forme": "psychic.png",
}

def map_backdrop_assets(pokemon_data, image_assets):
    for pokemon in pokemon_data:
        full_name = pokemon.get("name")
        base_name = pokemon.get("base_name")
        default_type = pokemon.get("types", [])[0] if pokemon.get("types") else None
        secondary_type = pokemon.get("types", [])[1] if pokemon.get("types") and len(pokemon.get("types")) > 1 else None
        # variant = pokemon.get("variant")

        if full_name in form_specific_backdrops:
            backdrop_filename = form_specific_backdrops[full_name]
            if backdrop_filename in image_assets:
                pokemon["backdrop"] = backdrop_filename
                print(f'Mapped form-specific backdrop for {full_name}')
            else:
                print(f'Form-specific backdrop image not found for {full_name}')

        elif base_name in underwater_pokemon:
            backdrop_filename = "underwater.png"
            if backdrop_filename in image_assets:
                pokemon["backdrop"] = backdrop_filename
                print(f'Mapped underwater backdrop for {base_name}')
            else:
                print(f'Underwater backdrop image not found for {base_name}')
        elif secondary_type and base_name in use_secondary_type_for_backdrop and f'{secondary_type.lower()}.png' in image_assets:
            backdrop_filename = f'{secondary_type.lower()}.png'
            pokemon["backdrop"] = backdrop_filename
            print(f'Mapped {secondary_type} backdrop for {base_name}')
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