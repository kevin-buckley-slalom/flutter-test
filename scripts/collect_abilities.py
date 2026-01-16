"""
Collect Pokémon ability information from PokemonDB.

Sources:
- Ability list: https://pokemondb.net/ability
- Ability details: https://pokemondb.net/ability/<ability-slug>

Outputs:
- data/abilities.json : map ability name -> { effect: str, pokemon: { regular: [names], hidden: [names] } }
- data/abilities_by_name.json : map lowercase ability name -> same object

Run:
    python scripts/collect_abilities.py

Dependencies:
    pip install requests beautifulsoup4 lxml
"""
from __future__ import annotations

import json
import pathlib
import re
import time
from typing import Dict, List, Tuple

import requests
from bs4 import BeautifulSoup

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
BASE_URL = "https://pokemondb.net"
ABILITY_LIST_URL = f"{BASE_URL}/ability"

HEADERS = {
    "User-Agent": "ChampionDex/1.0 (+https://github.com/kevinbuckley) Python requests",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def fetch_html(url: str) -> BeautifulSoup:
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "lxml")


def find_ability_links(soup: BeautifulSoup) -> List[Tuple[str, str]]:
    """Return list of (name, url) for abilities on the index page.
    Uses robust matching for links under /ability/<slug>.
    """
    links: List[Tuple[str, str]] = []
    seen = set()
    for a in soup.select('a[href^="/ability/"]'):
        name = a.get_text(strip=True)
        href = a.get("href")
        if not name or not href:
            continue
        # Skip anchors to same page sections
        if href == "/ability" or href.startswith("/ability#"):
            continue
        # Normalize and dedupe
        url = BASE_URL + href
        key = (name.lower(), url)
        if key in seen:
            continue
        seen.add(key)
        links.append((name, url))
    # Remove obvious nav/duplicate items by ensuring URL ends with slug
    links = [
        (n, u) for (n, u) in links
        if re.match(r"^https?://[^/]+/ability/[a-z0-9-]+/?$", u)
    ]
    # Dedupe by name preferring first occurrence
    dedup: Dict[str, str] = {}
    for name, url in links:
        dedup.setdefault(name, url)
    out = sorted(dedup.items(), key=lambda x: x[0].lower())
    return out


def parse_effect_description(soup: BeautifulSoup) -> str:
    """Extract the ability effect description from the details page.
    Prefer the vitals table row where th == 'Effect'; fallback to text under
    the 'Effect' header; then meta description; then any first paragraph.
    """
    # Try vitals-table -> th=='Effect'
    for table in soup.select('table.vitals-table'):
        for row in table.select('tr'):
            th = row.find('th')
            td = row.find('td')
            if th and td and th.get_text(strip=True).lower() == 'effect':
                return td.get_text(' ', strip=True)

    # Try the 'Effect' section header then next paragraph/table
    for header in soup.select('h2, h3'):
        if header.get_text(' ', strip=True).lower() == 'effect':
            nxt = header.find_next_sibling()
            while nxt and nxt.name not in {'p', 'table', 'div', 'ul', 'ol'}:
                nxt = nxt.find_next_sibling()
            if nxt and nxt.name == 'p':
                return nxt.get_text(' ', strip=True)
            if nxt and nxt.name == 'table':
                return nxt.get_text(' ', strip=True)
            break

    # Meta description fallback
    meta = soup.find('meta', attrs={'name': 'description'})
    if meta and meta.get('content'):
        content = meta['content'].strip()
        content = re.sub(r"\s*\|\s*Pokémon Database.*$", "", content)
        if content:
            return content

    # Any paragraph fallback
    p = soup.find('p')
    if p:
        return p.get_text(' ', strip=True)

    return ""


def parse_pokemon_lists(soup: BeautifulSoup) -> Tuple[List[str], List[str]]:
    """Return (regular_list, hidden_list) of Pokémon names from details page.
    Finds sections for regular and hidden ability holders via headers, then
    parses following data tables for pokedex links.
    """
    def collect_names_after(header) -> List[str]:
        """Collect display names for Pokémon from the next ability holder table.
        Prefer exact form names when present (e.g., 'Mega Beedrill').
        """
        # Find the next data-table after the header
        cur = header
        while cur:
            cur = cur.find_next_sibling()
            if not cur:
                break
            tbl = cur if cur.name == 'table' else cur.find('table')
            if not (tbl and 'data-table' in (tbl.get('class') or [])):
                continue

            # Determine columns
            headers = [th.get_text(' ', strip=True).lower() for th in tbl.select('thead th')]
            # Column indices
            name_idx = None
            form_idx = None
            for i, h in enumerate(headers):
                if 'form' in h or 'forme' in h or 'mega' in h:
                    form_idx = i

            names: List[str] = []
            rows = tbl.select('tbody tr')
            # If we didn't find the Pokémon column by header, infer from first row
            if name_idx is None and rows:
                tds0 = rows[0].find_all('td')
                for i, td in enumerate(tds0):
                    if td.select_one('a[href^="/pokedex/"]'):
                        name_idx = i
                        break
                if name_idx is None:
                    name_idx = 0

            for tr in rows:
                tds = tr.find_all('td')
                if not tds:
                    continue
                # Base species cell
                name_cell = tds[name_idx] if name_idx is not None and name_idx < len(tds) else tds[0]
                # Prefer anchor text for species name to avoid picking dex numbers
                anchor = name_cell.select_one('a[href^="/pokedex/"]')
                base_text = (anchor.get_text(strip=True) if anchor else name_cell.get_text(' ', strip=True))
                # Prefer a specific form column if present
                chosen = None
                if form_idx is not None and form_idx < len(tds):
                    form_text = tds[form_idx].get_text(' ', strip=True)
                    # Skip empty or placeholder form values
                    if form_text and form_text.lower() not in {'standard', 'normal', 'regular', '-', '—', 'n/a', ''}:
                        ft_low = form_text.lower()
                        bt_low = base_text.lower()
                        if bt_low in ft_low:
                            # Form cell already includes the species name
                            chosen = form_text
                        elif any(k in ft_low for k in ['mega', 'primal', 'alolan', 'galarian', 'hisuian', 'paldean', 'totem', 'gigantamax']):
                            # Prefix-style forms
                            chosen = f"{form_text} {base_text}"
                        else:
                            # Default: append form as suffix (covers Male, Female, and other variants)
                            chosen = f"{base_text} {form_text}"
                if not chosen:
                    # Look for explicit variant labels within the name cell
                    # e.g., <small>Mega Beedrill</small>, <small>Male</small>, <small>Partner Pikachu</small>
                    small = name_cell.find(['small', 'span'])
                    small_text = small.get_text(' ', strip=True) if small else ''
                    st_low = small_text.lower() if small_text else ''
                    # Accept any non-empty small text that's not a generic placeholder
                    if small_text and st_low not in {'-', '—', 'n/a', ''}:
                        bt_low = base_text.lower()
                        if bt_low in st_low:
                            # Small text already includes species name (e.g., "Mega Beedrill")
                            chosen = small_text
                        elif any(k in st_low for k in ['mega', 'primal', 'gmax', 'gigantamax']):
                            # Prefix-style: "Mega Beedrill", "Primal Groudon"
                            chosen = f"{small_text} {base_text}"
                        elif any(k in st_low for k in ['alolan', 'galarian', 'hisuian', 'paldean', 'partner', 'ash']):
                            # Prefix-style regional/special variants
                            chosen = f"{small_text} {base_text}"
                        elif 'form' in st_low or 'forme' in st_low or st_low.endswith('-striped'):
                            # Suffix-style: "Basculin Red-Striped Form", "Deoxys Normal Forme"
                            chosen = f"{base_text} {small_text}"
                        else:
                            # Default suffix for all other variants (Rotom Heat, Deoxys Attack, etc.)
                            chosen = f"{base_text} {small_text}"
                if not chosen:
                    chosen = base_text

                if chosen:
                    names.append(chosen)

            # Deduplicate preserving order
            seen = set()
            out: List[str] = []
            for n in names:
                if n not in seen:
                    seen.add(n)
                    out.append(n)
            return out
        return []

    regular: List[str] = []
    hidden: List[str] = []

    for header in soup.select('h2, h3'):
        text = header.get_text(' ', strip=True).lower()
        if re.search(r"pok[eé]mon\s+with", text):
            regular = collect_names_after(header)
        elif re.search(r"hidden\s+ability", text):
            hidden = collect_names_after(header)

    return (regular, hidden)


def parse_ability_page(name: str, url: str) -> Dict:
    soup = fetch_html(url)
    effect = parse_effect_description(soup)
    regular, hidden = parse_pokemon_lists(soup)
    return {
        "name": name,
        "slug": url.rstrip('/').split('/')[-1],
        "url": url,
        "effect": effect,
        "pokemon": {
            "regular": regular,
            "hidden": hidden,
        }
    }


def write_outputs(abilities: Dict[str, Dict]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    # by name (display)
    abilities_json = abilities
    # by lowercase name
    abilities_by_name = {k.lower(): v for k, v in abilities.items()}

    (DATA_DIR / "abilities.json").write_text(json.dumps(abilities_json, indent=2), encoding="utf-8")
    (DATA_DIR / "abilities_by_name.json").write_text(json.dumps(abilities_by_name, indent=2), encoding="utf-8")


def main(limit: int | None = None, sleep_sec: float = 0.5, specific_ability: str | None = None) -> None:
    print("Fetching ability index...")
    index_soup = fetch_html(ABILITY_LIST_URL)
    links = find_ability_links(index_soup)
    print(f"Found {len(links)} abilities on index")

    if limit is not None:
        links = links[:limit]
        print(f"Limiting to first {limit} abilities for this run")

    if specific_ability is not None:
        links = [link for link in links if link[0].lower() == specific_ability.lower()]
        print(f"Filtering to specific ability: {specific_ability}")

    abilities: Dict[str, Dict] = {}
    for i, (name, url) in enumerate(links, start=1):
        print(f"[{i}/{len(links)}] Parsing {name} -> {url}")
        try:
            data = parse_ability_page(name, url)
            abilities[name] = data
        except Exception as e:
            print(f"  ! Failed to parse {name}: {e}")
        time.sleep(sleep_sec)

    print("Writing outputs...")
    write_outputs(abilities)
    print(f"Wrote {len(abilities)} abilities to data/abilities.json")


if __name__ == "__main__":
    # You can adjust limit for quick tests
    main(limit=None)
