#!/usr/bin/env python3
"""Download sprites from pokemondb.net for pokemon 1-1025.
Saves images to `data/images_large/<number>/` and writes mapping to
`data/pokemon_sprites_large_1_1025.json`.

Run: python scripts/download_sprites.py
"""
import re
import json
import time
import os
import sys
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
ASSETS_IMG = os.path.join(ROOT, 'data', 'images_large')
OUT_JSON = os.path.join(ROOT, 'data', 'pokemon_sprites_large_1_1025.json')

HEADERS = {
    'User-Agent': 'python-requests/2.0 (sprite-downloader)'
}

def slugify(name: str) -> str:
    s = name.lower()
    s = s.replace("'", '')
    s = re.sub(r"[^a-z0-9]+", '-', s)
    s = s.strip('-')
    return s

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def download_file(url, dest_path):
    try:
        resp = requests.get(url, headers=HEADERS, timeout=30)
        resp.raise_for_status()
    except Exception as e:
        print(f"Failed to download {url}: {e}")
        return False
    with open(dest_path, 'wb') as f:
        f.write(resp.content)
    return True

def abs_url(src, base):
    if src.startswith('//'):
        return 'https:' + src
    return urljoin(base, src)

def find_sprite_images(soup, base_url):
    imgs = []
    for img in soup.find_all('img'):
        src = img.get('src')
        if not src:
            continue
        full = abs_url(src, base_url)
        if '/home/' in full:
            imgs.append((full, img))
    # collapse duplicates
    seen = set()
    out = []
    for full, img in imgs:
        if full in seen:
            continue
        seen.add(full)
        out.append((full, img))
    return out

def form_name_from_img(img_tag):
    # Try to get form from alt, title, or parent elements
    alt = (img_tag.get('alt') or '').strip()
    title = (img_tag.get('title') or '').strip()
    txt = alt or title
    if not txt:
        # Check parent or siblings for form info
        parent = img_tag.find_parent()
        if parent:
            txt = parent.get_text().strip()
    if not txt:
        return 'base'
    txt = re.sub(r"\s+", ' ', txt)
    return txt

def process_pokemon(number, entries):
    base_name = entries[0].get('base_name') or entries[0].get('name')
    slug = slugify(base_name)
    page_url = f'https://pokemondb.net/sprites/{slug}'
    print(f"Fetching {number} {base_name} -> {page_url}")
    try:
        r = requests.get(page_url, headers=HEADERS, timeout=30)
        r.raise_for_status()
    except Exception as e:
        print(f"Failed to fetch page for {number} ({base_name}): {e}")
        return None
    soup = BeautifulSoup(r.text, 'html.parser')
    imgs = find_sprite_images(soup, page_url)
    dest_dir = os.path.join(ASSETS_IMG, str(number))
    ensure_dir(dest_dir)
    record = []
    for idx, (url, img_tag) in enumerate(imgs):
        lower = url.lower()
        is_shiny = 'shiny' in lower
        url = url.replace('/1x/', '/')
        parsed = urlparse(url)
        orig = os.path.basename(parsed.path)
        name_no_ext, ext = os.path.splitext(orig)
        form = form_name_from_img(img_tag)
        # sanitize form label
        form_label = re.sub(r"\s+", '_', form.lower())
        form_label = re.sub(r"[^a-z0-9_]+", '', form_label).strip('_')
        if not form_label:
            form_label = 'base'
        shiny_tag = '_shiny' if is_shiny else ''
        save_name = f"{idx:02d}_{form_label}_{name_no_ext}{shiny_tag}{ext}"
        save_path = os.path.join(dest_dir, save_name)
        ok = download_file(url, save_path)
        if not ok:
            continue
        record.append({
            'url': url,
            'local': os.path.relpath(save_path, ROOT).replace('\\', '/'),
            'form': form,
            'shiny': bool(is_shiny)
        })
        time.sleep(0.5)
    return record

def main():
    data_path = os.path.join(ROOT, 'assets', 'data', 'pokemon_by_number.json')
    if not os.path.exists(data_path):
        print('Missing assets/data/pokemon_by_number.json')
        sys.exit(1)
    with open(data_path, 'r', encoding='utf-8') as f:
        by_number = json.load(f)

    out_map = {}
    for n in range(5, 1026):
        key = str(n)
        if key not in by_number:
            print(f"No data for {n} in pokemon_by_number.json; skipping")
            continue
        entries = by_number[key]
        rec = process_pokemon(n, entries)
        if rec is None:
            print(f"No sprites found for {n}")
            out_map[key] = []
        else:
            out_map[key] = rec
        time.sleep(1.0)

    ensure_dir(os.path.dirname(OUT_JSON))
    with open(OUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(out_map, f, indent=2, ensure_ascii=False)
    print(f"Wrote mapping to {OUT_JSON}")


if __name__ == '__main__':
    main()
