#!/usr/bin/env python3
"""
Collect enhanced move data from Serebii.net.

This script fetches additional move attributes from Serebii's attackdex including:
- In-depth effect (with nested tables as structured data)
- Secondary effect
- Effect rate
- Base critical hit rate
- Boolean attributes (contact, sound, protect, etc.)
"""

import json
import pathlib
import re
import time
import unicodedata
from typing import Any, Dict, List, Optional, Tuple

import requests
from bs4 import BeautifulSoup, Tag


# Paths
ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
ASSETS_DIR = ROOT / "assets" / "data"

# HTTP Configuration
HEADERS = {
    "User-Agent": "ChampionDex/1.0 Python requests",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

BASE_URL = "https://www.serebii.net/attackdex-sv"


def make_serebii_move_url(move_name: str) -> str:
    """
    Convert move name to Serebii URL format.
    
    Rules:
    - Lowercase
    - Remove spaces
    - Remove special characters EXCEPT dashes (keep dashes)
    - Normalize Unicode
    
    Examples:
    - "Thunder Bolt" -> "thunderbolt"
    - "U-turn" -> "u-turn"
    - "10,000,000 Volt Thunderbolt" -> "10000000voltthunderbolt"
    """
    slug = move_name.lower()
    
    # Normalize Unicode (decompose accented characters)
    slug = unicodedata.normalize('NFD', slug)
    slug = ''.join(char for char in slug if unicodedata.category(char) != 'Mn')
    
    # Remove spaces
    slug = slug.replace(" ", "")
    
    # Remove all special characters EXCEPT dashes and alphanumeric
    slug = re.sub(r'[^a-z0-9\-]', '', slug)
    
    return f"{BASE_URL}/{slug}.shtml"


def fetch_html(url: str) -> BeautifulSoup:
    """Fetch and parse HTML from the given URL."""
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "lxml")


def clean_text(text: str) -> str:
    """Clean and normalize text."""
    if not text:
        return ""
    # Replace multiple spaces with single space
    text = re.sub(r'\s+', ' ', text.strip())
    return text


def parse_table_to_structured_data(table: Tag) -> Dict[str, Any]:
    """
    Parse a nested table into structured data.
    
    Common table types in in-depth effects:
    - Power calculation tables (e.g., Heavy Slam)
    - Probability distributions (e.g., multi-hit moves)
    - Condition-based effects
    """
    rows = table.find_all('tr')
    if not rows:
        return {"raw_text": clean_text(table.get_text())}
    
    # Try to parse as a data table
    headers = []
    data_rows = []
    
    for i, row in enumerate(rows):
        cells = row.find_all(['th', 'td'])
        if not cells:
            continue
            
        cell_values = [clean_text(cell.get_text()) for cell in cells]
        
        # If all cells are th, treat as header
        if all(cell.name == 'th' for cell in cells):
            headers = cell_values
        # If first row and no headers yet, treat as header
        elif i == 0 and not headers:
            headers = cell_values
        else:
            data_rows.append(cell_values)
    
    # If we have headers and data, structure it
    if headers and data_rows:
        structured_rows = []
        for data_row in data_rows:
            row_dict = {}
            for i, value in enumerate(data_row):
                header = headers[i] if i < len(headers) else f"column_{i}"
                row_dict[header] = value
            structured_rows.append(row_dict)
        return {
            "type": "table",
            "headers": headers,
            "rows": structured_rows
        }
    
    # Otherwise, just capture as rows
    return {
        "type": "simple_table",
        "rows": [[clean_text(cell.get_text()) for cell in row.find_all(['th', 'td'])] for row in rows]
    }


def parse_in_depth_effect(cell: Tag) -> Dict[str, Any]:
    """
    Parse the in-depth effect cell, extracting nested tables as structured data.
    
    Returns:
    {
        "text": "Main description text",
        "nested_tables": [<structured table data>, ...]
    }
    """
    if not cell:
        return {"text": None, "nested_tables": []}
    
    # Find all nested dextables
    nested_tables = cell.find_all('table', class_='dextable')
    
    # Extract and structure nested tables
    structured_tables = []
    for table in nested_tables:
        structured_tables.append(parse_table_to_structured_data(table))
        # Remove the table from the cell temporarily for text extraction
        table.extract()
    
    # Get the remaining text
    text = clean_text(cell.get_text())
    
    return {
        "text": text if text else None,
        "nested_tables": structured_tables if structured_tables else []
    }


def parse_move_page(soup: BeautifulSoup, move_name: str, warnings: List[Dict]) -> Optional[Dict[str, Any]]:
    """
    Parse a Serebii move page for enhanced attributes.
    
    Returns None if the move is unusable (Battle Effect contains "This move can't be used").
    """
    # Find only top-level dextables (not nested inside other dextables)
    all_dextables = soup.find_all('table', class_='dextable')
    dextables = []
    for table in all_dextables:
        parent_dextable = table.find_parent('table', class_='dextable')
        if parent_dextable is None:
            dextables.append(table)
    
    if len(dextables) < 1:
        warnings.append({
            "move": move_name,
            "warning": "No dextables found on page"
        })
        return None
    
    # Initialize result
    result = {
        "in_depth_effect": None,
        "secondary_effect": None,
        "effect_rate": None,
        "base_critical_hit_rate": None,
        "boolean_attributes": {}
    }
    
    # Parse first dextable (battle mechanics)
    # Structure: rows alternate or have labels with values in next row or cells
    first_table = dextables[0]
    rows = first_table.find_all('tr')
    
    i = 0
    while i < len(rows):
        row = rows[i]
        cells = row.find_all('td')
        
        if not cells:
            i += 1
            continue
        
        # Get the first cell text as potential label
        first_cell_text = clean_text(cells[0].get_text()).lower()
        
        # Battle Effect - check if unusable
        if first_cell_text == 'battle effect:':
            # Value is in the next row
            if i + 1 < len(rows):
                next_row = rows[i + 1]
                next_cells = next_row.find_all('td')
                if next_cells:
                    value_text = clean_text(next_cells[0].get_text()).lower()
                    # Check for truly unusable moves: "This move can't be used. It's recommended that this move is forgotten"
                    if "this move can't be used" in value_text and "recommended that this move is forgotten" in value_text:
                        return None  # Mark as unusable
            i += 1
            continue
        
        # In-depth effect (look for next row after label)
        if 'in depth effect' in first_cell_text or 'in-depth effect' in first_cell_text:
            if i + 1 < len(rows):
                next_row = rows[i + 1]
                next_cells = next_row.find_all('td')
                if next_cells:
                    result["in_depth_effect"] = parse_in_depth_effect(next_cells[0])
            i += 1
            continue
        
        # Secondary Effect: and Effect Rate: are on the same row
        if 'secondary effect:' in first_cell_text:
            # This row has labels, next row has values
            if i + 1 < len(rows):
                next_row = rows[i + 1]
                next_cells = next_row.find_all('td')
                if len(next_cells) >= 1:
                    sec_effect_text = clean_text(next_cells[0].get_text())
                    result["secondary_effect"] = sec_effect_text if sec_effect_text and sec_effect_text != '—' else None
                if len(next_cells) >= 2:
                    effect_rate_text = clean_text(next_cells[1].get_text())
                    if effect_rate_text and effect_rate_text not in ('—', '-', ''):
                        match = re.search(r'(\d+)\s*%', effect_rate_text)
                        if match:
                            result["effect_rate"] = int(match.group(1))
                        else:
                            result["effect_rate"] = effect_rate_text
            i += 1
            continue
        
        # Base Critical Hit Rate (row with labels)
        if 'base critical hit rate' in first_cell_text:
            # Values are in the next row
            if i + 1 < len(rows):
                next_row = rows[i + 1]
                next_cells = next_row.find_all('td')
                if next_cells:
                    crit_text = clean_text(next_cells[0].get_text())
                    result["base_critical_hit_rate"] = crit_text if crit_text and crit_text != '—' else None
            i += 1
            continue
        
        i += 1
    
    # Parse second dextable (boolean attributes) if it exists
    if len(dextables) >= 2:
        second_table = dextables[1]
        rows = second_table.find_all('tr')
        
        # Parse in pairs: label row, value row, label row, value row...
        # Structure: Row 0 has headers, Row 1 has values, Row 2 has more headers, Row 3 has more values...
        label_rows = []
        value_rows = []
        
        for i, row in enumerate(rows):
            cells = row.find_all('td')
            if not cells:
                continue
            
            # Odd rows (0, 2, 4...) tend to be labels, even rows (1, 3, 5...) tend to be values
            if i % 2 == 0:
                label_rows.append(cells)
            else:
                value_rows.append(cells)
        
        # Match label rows with value rows
        for label_cells, value_cells in zip(label_rows, value_rows):
            for label_cell, value_cell in zip(label_cells, value_cells):
                label = clean_text(label_cell.get_text()).lower()
                value_text = clean_text(value_cell.get_text()).lower()
                
                if not label or label == '—':
                    continue
                
                # Normalize label to key
                key = re.sub(r'[^a-z0-9_]', '_', label.replace(' ', '_').replace("'", '').replace('-', '_'))
                key = re.sub(r'_+', '_', key).strip('_')
                
                # Parse yes/no to boolean
                if 'yes' in value_text:
                    result["boolean_attributes"][key] = True
                elif 'no' in value_text:
                    result["boolean_attributes"][key] = False
                else:
                    result["boolean_attributes"][key] = None
                    if value_text and value_text != '—':
                        warnings.append({
                            "move": move_name,
                            "warning": f"Unexpected value for boolean '{label}': '{value_text}'"
                        })
    else:
        warnings.append({
            "move": move_name,
            "warning": "No second dextable found (boolean attributes missing)"
        })
    
    return result


def main():
    """Main execution function."""
    print("=== Serebii Move Data Collector ===\n")
    
    # Load existing moves
    moves_path = ASSETS_DIR / "moves.json"
    print(f"Loading moves from: {moves_path}")
    
    with open(moves_path, 'r', encoding='utf-8') as f:
        moves = json.load(f)
    
    print(f"Found {len(moves)} moves to process\n")
    
    # Initialize tracking
    enhanced_data = {}
    unusable_moves = []
    failures = []
    warnings = []
    
    # Process each move
    for i, move_name in enumerate(moves.keys(), 1):
        print(f"[{i}/{len(moves)}] {move_name}...", end=" ", flush=True)
        
        try:
            url = make_serebii_move_url(move_name)
            soup = fetch_html(url)
            
            result = parse_move_page(soup, move_name, warnings)
            
            if result is None:
                # Move is unusable
                unusable_moves.append({
                    "name": move_name,
                    "url": url
                })
                print("✗ Unusable")
            else:
                enhanced_data[move_name] = result
                print("✓")
            
            # Rate limiting
            time.sleep(0.3)
            
            # Save checkpoint every 50 moves
            if i % 50 == 0:
                DATA_DIR.mkdir(parents=True, exist_ok=True)
                checkpoint_path = DATA_DIR / f"moves_enhanced_checkpoint_{i}.json"
                with open(checkpoint_path, 'w', encoding='utf-8') as f:
                    json.dump({
                        'enhanced_data': enhanced_data,
                        'unusable_moves': unusable_moves,
                        'failures': failures,
                        'processed': i
                    }, f, indent=2, ensure_ascii=False)
                print(f"  [Checkpoint saved: {i} moves processed]")
            
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                failures.append({
                    'name': move_name,
                    'reason': '404 Not Found',
                    'url': url
                })
                print("✗ 404")
            else:
                failures.append({
                    'name': move_name,
                    'error': str(e),
                    'url': url
                })
                print(f"✗ HTTP Error: {e.response.status_code}")
        
        except Exception as e:
            failures.append({
                'name': move_name,
                'error': str(e),
                'url': make_serebii_move_url(move_name)
            })
            print(f"✗ Error: {e}")
    
    # Save results
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    # Enhanced data
    enhanced_path = DATA_DIR / "moves_enhanced.json"
    print(f"\nSaving enhanced data to: {enhanced_path}")
    with open(enhanced_path, 'w', encoding='utf-8') as f:
        json.dump(enhanced_data, f, indent=2, ensure_ascii=False)
    
    # Unusable moves
    unusable_path = DATA_DIR / "moves_unusable.json"
    print(f"Saving unusable moves to: {unusable_path}")
    with open(unusable_path, 'w', encoding='utf-8') as f:
        json.dump(unusable_moves, f, indent=2, ensure_ascii=False)
    
    # Failures
    failures_path = DATA_DIR / "moves_enhanced_failures.json"
    print(f"Saving failures to: {failures_path}")
    with open(failures_path, 'w', encoding='utf-8') as f:
        json.dump({
            'failures': failures,
            'warnings': warnings,
            'summary': {
                'total_processed': len(moves),
                'successful': len(enhanced_data),
                'unusable': len(unusable_moves),
                'failed': len(failures),
                'warnings': len(warnings)
            }
        }, f, indent=2, ensure_ascii=False)
    
    # Summary
    print("\n=== Summary ===")
    print(f"✓ Successfully processed: {len(enhanced_data)}")
    print(f"✗ Unusable moves: {len(unusable_moves)}")
    print(f"✗ Failed: {len(failures)}")
    print(f"⚠ Warnings: {len(warnings)}")
    
    if unusable_moves[:5]:
        print(f"\nUnusable moves (first 5): {', '.join([m['name'] for m in unusable_moves[:5]])}")
    
    if failures[:5]:
        print(f"\nFailed moves (first 5): {', '.join([f['name'] for f in failures[:5]])}")
    
    if warnings[:10]:
        print(f"\nWarnings (first 10):")
        for w in warnings[:10]:
            print(f"  - {w['move']}: {w['warning']}")


if __name__ == "__main__":
    main()
