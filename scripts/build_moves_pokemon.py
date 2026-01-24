#!/usr/bin/env python3
import os
import json
import re
from collections import defaultdict

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
src_dir = os.path.join(repo_root, 'assets', 'data', 'pokemon_moves')
dest_dir = os.path.join(repo_root, 'assets', 'data', 'moves_pokemon')

if not os.path.isdir(src_dir):
    raise SystemExit(f"Source directory not found: {src_dir}")
if not os.path.isdir(dest_dir):
    os.makedirs(dest_dir, exist_ok=True)

# sanitize filename: replace problematic chars with underscore and trim
def sanitize_filename(name):
    s = name.strip()
    s = re.sub(r"[\\/:*?\"<>|]", '_', s)
    return s + '.json'

moves = defaultdict(lambda: defaultdict(lambda: defaultdict(set)))

files = [f for f in os.listdir(src_dir) if f.endswith('.json')]
for fn in files:
    path = os.path.join(src_dir, fn)
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            data = json.load(fh)
    except Exception as e:
        print(f"Skipping {fn}: failed to load JSON: {e}")
        continue

    for form_name, form_data in data.items():
        # form_data contains gen_* keys
        if not isinstance(form_data, dict):
            continue
        for gen_key, gen_val in form_data.items():
            if not isinstance(gen_val, dict):
                continue
            for game_name, game_data in gen_val.items():
                if not isinstance(game_data, dict):
                    continue
                for method_name, entries in game_data.items():
                    if not isinstance(entries, list):
                        continue
                    for entry in entries:
                        move_name = None
                        if isinstance(entry, dict):
                            # common keys: 'name' or 'move' or 'move_name'
                            move_name = entry.get('name') or entry.get('move') or entry.get('move_name')
                        elif isinstance(entry, str):
                            move_name = entry
                        if not move_name:
                            continue
                        moves[move_name][game_name][method_name].add(form_name)

# write per-move files
for move_name, games in moves.items():
    out = {}
    for game_name, methods in games.items():
        out[game_name] = {}
        for method_name, forms in methods.items():
            out[game_name][method_name] = sorted(forms)
    filename = sanitize_filename(move_name)
    out_path = os.path.join(dest_dir, filename)
    try:
        with open(out_path, 'w', encoding='utf-8') as fh:
            json.dump(out, fh, ensure_ascii=False, indent=2, sort_keys=True)
    except Exception as e:
        print(f"Failed writing {out_path}: {e}")

print(f"Wrote {len(moves)} move files to {dest_dir}")
