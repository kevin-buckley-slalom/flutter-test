from pathlib import Path
import os
import json

images_dir = Path(__file__).parent.parent / "data" / "images_large"
pokemon_json_file = Path(__file__).parent.parent / "assets" / "data" / "pokemon_by_number.json"

with open(pokemon_json_file, "r", encoding="utf-8") as f:
    pokemon_data = json.load(f)

def rename_sprites(range_start: int, range_end: int):
    for number_dir in images_dir.iterdir():
        if not number_dir.is_dir():
            continue
        elif not (range_start <= int(number_dir.name) <= range_end):
            continue

        pokemon_list = pokemon_data.get(number_dir.name)
        if not pokemon_list:
            print(f"No data for {number_dir.name}; skipping")
            continue

        pokemon = pokemon_list[0]
        pokemon_name = pokemon.get("base_name")
        if not pokemon_name:
            print(f"No base_name for {number_dir.name}; skipping")
            continue

        img_files = list(number_dir.iterdir())
        if len(img_files) == 0:
            print(f"No images found in {number_dir}; deleting directory.")
            number_dir.rmdir()
            continue

        for img_file in number_dir.iterdir():
            if not img_file.is_file():
                continue

            if '_back_' in img_file.name or '_backshiny_' in img_file.name:
                print(f"deleting back image {img_file}")
                img_file.unlink()
                continue
            elif '_tinymushroom_' in img_file.name:
                print(f"deleting tiny mushroom image {img_file}")
                img_file.unlink()
                continue

            if img_file.name.endswith(f'{pokemon_name.lower()}.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif pokemon_name.lower() == "farfetch'd":
                if img_file.name.endswith('farfetchd.png'):
                    new_name = 'farfetchd.png'
                elif img_file.name.endswith('farfetchd_shiny.png'):
                    new_name = 'farfetchd_shiny.png'
                elif img_file.name.endswith('farfetchd-galarian.png'):
                    new_name = 'galarian_farfetchd.png'
                elif img_file.name.endswith('farfetchd-galarian_shiny.png'):
                    new_name = 'galarian_farfetchd_shiny.png'
                else:
                    print(f"Unrecognized image file {img_file}; skipping.")
                    continue
            elif pokemon_name.lower() == "sirfetch'd":
                if img_file.name.endswith('sirfetchd.png'):
                    new_name = 'sirfetchd.png'
                elif img_file.name.endswith('sirfetchd_shiny.png'):
                    new_name = 'sirfetchd_shiny.png'
                else:
                    print(f"Unrecognized image file {img_file}; skipping.")
                    continue
            elif pokemon_name.lower() == "mr. mime":
                if img_file.name.endswith('mr-mime.png'):
                    new_name = 'mr_mime.png'
                elif img_file.name.endswith('mr-mime_shiny.png'):
                    new_name = 'mr_mime_shiny.png'
                elif img_file.name.endswith('mr-mime-galarian.png'):
                    new_name = 'galarian_mr_mime.png'
                elif img_file.name.endswith('mr-mime-galarian_shiny.png'):
                    new_name = 'galarian_mr_mime_shiny.png'
                else:
                    print(f"Unrecognized image file {img_file}; skipping.")
                    continue
            elif pokemon_name.lower() == "type: null":
                if img_file.name.endswith('type-null.png'):
                    new_name = 'type_null.png'
                elif img_file.name.endswith('type-null_shiny.png'):
                    new_name = 'type_null_shiny.png'
                else:
                    print(f"Unrecognized image file {img_file}; skipping.")
                    continue
            elif pokemon_name.lower() == "mime jr.":
                if img_file.name.endswith('mime-jr.png'):
                    new_name = 'mime_jr.png'
                elif img_file.name.endswith('mime-jr_shiny.png'):
                    new_name = 'mime_jr_shiny.png'
                else:
                    print(f"Unrecognized image file {img_file}; skipping.")
                    continue
            elif pokemon_name.lower() == "mr. rime":
                if img_file.name.endswith('mr-rime.png'):
                    new_name = 'mr_rime.png'
                elif img_file.name.endswith('mr-rime_shiny.png'):
                    new_name = 'mr_rime_shiny.png'
                else:
                    print(f"Unrecognized image file {img_file}; skipping.")
                    continue
            elif img_file.name.endswith(f'{pokemon_name.lower()}-alolan.png'):
                new_name = f"alolan_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-alolan_shiny.png'):
                new_name = f"alolan_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-f.png'):
                new_name = f"{pokemon_name.lower()}_alt_female.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-f_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_female_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-galarian.png'):
                new_name = f"galarian_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-galarian_shiny.png'):
                new_name = f"galarian_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hisuian.png'):
                new_name = f"hisuian_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hisuian_shiny.png'):
                new_name = f"hisuian_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hisuian-f.png'):
                new_name = f"hisuian_{pokemon_name.lower()}_alt_female.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hisuian-f_shiny.png'):
                new_name = f"hisuian_{pokemon_name.lower()}_alt_female_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mega.png'):
                new_name = f"mega_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mega_shiny.png'):
                new_name = f"mega_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mega-x.png'):
                new_name = f"mega_{pokemon_name.lower()}_x.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mega-x_shiny.png'):
                new_name = f"mega_{pokemon_name.lower()}_x_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mega-y.png'):
                new_name = f"mega_{pokemon_name.lower()}_y.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mega-y_shiny.png'):
                new_name = f"mega_{pokemon_name.lower()}_y_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-gigantamax.png'):
                new_name = f"{pokemon_name.lower()}_alt_gigantamax.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-gigantamax_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_gigantamax_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean.png'):
                new_name = f"paldean_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean_shiny.png'):
                new_name = f"paldean_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-primal.png'):
                new_name = f"primal_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-primal_shiny.png'):
                new_name = f"primal_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-therian.png'):
                new_name = f"{pokemon_name.lower()}_therian_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-therian_shiny.png'):
                new_name = f"{pokemon_name.lower()}_therian_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-origin.png'):
                new_name = f"{pokemon_name.lower()}_origin_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-origin_shiny.png'):
                new_name = f"{pokemon_name.lower()}_origin_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-attack.png'):
                new_name = f"{pokemon_name.lower()}_attack_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-attack_shiny.png'):
                new_name = f"{pokemon_name.lower()}_attack_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-defense.png'):
                new_name = f"{pokemon_name.lower()}_defense_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-defense_shiny.png'):
                new_name = f"{pokemon_name.lower()}_defense_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-speed.png'):
                new_name = f"{pokemon_name.lower()}_speed_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-speed_shiny.png'):
                new_name = f"{pokemon_name.lower()}_speed_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-school.png'):
                new_name = f"{pokemon_name.lower()}_school_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-school_shiny.png'):
                new_name = f"{pokemon_name.lower()}_school_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-single-strike.png'):
                new_name = f"{pokemon_name.lower()}_single_strike_style.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-single-strike_shiny.png'):
                new_name = f"{pokemon_name.lower()}_single_strike_style_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-rapid-strike.png'):
                new_name = f"{pokemon_name.lower()}_rapid_strike_style.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-rapid-strike_shiny.png'):
                new_name = f"{pokemon_name.lower()}_rapid_strike_style_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-incarnate.png'):
                new_name = f"{pokemon_name.lower()}_incarnate_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-incarnate_shiny.png'):
                new_name = f"{pokemon_name.lower()}_incarnate_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean-aqua.png'):
                new_name = f"{pokemon_name.lower()}_aqua_breed.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean-aqua_shiny.png'):
                new_name = f"{pokemon_name.lower()}_aqua_breed_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean-blaze.png'):
                new_name = f"{pokemon_name.lower()}_blaze_breed.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean-blaze_shiny.png'):
                new_name = f"{pokemon_name.lower()}_blaze_breed_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean-combat.png'):
                new_name = f"{pokemon_name.lower()}_combat_breed.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-paldean-combat_shiny.png'):
                new_name = f"{pokemon_name.lower()}_combat_breed_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-rainy.png'):
                new_name = f"{pokemon_name.lower()}_rainy_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-rainy_shiny.png'):
                new_name = f"{pokemon_name.lower()}_rainy_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sunny.png'):
                new_name = f"{pokemon_name.lower()}_sunny_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sunny_shiny.png'):
                new_name = f"{pokemon_name.lower()}_sunny_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-snowy.png'):
                new_name = f"{pokemon_name.lower()}_snowy_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-snowy_shiny.png'):
                new_name = f"{pokemon_name.lower()}_snowy_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-normal.png'):
                if pokemon_name.lower() == "deoxys":
                    new_name = f"{pokemon_name.lower()}_normal_forme.png"
                else:
                    new_name = f"{pokemon_name.lower()}_normal_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-normal_shiny.png'):
                if pokemon_name.lower() == "deoxys":
                    new_name = f"{pokemon_name.lower()}_normal_forme_shiny.png"
                else:
                    new_name = f"{pokemon_name.lower()}_normal_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-plant.png'):
                new_name = f"{pokemon_name.lower()}_plant_cloak.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-plant_shiny.png'):
                new_name = f"{pokemon_name.lower()}_plant_cloak_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sandy.png'):
                new_name = f"{pokemon_name.lower()}_sandy_cloak.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sandy_shiny.png'):
                new_name = f"{pokemon_name.lower()}_sandy_cloak_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-trash.png'):
                new_name = f"{pokemon_name.lower()}_trash_cloak.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-trash_shiny.png'):
                new_name = f"{pokemon_name.lower()}_trash_cloak_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-overcast.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-overcast_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sunshine.png'):
                new_name = f"{pokemon_name.lower()}_alt_sunshine_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sunshine_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_sunshine_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-west.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-west_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-east.png'):
                new_name = f"{pokemon_name.lower()}_alt_east_sea_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-east_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_east_sea_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-fan.png'):
                new_name = f"fan_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-fan_shiny.png'):
                new_name = f"fan_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-frost.png'):
                new_name = f"frost_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-frost_shiny.png'):
                new_name = f"frost_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-heat.png'):
                new_name = f"heat_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-heat_shiny.png'):
                new_name = f"heat_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mow.png'):
                new_name = f"mow_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-mow_shiny.png'):
                new_name = f"mow_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-wash.png'):
                new_name = f"wash_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-wash_shiny.png'):
                new_name = f"wash_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-altered.png'):
                new_name = f"{pokemon_name.lower()}_altered_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-altered_shiny.png'):
                new_name = f"{pokemon_name.lower()}_altered_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-land.png'):
                new_name = f"{pokemon_name.lower()}_land_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-land_shiny.png'):
                new_name = f"{pokemon_name.lower()}_land_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sky.png'):
                new_name = f"{pokemon_name.lower()}_sky_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sky_shiny.png'):
                new_name = f"{pokemon_name.lower()}_sky_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-red-striped.png'):
                new_name = f"{pokemon_name.lower()}_red_striped_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-red-striped_shiny.png'):
                new_name = f"{pokemon_name.lower()}_red_striped_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-blue-striped.png'):
                new_name = f"{pokemon_name.lower()}_blue_striped_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-blue-striped_shiny.png'):
                new_name = f"{pokemon_name.lower()}_blue_striped_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-white-striped.png'):
                new_name = f"{pokemon_name.lower()}_white_striped_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-white-striped_shiny.png'):
                new_name = f"{pokemon_name.lower()}_white_striped_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-galarian-standard.png'):
                new_name = f"{pokemon_name.lower()}_galarian_standard_mode.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-galarian-standard_shiny.png'):
                new_name = f"{pokemon_name.lower()}_galarian_standard_mode_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-galarian-zen.png'):
                new_name = f"{pokemon_name.lower()}_galarian_zen_mode.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-galarian-zen_shiny.png'):
                new_name = f"{pokemon_name.lower()}_galarian_zen_mode_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-standard.png'):
                new_name = f"{pokemon_name.lower()}_standard_mode.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-standard_shiny.png'):
                new_name = f"{pokemon_name.lower()}_standard_mode_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-zen.png'):
                new_name = f"{pokemon_name.lower()}_zen_mode.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-zen_shiny.png'):
                new_name = f"{pokemon_name.lower()}_zen_mode_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-spring.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-spring_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-summer.png'):
                new_name = f"{pokemon_name.lower()}_alt_summer.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-summer_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_summer_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-autumn.png'):
                new_name = f"{pokemon_name.lower()}_alt_autumn.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-autumn_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_autumn_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-winter.png'):
                new_name = f"{pokemon_name.lower()}_alt_winter.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-winter_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_winter_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-black.png'):
                new_name = f"black_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-black_shiny.png'):
                new_name = f"black_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-white.png'):
                new_name = f"white_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-white_shiny.png'):
                new_name = f"white_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ordinary.png'):
                new_name = f"{pokemon_name.lower()}_ordinary_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ordinary_shiny.png'):
                new_name = f"{pokemon_name.lower()}_ordinary_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-resolute.png'):
                new_name = f"{pokemon_name.lower()}_resolute_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-resolute_shiny.png'):
                new_name = f"{pokemon_name.lower()}_resolute_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-midday.png'):
                new_name = f"{pokemon_name.lower()}_midday_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-midday_shiny.png'):
                new_name = f"{pokemon_name.lower()}_midday_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-midnight.png'):
                new_name = f"{pokemon_name.lower()}_midnight_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-midnight_shiny.png'):
                new_name = f"{pokemon_name.lower()}_midnight_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-dusk.png'):
                new_name = f"{pokemon_name.lower()}_dusk_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-dusk_shiny.png'):
                new_name = f"{pokemon_name.lower()}_dusk_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-pirouette.png'):
                new_name = f"{pokemon_name.lower()}_pirouette_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-pirouette_shiny.png'):
                new_name = f"{pokemon_name.lower()}_pirouette_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-aria.png'):
                new_name = f"{pokemon_name.lower()}_aria_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-aria_shiny.png'):
                new_name = f"{pokemon_name.lower()}_aria_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-burn.png'):
                new_name = f"{pokemon_name.lower()}_alt_burn_drive.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-burn_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_burn_drive_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-chill.png'):
                new_name = f"{pokemon_name.lower()}_alt_chill_drive.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-chill_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_chill_drive_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-douse.png'):
                new_name = f"{pokemon_name.lower()}_alt_douse_drive.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-douse_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_douse_drive_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-shock.png'):
                new_name = f"{pokemon_name.lower()}_alt_shock_drive.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-shock_shiny.png'):
                new_name = f"{pokemon_name.lower()}_alt_shock_drive_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ash.png'):
                new_name = f"{pokemon_name.lower()}_ash_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ash_shiny.png'):
                new_name = f"{pokemon_name.lower()}_ash_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-meadow.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-meadow_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-red.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-red_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-natural.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-natural_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-male.png'):
                new_name = f"{pokemon_name.lower()}_male.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-male_shiny.png'):
                new_name = f"{pokemon_name.lower()}_male_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-female.png'):
                new_name = f"{pokemon_name.lower()}_female.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-female_shiny.png'):
                new_name = f"{pokemon_name.lower()}_female_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-shield.png'):
                new_name = f"{pokemon_name.lower()}_shield_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-shield_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shield_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-blade.png'):
                new_name = f"{pokemon_name.lower()}_blade_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-blade_shiny.png'):
                new_name = f"{pokemon_name.lower()}_blade_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-average.png'):
                new_name = f"{pokemon_name.lower()}_average_size.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-average_shiny.png'):
                new_name = f"{pokemon_name.lower()}_average_size_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-large.png'):
                new_name = f"{pokemon_name.lower()}_large_size.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-large_shiny.png'):
                new_name = f"{pokemon_name.lower()}_large_size_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-small.png'):
                new_name = f"{pokemon_name.lower()}_small_size.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-small_shiny.png'):
                new_name = f"{pokemon_name.lower()}_small_size_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-super.png'):
                new_name = f"{pokemon_name.lower()}_super_size.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-super_shiny.png'):
                new_name = f"{pokemon_name.lower()}_super_size_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-50.png'):
                new_name = f"{pokemon_name.lower()}_50_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-50_shiny.png'):
                new_name = f"{pokemon_name.lower()}_50_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-10.png'):
                new_name = f"{pokemon_name.lower()}_10_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-10_shiny.png'):
                new_name = f"{pokemon_name.lower()}_10_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-complete.png'):
                new_name = f"{pokemon_name.lower()}_complete_forme.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-complete_shiny.png'):
                new_name = f"{pokemon_name.lower()}_complete_forme_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-confined.png'):
                new_name = f"{pokemon_name.lower()}_confined.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-confined_shiny.png'):
                new_name = f"{pokemon_name.lower()}_confined_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-unbound.png'):
                new_name = f"{pokemon_name.lower()}_unbound.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-unbound_shiny.png'):
                new_name = f"{pokemon_name.lower()}_unbound_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-stellar.png'):
                new_name = f"{pokemon_name.lower()}_stellar_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-stellar_shiny.png'):
                new_name = f"{pokemon_name.lower()}_stellar_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-terastal.png'):
                new_name = f"{pokemon_name.lower()}_terastal_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-terastal_shiny.png'):
                new_name = f"{pokemon_name.lower()}_terastal_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower().replace(" ", "-")}.png'):
                new_name = f"{pokemon_name.lower().replace(' ', '_')}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower().replace(" ", "-")}_shiny.png'):
                new_name = f"{pokemon_name.lower().replace(' ', '_')}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-teal.png'):
                new_name = f"{pokemon_name.lower()}_teal_mask.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-teal_shiny.png'):
                new_name = f"{pokemon_name.lower()}_teal_mask_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-cornerstone.png'):
                new_name = f"{pokemon_name.lower()}_cornerstone_mask.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-cornerstone_shiny.png'):
                new_name = f"{pokemon_name.lower()}_cornerstone_mask_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hearthflame.png'):
                new_name = f"{pokemon_name.lower()}_hearthflame_mask.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hearthflame_shiny.png'):
                new_name = f"{pokemon_name.lower()}_hearthflame_mask_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-wellspring.png'):
                new_name = f"{pokemon_name.lower()}_wellspring_mask.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-wellspring_shiny.png'):
                new_name = f"{pokemon_name.lower()}_wellspring_mask_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-chest.png'):
                new_name = f"{pokemon_name.lower()}_chest_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-chest_shiny.png'):
                new_name = f"{pokemon_name.lower()}_chest_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-roaming.png'):
                new_name = f"{pokemon_name.lower()}_roaming_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-roaming_shiny.png'):
                new_name = f"{pokemon_name.lower()}_roaming_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-two-segment.png'):
                new_name = f"{pokemon_name.lower()}_two_segment_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-two-segment_shiny.png'):
                new_name = f"{pokemon_name.lower()}_two_segment_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-three-segment.png'):
                new_name = f"{pokemon_name.lower()}_three_segment_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-three-segment_shiny.png'):
                new_name = f"{pokemon_name.lower()}_three_segment_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-curly.png'):
                new_name = f"{pokemon_name.lower()}_curly_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-curly_shiny.png'):
                new_name = f"{pokemon_name.lower()}_curly_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-droopy.png'):
                new_name = f"{pokemon_name.lower()}_droopy_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-droopy_shiny.png'):
                new_name = f"{pokemon_name.lower()}_droopy_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-stretchy.png'):
                new_name = f"{pokemon_name.lower()}_stretchy_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-stretchy_shiny.png'):
                new_name = f"{pokemon_name.lower()}_stretchy_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hero.png'):
                new_name = f"{pokemon_name.lower()}_hero_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hero_shiny.png'):
                new_name = f"{pokemon_name.lower()}_hero_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-zero.png'):
                new_name = f"{pokemon_name.lower()}_zero_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-zero_shiny.png'):
                new_name = f"{pokemon_name.lower()}_zero_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-active.png'):
                new_name = f"{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-active_shiny.png'):
                new_name = f"{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-baile.png'):
                new_name = f"{pokemon_name.lower()}_baile_style.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-baile_shiny.png'):
                new_name = f"{pokemon_name.lower()}_baile_style_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-pom-pom.png'):
                new_name = f"{pokemon_name.lower()}_pom_pom_style.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-pom-pom_shiny.png'):
                new_name = f"{pokemon_name.lower()}_pom_pom_style_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-pau.png'):
                new_name = f"{pokemon_name.lower()}_pau_style.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-pau_shiny.png'):
                new_name = f"{pokemon_name.lower()}_pau_style_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sensu.png'):
                new_name = f"{pokemon_name.lower()}_sensu_style.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-sensu_shiny.png'):
                new_name = f"{pokemon_name.lower()}_sensu_style_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-solo.png'):
                new_name = f"{pokemon_name.lower()}_solo_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-solo_shiny.png'):
                new_name = f"{pokemon_name.lower()}_solo_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-meteor.png'):
                new_name = f"{pokemon_name.lower()}_meteor_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-meteor_shiny.png'):
                new_name = f"{pokemon_name.lower()}_meteor_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-indigo-core.png'):
                new_name = f"{pokemon_name.lower()}_core_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-indigo-core_shiny.png'):
                new_name = f"{pokemon_name.lower()}_core_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-dawn-wings.png'):
                new_name = f"dawn_wings_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-dawn-wings_shiny.png'):
                new_name = f"dawn_wings_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-dusk-mane.png'):
                new_name = f"dusk_mane_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-dusk-mane_shiny.png'):
                new_name = f"dusk_mane_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ultra.png'):
                new_name = f"ultra_{pokemon_name.lower()}.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ultra_shiny.png'):
                new_name = f"ultra_{pokemon_name.lower()}_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ice.png'):
                new_name = f"{pokemon_name.lower()}_ice_face.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-ice_shiny.png'):
                new_name = f"{pokemon_name.lower()}_ice_face_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-noice.png'):
                new_name = f"{pokemon_name.lower()}_noice_face.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-noice_shiny.png'):
                new_name = f"{pokemon_name.lower()}_noice_face_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-full-belly.png'):
                new_name = f"{pokemon_name.lower()}_full_belly_mode.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-full-belly_shiny.png'):
                new_name = f"{pokemon_name.lower()}_full_belly_mode_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hangry.png'):
                new_name = f"{pokemon_name.lower()}_hangry_mode.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-hangry_shiny.png'):
                new_name = f"{pokemon_name.lower()}_hangry_mode_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-amped.png'):
                new_name = f"{pokemon_name.lower()}_amped_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-amped_shiny.png'):
                new_name = f"{pokemon_name.lower()}_amped_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-low-key.png'):
                new_name = f"{pokemon_name.lower()}_low_key_form.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-low-key_shiny.png'):
                new_name = f"{pokemon_name.lower()}_low_key_form_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-crowned.png'):
                if pokemon_name.lower() == "zamazenta":
                    new_name = f"{pokemon_name.lower()}_crowned_shield.png"
                else:
                    new_name = f"{pokemon_name.lower()}_crowned_sword.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-crowned_shiny.png'):
                if pokemon_name.lower() == "zamazenta":
                    new_name = f"{pokemon_name.lower()}_crowned_shield_shiny.png"
                else:
                    new_name = f"{pokemon_name.lower()}_crowned_sword_shiny.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-eternamax.png'):
                new_name = f"{pokemon_name.lower()}_eternamax.png"
            elif img_file.name.endswith(f'{pokemon_name.lower()}-eternamax_shiny.png'):
                new_name = f"{pokemon_name.lower()}_eternamax_shiny.png"
            elif img_file.name == f"{pokemon_name.lower()}-ice-rider.png":
                new_name = f"{pokemon_name.lower()}_ice_rider.png"
            elif img_file.name == f"{pokemon_name.lower()}-ice-rider_shiny.png":
                new_name = f"{pokemon_name.lower()}_ice_rider_shiny.png"
            elif img_file.name == f"{pokemon_name.lower()}-shadow-rider.png":
                new_name = f"{pokemon_name.lower()}_shadow_rider.png"
            elif img_file.name == f"{pokemon_name.lower()}-shadow-rider_shiny.png":
                new_name = f"{pokemon_name.lower()}_shadow_rider_shiny.png"
            elif img_file.name == f"{pokemon_name.lower()}-bloodmoon.png":
                new_name = f"{pokemon_name.lower()}_bloodmoon.png"
            elif img_file.name == f"{pokemon_name.lower()}-bloodmoon_shiny.png":
                new_name = f"{pokemon_name.lower()}_bloodmoon_shiny.png"
            else:
                print(f"Unrecognized image file {img_file}; skipping.")
                continue

            new_path = Path(__file__).parent.parent / "assets" / "images_large" / "pokemon" / new_name
            new_path.parent.mkdir(parents=True, exist_ok=True)
            img_file.rename(new_path)
            print(f"Renamed {img_file} to {new_path}")

        if not any(number_dir.iterdir()):
            number_dir.rmdir()

def crop_prefixes(range_start: int, range_end: int):
    images_dir = Path(__file__).parent.parent / "data" / "images_large"
    for number_dir in images_dir.iterdir():
        if not number_dir.is_dir():
            continue
        elif not (range_start <= int(number_dir.name) <= range_end):
            continue

        pokemon_list = pokemon_data.get(number_dir.name)
        if not pokemon_list:
            print(f"No data for {number_dir.name}; skipping")
            continue

        pokemon = pokemon_list[0]
        pokemon_name = pokemon.get("base_name")
        if not pokemon_name:
            print(f"No base_name for {number_dir.name}; skipping")
            continue

        img_files = list(number_dir.iterdir())
        if len(img_files) == 0:
            print(f"No images found in {number_dir}; deleting directory.")
            number_dir.rmdir()
            continue

        for img_file in number_dir.iterdir():
            if not img_file.is_file():
                continue

            cropped_name = img_file.name.split('_from_home_')[1]
            img_file.rename(number_dir / cropped_name)
            print(f"Cropped {img_file.name} to {cropped_name}")

if __name__ == "__main__":
    rename_sprites(493, 1025)
    # crop_prefixes(201, 1025)