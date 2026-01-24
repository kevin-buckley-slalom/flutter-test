#!/usr/bin/env python3
"""
Fetch detailed move effect descriptions from pokemondb.net and add them
to the moves JSON as a new field `detailed_effect`.

Usage:
  python scripts/update_moves_detailed_effects.py --input assets/data/moves.json

This script overwrites the input file by default and creates a backup
with the `.bak` suffix.
"""
import argparse
import json
import re
import time
from typing import Iterable

import requests
from bs4 import BeautifulSoup


def slugify(name: str) -> str:
    # Preserve existing dashes, keep letters/digits/spaces/dashes,
    # remove other punctuation, then replace spaces with '-'
    cleaned = re.sub(r"[^A-Za-z0-9 \-]+", "", name)
    # collapse multiple spaces into single dash
    slug = re.sub(r"\s+", "-", cleaned.strip().lower())
    return slug


def fetch_detailed_effect(slug: str, session: requests.Session) -> str | None:
    url = f"https://pokemondb.net/move/{slug}"
    try:
        resp = session.get(url, timeout=15)
    except requests.RequestException:
        return None
    if resp.status_code != 200:
        return None
    soup = BeautifulSoup(resp.text, "lxml")

    # Find the header by id if present, else by text 'Effects'
    header = soup.find(id="move-effects")
    if header is None:
        header = soup.find(lambda tag: tag.name in ("h1", "h2", "h3", "h4") and tag.get_text(strip=True).lower() == "effects")
    if header is None:
        return None

    paragraphs: list[str] = []

    def normalize_paragraph(p_tag) -> str:
        # Convert fraction spans like <span class="fraction"><sup>1</sup>⁄<sub>12</sub></span>
        # into '1/12'

        for frac in p_tag.find_all("span", class_=lambda c: c and "fraction" in c):
            sup = frac.find("sup")
            sub = frac.find("sub")
            if sup and sub:
                new_text = f"{sup.get_text(strip=True)}/{sub.get_text(strip=True)}"
                # ensure spacing around replacement to avoid word joins
                frac.replace_with(f" {new_text} ")
            else:
                frac.replace_with(f" {frac.get_text(strip=True).replace("⁄", "/")} ")

        # Replace <br> tags with a newline placeholder to preserve paragraph breaks

        for br in p_tag.find_all("br"):
            br.replace_with(" \n ")

        # Collect stripped strings and join with single spaces to preserve boundaries
        tokens = list(p_tag.stripped_strings)
        text = " ".join(tokens)

        # Collapse multiple whitespace (including newlines introduced by <br>)
        text = re.sub(r"\s+", " ", text)

        # Convert any remaining unicode fraction slash to '/'
        text = text.replace("⁄", "/")

        # Ensure there's space after punctuation when missing (e.g. "water,which" -> "water, which")
        text = re.sub(r"([,.;:!?])(?=[A-Za-z0-9])", r"\1 ", text)

        # Add spaces around plain fraction tokens that lack spacing (e.g. "restores1/16of")
        text = re.sub(r"(?<!\s)(\d+/\d+)(?!\s)", r" \1 ", text)

        # Insert space between a lowercase/number and a following CapitalizedWord (e.g. "ofIngrain")
        text = re.sub(r"([a-z0-9])([A-Z][a-z])", r"\1 \2", text)

        # Remove any short sentence that references the glossary
        text = re.sub(r"[^.]*glossary[^.]*\.?", "", text, flags=re.I)

        # Final whitespace collapse and strip
        text = re.sub(r"\s+", " ", text).strip()
        return text

    # Iterate through next siblings until we hit another header tag
    for sib in header.find_next_siblings():
        if getattr(sib, "name", None) and sib.name and sib.name.startswith("h"):
            break
        if getattr(sib, "name", None) == "p":
            normalized = normalize_paragraph(sib)
            if normalized:
                paragraphs.append(normalized)
        # some pages may wrap text in divs—collect p tags inside such sibling divs
        if getattr(sib, "name", None) == "div":
            for p in sib.find_all("p", recursive=False):
                normalized = normalize_paragraph(p)
                if normalized:
                    paragraphs.append(normalized)

    if not paragraphs:
        return None

    # Join paragraphs with a single newline between them to preserve paragraph breaks
    return "\n".join(paragraphs)


def iter_moves(data) -> Iterable[tuple[object, str]]:
    # yield (move_obj, move_name) for either dict mapping or list
    if isinstance(data, dict):
        for key, val in data.items():
            # if value is a dict containing a name field, prefer it
            if isinstance(val, dict) and "name" in val and val["name"]:
                yield val, val["name"]
            else:
                yield val, key
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                name = item.get("name") or item.get("move") or item.get("identifier")
                if name:
                    yield item, name
    else:
        return


def main():
    p = argparse.ArgumentParser(description="Update moves.json with detailed_effect from pokemondb.net")
    p.add_argument("--input", required=True, help="Path to moves.json to update")
    p.add_argument("--backup", action="store_true", help="Create a .bak backup of the input file")
    p.add_argument("--delay", type=float, default=1.0, help="Seconds to sleep between requests (default: 1.0)")
    p.add_argument("--timeout-on-fail", action="store_true", help="Stop on first fetch failure")
    args = p.parse_args()

    with open(args.input, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    if args.backup:
        with open(args.input + ".bak", "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)

    session = requests.Session()
    total = 0
    updated = 0

    for move_obj, move_name in iter_moves(data):
        total += 1
        slug = slugify(move_name)
        print(f"[{total}] Fetching: {move_name} -> {slug}")
        detailed = fetch_detailed_effect(slug, session)
        if detailed is None:
            print(f"  Warning: no detailed effect found for '{move_name}' (slug: {slug})")
            if args.timeout_on_fail:
                print("Stopping due to --timeout-on-fail")
                break
        else:
            move_obj["detailed_effect"] = detailed
            updated += 1
        time.sleep(args.delay)

    # Write back to file
    with open(args.input, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)

    print(f"Done. Processed {total} moves, updated {updated} with `detailed_effect`.\n")


if __name__ == "__main__":
    main()
