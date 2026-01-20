#!/usr/bin/env python3
"""
Collect Pokémon moveset information from Serebii for Generation 9 (Scarlet/Violet).

Source:
- Pokemon pages: https://www.serebii.net/pokedex-sv/<pokemon-slug>/

Outputs:
- data/pokemon_moves_gen9.json : map pokemon name -> generation 9 movesets with URLs
"""

import json
import pathlib
import re
import time
from typing import Dict, List, Optional

import requests
from bs4 import BeautifulSoup
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
POKEMON_JSON = DATA_DIR / "pokemon.json"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
}


def fetch_html(url: str) -> BeautifulSoup:
    """Fetch and parse HTML from the given URL."""
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "html.parser")


def clean_text(text: str) -> str:
    """Clean and normalize text."""
    return text.strip().replace('\n', ' ').replace('\r', '').replace('  ', ' ')


def make_pokemon_url(base_name: str) -> str:
    """Convert Pokemon base name to Serebii URL slug.
    
    Serebii uses:
    - Lowercase
    - Spaces are removed (not replaced with dashes)
    - Special characters like periods and apostrophes are KEPT
    - Accented characters are normalized
    - Pokemon gender symbols (♀, ♂) are converted to letters
    """
    slug = base_name.lower()
    
    # Handle special Pokemon symbols
    slug = slug.replace('♀', 'f').replace('♂', 'm')
    
    # Normalize Unicode (decompose accented characters like é, è)
    slug = unicodedata.normalize('NFD', slug)
    slug = ''.join(char for char in slug if unicodedata.category(char) != 'Mn')
    
    # Only remove spaces, keep special characters like . and '
    slug = slug.replace(" ", "")
    
    return f"https://www.serebii.net/pokedex-sv/{slug}/"


def match_form_name(form_heading: str, variant_names: List[str]) -> Optional[str]:
    """
    Match a form heading from Serebii to a Pokemon name from our JSON.
    
    Args:
        form_heading: The heading text like "Paldean Form Level Up" or "Level Up - Blaze Breed" or "Level Up - Male"
        variant_names: List of variant names from pokemon.json for this Pokemon
    
    Returns:
        Matching Pokemon name or None if no match found
    """
    # Normalize the heading
    heading_lower = form_heading.lower()
    
    # Extract the form name from the heading
    form_text = heading_lower.replace('level up', '').replace('level-up', '')
    form_text = form_text.replace('-', ' ').replace('form', '').strip()
    
    # Handle special mappings for known regional variants
    if 'paldean' in heading_lower:
        # In Tauros's case, Paldean = Combat Breed
        # Check if "Combat" is in any variant
        for variant in variant_names:
            if 'combat' in variant.lower():
                return variant
    
    # Handle gender forms (male/female)
    # Check female FIRST because "female" contains "male" as a substring
    if 'female' in heading_lower:
        gender = 'female'
        for variant in variant_names:
            if gender in variant.lower():
                return variant
    elif 'male' in heading_lower:
        gender = 'male'
        for variant in variant_names:
            if gender in variant.lower():
                return variant
    
    if 'standard' in heading_lower or 'regular' in heading_lower:
        # Return the base form (without modifier in the name)
        for variant in variant_names:
            # Check if this is the base form (usually single word or no breed/form modifier)
            if variant.split()[-1].lower() not in ['breed', 'form', 'alolan', 'galarian', 'galar', 'hisuian', 'paldean', 'male', 'female']:
                return variant
        # Fallback: return first variant
        return variant_names[0] if variant_names else None
    
    # Try to extract breed name from heading (e.g., "Blaze" from "Level Up - Blaze Breed")
    breed_match = re.search(r'(\w+)\s+breed', form_text, re.IGNORECASE)
    if breed_match:
        breed_name = breed_match.group(1).lower()
        for variant in variant_names:
            if breed_name in variant.lower():
                return variant
    
    # Try exact matches on the form text
    for variant in variant_names:
        variant_lower = variant.lower()
        if form_text in variant_lower or variant_lower.endswith(form_text):
            return variant
    
    # Try partial matching on significant words
    for variant in variant_names:
        variant_lower = variant.lower()
        # Check if any significant word matches
        variant_words = set(word for word in variant_lower.split() if len(word) > 3)
        form_words = set(word for word in form_text.split() if len(word) > 3)
        
        if form_words and variant_words & form_words:
            return variant
    
    return None


def get_table_type(header_text: str) -> Optional[str]:
    """
    Determine the type of a move table by examining its header text.
    
    Args:
        header_text: The header text from the first row of the table
        
    Returns:
        "level_up", "tm", "egg_moves", "special_moves", "move_tutor", "tr", "tutor_attacks" or None if unknown
    """
    header_lower = header_text.lower()
    
    if 'level up' in header_lower or 'level-up' in header_lower:
        return "level_up"
    elif 'technical machine' in header_lower or ' tm ' in header_lower:
        return "tm"
    elif 'technical record' in header_lower or 'tr ' in header_lower or ' tr' in header_lower or 'tr\n' in header_lower:
        # SWSH Crown Tundra Technical Record
        return "tr"
    elif 'tutor' in header_lower and 'attack' in header_lower:
        # Isle of Armor and similar tutor attacks
        return "tutor_attacks"
    elif 'move tutor' in header_lower or 'tutor' in header_lower:
        return "move_tutor"
    elif 'egg' in header_lower and 'move' in header_lower:
        return "egg_moves"
    elif 'egg' in header_lower:
        return "egg_moves"
    elif 'special' in header_lower and 'move' in header_lower:
        return "special_moves"
    elif 'special' in header_lower:
        return "special_moves"
    # Additional fallback: if header contains "Attacks" or "Moves", treat as move data
    elif 'attack' in header_lower or ('move' in header_lower and 'custom' not in header_lower):
        # Likely a move table if it says "Attacks" or "Moves"
        return "special_moves"
    
    return None


def extract_game_designations(move_name: str) -> List[str]:
    """
    Extract game designations from a move name.
    
    Examples:
    - "ScreechBDSP Only" -> ["Brilliant Diamond and Shining Pearl"]
    - "Water PulseSWSH Only" -> ["Sword and Shield"]
    
    Returns:
        List of game names this move applies to
    """
    games = []
    move_lower = move_name.lower()
    
    # Check for specific game designations
    if 'swsh only' in move_lower or 'sword & shield only' in move_lower:
        games.append('Sword and Shield')
    if 'bdsp only' in move_lower or 'brilliant diamond shining pearl only' in move_lower:
        games.append('Brilliant Diamond and Shining Pearl')
    if 'legends' in move_lower and 'z-a' in move_lower:
        games.append('Legends: Z-A')
    if ('scarlet' in move_lower or 'violet' in move_lower) and 'only' in move_lower:
        games.append('Scarlet and Violet')
    
    return games


def remove_game_designations(move_name: str) -> str:
    """
    Remove game designations from a move name.
    
    Examples:
    - "ScreechBDSP Only" -> "Screech"
    - "Water PulseSWSH Only" -> "Water Pulse"
    
    Returns:
        Clean move name without game designation
    """
    # Remove common game designation patterns
    patterns = [
        r'\s*BDSP\s+Only\s*$',
        r'\s*SWSH\s+Only\s*$',
        r'\s*Sword\s+&\s+Shield\s+Only\s*$',
        r'\s*Brilliant\s+Diamond.*?Shining\s+Pearl\s+Only\s*$',
        r'\s*Isle\s+of\s+Armou?r\s+Only\s*$',
        r'\s*Crown\s+Tundra\s+Only\s*$',
        r'\s*Legends:\s+Z-A\s+Only\s*$',
        r'\s*Scarlet\s+&\s+Violet\s+Only\s*$',
    ]
    
    clean_name = move_name
    for pattern in patterns:
        clean_name = re.sub(pattern, '', clean_name, flags=re.IGNORECASE)
    
    return clean_name.strip()


def parse_level_up_moves(table: BeautifulSoup, is_legends: bool = False, is_pla: bool = False) -> List[Dict]:
    """
    Parse level-up moves from a dextable.
    
    For Legends: Z-A, moves can be upgraded to "plus moves" at a higher level.
    The cell contains: base_level <br/> <img alt="Plus Move"> plus_level
    
    For Pokémon Legends: Arceus, moves have a learned level and a mastery level.
    The cell contains: learned_level <br/> mastery_level
    
    For S&V/SWSH/BDSP, there's just: level
    
    Args:
        table: The dextable element
        is_legends: Whether this is a Legends: Z-A table (has plus_level in cell)
        is_pla: Whether this is a Pokémon Legends: Arceus table (has mastery level)
        
    Returns:
        List of dicts with 'name', 'level' (and 'level_plus'/'mastery_level' for special editions)
    """
    moves = []
    rows = table.find_all('tr')
    
    if len(rows) < 3:
        return moves
    
    # Parse move rows (skip header rows 0 and 1)
    i = 2
    while i < len(rows):
        row = rows[i]
        cells = row.find_all('td')
        
        if not cells or len(cells) < 2:
            i += 1
            continue
        
        # Skip filler rows (like description rows with 1 cell)
        if len(cells) == 1:
            i += 1
            continue
        
        # Cell 0: level info, Cell 1: move name, Cell 2: type
        level_cell = cells[0]
        move_name_cell = cells[1]
        move_type_cell = cells[2] if len(cells) > 2 else None
        
        move_name = clean_text(move_name_cell.get_text())
        move_type = clean_text(move_type_cell.get_text()) if move_type_cell else ''
        
        if move_name:
            move_dict = {
                'name': move_name,
                'type': move_type
            }
            
            if is_pla:
                # Extract learned level and mastery level from level_cell
                # Structure: learned_level <br/> mastery_level
                level_text = level_cell.get_text(separator='|').strip()
                parts = level_text.split('|')
                
                learned_level = parts[0].strip() if parts else ''
                mastery_level = parts[1].strip() if len(parts) > 1 else None
                
                move_dict['level'] = learned_level
                if mastery_level:
                    move_dict['mastery_level'] = mastery_level
                    
            elif is_legends:
                # Extract base level and plus level from level_cell
                # Structure: base_level <br/> <img> plus_level
                level_text = level_cell.get_text(separator='|').strip()  # Use separator to identify breaks
                
                # Get the <i> tag which contains plus level
                plus_tag = level_cell.find('i')
                level_plus = clean_text(plus_tag.get_text()) if plus_tag else None
                
                # Get base level (everything before first <br/>)
                # Split on | separator we added
                parts = level_text.split('|')
                level = parts[0].strip() if parts else ''
                
                move_dict['level'] = level
                if level_plus:
                    move_dict['level_plus'] = level_plus
            else:
                # S&V/SWSH/BDSP: simple level extraction
                level = clean_text(level_cell.get_text())
                move_dict['level'] = level
            
            moves.append(move_dict)
        
        # Skip the description row (which should be next)
        i += 2
    
    return moves


def parse_egg_or_special_moves(table: BeautifulSoup, game_context: Optional[str] = None) -> List[Dict]:
    """
    Parse egg moves or special moves from a dextable.
    
    Some moves have game designations like "MoveSWSH Only" or "MoveBDSP Only".
    This function splits them into separate games.
    
    Structure is same as level-up: paired rows with move data.
    For egg/special moves, there's no level number, just [move_name, type, ...]
    
    Args:
        table: The dextable element
        game_context: Optional game context ("SWSH", "BDSP", etc.) to apply if no designation
        
    Returns:
        Dict mapping game name to list of dicts with 'name', 'type'
    """
    moves_by_game = {}  # Dict[game_name, List[Dict]]
    rows = table.find_all('tr')
    
    if len(rows) < 3:
        return moves_by_game
    
    # Parse move rows (skip header rows 0 and 1)
    i = 2
    while i < len(rows):
        row = rows[i]
        cells = row.find_all('td')
        
        if not cells or len(cells) < 1:
            i += 1
            continue
        
        # Skip filler rows (description rows with 1 cell)
        if len(cells) == 1:
            i += 1
            continue
        
        # Extract: [move_name, type, ...] for egg/special
        move_name = clean_text(cells[0].get_text())
        move_type = clean_text(cells[1].get_text()) if len(cells) > 1 else ''
        
        if move_name:
            # Check for game designations in move name
            games_for_move = extract_game_designations(move_name)
            
            # Clean the move name by removing game designations
            clean_move_name = remove_game_designations(move_name)
            
            move_data = {
                'name': clean_move_name,
                'type': move_type
            }
            
            # If specific games were designated, use those; otherwise use context or both
            if games_for_move:
                for game in games_for_move:
                    if game not in moves_by_game:
                        moves_by_game[game] = []
                    moves_by_game[game].append(move_data)
            elif game_context:
                if game_context not in moves_by_game:
                    moves_by_game[game_context] = []
                moves_by_game[game_context].append(move_data)
            else:
                # No context - add to generic list, will be assigned to all games later
                if 'all' not in moves_by_game:
                    moves_by_game['all'] = []
                moves_by_game['all'].append(move_data)
        
        # Skip the description row
        i += 2
    
    return moves_by_game


def parse_tm_moves(table: BeautifulSoup, variant_names: List[str]) -> Dict[str, List[Dict]]:
    """
    Parse TM moves from a dextable, handling form indicators.
    
    Form indicators are images in cells 9-12 with alt text identifying the form.
    For example: <img alt="Female"> or <img alt="Male">
    
    Args:
        table: The dextable element
        variant_names: List of variant names to map form indicators to
        
    Returns:
        Dict mapping variant name to list of TM move dicts
    """
    variant_moves = {name: [] for name in variant_names}
    rows = table.find_all('tr')
    
    if len(rows) < 3:
        return variant_moves
    
    # Parse move rows (skip header rows 0 and 1)
    i = 2
    while i < len(rows):
        row = rows[i]
        cells = row.find_all('td')
        
        if not cells or len(cells) < 2:
            i += 1
            continue
        
        # Skip filler rows
        if len(cells) == 1:
            i += 1
            continue
        
        # Extract: [tm_id, move_name, type, ...]
        tm_id = clean_text(cells[0].get_text())
        move_name = clean_text(cells[1].get_text())
        move_type = clean_text(cells[2].get_text()) if len(cells) > 2 else ''
        
        if not move_name or not tm_id:
            i += 1
            continue
        
        # Check for form indicators in cells 9-12
        # Each cell may contain an image with alt text identifying the form
        forms_that_learn = []
        
        if len(cells) > 9:
            # Check which forms can learn this TM based on image alt text
            for col_idx in range(9, min(13, len(cells))):
                img = cells[col_idx].find('img')
                if img:
                    # Get the alt text to identify which form
                    alt_text = img.get('alt', '').strip().lower()
                    
                    if alt_text:
                        # Match alt text to variant name
                        matched_variant = match_form_name(alt_text, variant_names)
                        if matched_variant:
                            forms_that_learn.append(matched_variant)
        
        # If no form indicators found, all variants learn the move
        if not forms_that_learn:
            forms_that_learn = variant_names
        
        # Add move to each variant that can learn it
        move_data = {
            'tm_id': tm_id,
            'name': move_name,
            'type': move_type
        }
        
        for variant_name in forms_that_learn:
            variant_moves[variant_name].append(move_data)
        
        # Skip the description row
        i += 2
    
    return variant_moves


def detect_generation(url: str) -> int:
    """Detect which generation this URL is for based on the path."""
    if 'pokedex-sv' in url:
        return 9
    elif 'pokedex-swsh' in url:
        return 8
    else:
        # Default to 9 if unclear
        return 9


def partition_tables_by_game(all_tables: List, generation: int) -> Dict[str, List]:
    """
    Partition dextables by game based on generation.
    
    Gen 9: Legends: Z-A vs Scarlet and Violet
    Gen 8: Sword and Shield vs Brilliant Diamond and Shining Pearl
    
    Returns:
        Dict mapping game names to lists of table elements
    """
    games_tables = {}
    
    if generation == 9:
        # Gen 9: Legends vs SV
        legends_tables = []
        sv_tables = []
        
        last_legends_idx = -1
        for idx, table in enumerate(all_tables):
            rows = table.find_all('tr')
            if not rows:
                continue
            first_row_cells = rows[0].find_all('td') or rows[0].find_all('th')
            if first_row_cells:
                header_text = clean_text(first_row_cells[0].get_text())
                if 'legends' in header_text.lower():
                    last_legends_idx = idx
        
        for idx, table in enumerate(all_tables):
            rows = table.find_all('tr')
            if not rows:
                continue
            first_row_cells = rows[0].find_all('td') or rows[0].find_all('th')
            if not first_row_cells:
                continue
            
            header_text = clean_text(first_row_cells[0].get_text())
            header_lower = header_text.lower()
            
            is_move_table = any(x in header_lower for x in [
                'level up', 'level-up', 'technical machine', ' tm ', 'tr ',
                'egg', 'special', 'move tutor', 'tutor', 'attack'
            ])
            
            if not is_move_table:
                continue
            
            if idx <= last_legends_idx:
                legends_tables.append(table)
            else:
                sv_tables.append(table)
        
        if legends_tables:
            games_tables['Legends: Z-A'] = legends_tables
        if sv_tables:
            games_tables['Scarlet and Violet'] = sv_tables
    
    else:  # Generation 8
        # Gen 8: Separate SWSH, BDSP, and Pokémon Legends: Arceus
        # Tables are wrapped in divs with IDs: 'swshbdsp' or 'legends' (for PLA)
        swsh_tables = []
        bdsp_tables = []
        pla_tables = []
        
        for idx, table in enumerate(all_tables):
            rows = table.find_all('tr')
            if not rows:
                continue
            first_row_cells = rows[0].find_all('td') or rows[0].find_all('th')
            if not first_row_cells:
                continue
            
            header_text = clean_text(first_row_cells[0].get_text())
            header_lower = header_text.lower()
            
            is_move_table = any(x in header_lower for x in [
                'level up', 'level-up', 'technical machine', ' tm ', 'tr ',
                'egg', 'special', 'move tutor', 'tutor', 'attack', 'mastery'
            ])
            
            if not is_move_table:
                continue
            
            # Check parent div ID to determine which game section this table belongs to
            parent_div = table.find_parent('div')
            parent_id = parent_div.get('id', '').lower() if parent_div else ''
            
            # Categorize by parent div ID
            if 'legends' in parent_id:
                # Pokémon Legends: Arceus section
                pla_tables.append(table)
            elif 'bdsp' in header_lower or 'brilliant diamond' in header_lower or 'shining pearl' in header_lower:
                # Explicit BDSP marker in header
                bdsp_tables.append(table)
            elif 'swshbdsp' in parent_id:
                # SWSH/BDSP section - check header for BDSP marker
                if 'bdsp' in header_lower:
                    bdsp_tables.append(table)
                else:
                    swsh_tables.append(table)
            else:
                # Default to SWSH
                swsh_tables.append(table)
        
        if swsh_tables:
            games_tables['Sword and Shield'] = swsh_tables
        if bdsp_tables:
            games_tables['Brilliant Diamond and Shining Pearl'] = bdsp_tables
        if pla_tables:
            games_tables['Pokémon Legends: Arceus'] = pla_tables
    
    return games_tables


def parse_serebii_moves(soup: BeautifulSoup, base_name: str, variant_names: List[str], url: str = "") -> Dict:
    """
    Parse move data from Serebii page using dextable structure.
    
    Handles both Gen 8 (SWSH/BDSP) and Gen 9 (SV/Legends) pages.
    
    Serebii uses tables with class="dextable" containing:
    - Row 0: Header (identifies table type and variant)
    - Row 1: Column headers
    - Rows 2+: Move data (paired rows - data then description)
    
    Args:
        soup: BeautifulSoup parsed HTML
        base_name: Pokemon base name
        variant_names: List of all variant names for this Pokemon
        url: The URL (used to detect generation)
        
    Returns:
        Dict mapping pokemon name -> {gen_key: {game_name: movedata}, ...}
    """
    result = {}
    
    # Detect generation from URL
    generation = detect_generation(url)
    gen_key = f"gen_{generation}"
    
    # Find all dextables on the page
    all_tables = soup.find_all('table', class_='dextable')
    
    # Partition tables by game
    games_tables = partition_tables_by_game(all_tables, generation)
    
    # Process each game's tables
    games_data = {}
    for game_name, tables in games_tables.items():
        games_data[game_name] = _parse_game_section(
            tables, variant_names, base_name, game_name=game_name
        )
    
    # Combine results per variant
    for variant_name in variant_names:
        result[variant_name] = {gen_key: {}}
        for game_name, variant_data in games_data.items():
            if variant_name in variant_data:
                result[variant_name][gen_key][game_name] = variant_data[variant_name]
    
    return result


def _parse_game_section(tables: List, variant_names: List[str], base_name: str, game_name: str = "") -> Dict:
    """
    Parse all move tables in a game section.
    
    Args:
        tables: List of dextable elements to parse
        variant_names: List of variant names for this Pokemon
        base_name: Base Pokemon name
        game_name: The game this section is for (e.g., "Scarlet and Violet", "Sword and Shield", "Pokémon Legends: Arceus")
        
    Returns:
        Dict mapping variant_name -> {move_category: [...], ...}
    """
    result = {name: {} for name in variant_names}
    
    tm_table_found = False
    tr_table_found = False
    
    is_legends_za = 'Legends: Z-A' in game_name
    is_pla = 'Arceus' in game_name
    
    for table in tables:
        rows = table.find_all('tr')
        if len(rows) < 2:
            continue
        
        # Get header
        header_row_cells = rows[0].find_all('td')
        if not header_row_cells:
            header_row_cells = rows[0].find_all('th')
        
        if not header_row_cells:
            continue
        
        header_text = clean_text(header_row_cells[0].get_text())
        header_lower = header_text.lower()
        
        # Determine table type
        table_type = get_table_type(header_text)
        
        if table_type == "level_up":
            # Level-up moves - form-specific
            pokemon_name = match_form_name(header_text, variant_names)
            if not pokemon_name:
                pokemon_name = variant_names[0] if variant_names else base_name
            
            moves = parse_level_up_moves(table, is_legends=is_legends_za, is_pla=is_pla)
            result[pokemon_name]['level_up'] = moves
        
        elif table_type == "tm":
            # TM moves - only process once per section
            if not tm_table_found:
                variant_tm_moves = parse_tm_moves(table, variant_names)
                for variant_name, tm_moves in variant_tm_moves.items():
                    result[variant_name]['tm'] = tm_moves
                tm_table_found = True
        
        elif table_type == "tr":
            # Technical Record moves - only once per section, treat like TMs
            if not tr_table_found:
                variant_tr_moves = parse_tm_moves(table, variant_names)
                for variant_name, tr_moves in variant_tr_moves.items():
                    result[variant_name]['tr'] = tr_moves
                tr_table_found = True
        
        elif table_type == "egg_moves":
            # Egg moves - form-specific, handle game designations
            pokemon_name = match_form_name(header_text, variant_names)
            if not pokemon_name:
                pokemon_name = variant_names[0] if variant_names else base_name
            
            moves_by_game = parse_egg_or_special_moves(table, game_context=game_name)
            
            # Convert from game-keyed dict to flat list, handling 'all' entries
            final_moves = []
            for move_game, moves_list in moves_by_game.items():
                if move_game == 'all':
                    # Add to all games
                    final_moves.extend(moves_list)
                elif move_game == game_name:
                    # This game-specific move
                    final_moves.extend(moves_list)
                # Skip moves designated for other games
            
            result[pokemon_name]['egg_moves'] = final_moves
        
        elif table_type == "tutor_attacks" or table_type == "move_tutor":
            # Tutor moves - handle game designations
            pokemon_name = match_form_name(header_text, variant_names)
            if not pokemon_name:
                pokemon_name = variant_names[0] if variant_names else base_name
            
            moves_by_game = parse_egg_or_special_moves(table, game_context=game_name)
            
            # Convert to flat list
            final_moves = []
            for move_game, moves_list in moves_by_game.items():
                if move_game == 'all':
                    final_moves.extend(moves_list)
                elif move_game == game_name:
                    final_moves.extend(moves_list)
            
            category_key = 'tutor_attacks' if table_type == 'tutor_attacks' else 'move_tutor'
            if category_key not in result[pokemon_name]:
                result[pokemon_name][category_key] = []
            result[pokemon_name][category_key].extend(final_moves)
        
        elif table_type == "special_moves":
            # Special/egg moves - form-specific
            pokemon_name = match_form_name(header_text, variant_names)
            if not pokemon_name:
                pokemon_name = variant_names[0] if variant_names else base_name
            
            moves_by_game = parse_egg_or_special_moves(table, game_context=game_name)
            
            # Convert to flat list
            final_moves = []
            for move_game, moves_list in moves_by_game.items():
                if move_game == 'all':
                    final_moves.extend(moves_list)
                elif move_game == game_name:
                    final_moves.extend(moves_list)
            
            if 'special_moves' not in result[pokemon_name]:
                result[pokemon_name]['special_moves'] = []
            result[pokemon_name]['special_moves'].extend(final_moves)
        
        elif any(x in header_lower for x in ['stats', 'evolutionary', 'gender', 'weakness', 'evolution']):
            # Stop when we hit non-move sections
            break
    
    return result


def main():
    """Main function to collect Pokemon move data from Serebii."""
    print("Loading Pokemon data...")
    with open(POKEMON_JSON, 'r', encoding='utf-8') as f:
        pokemon_list = json.load(f)
    
    # Group Pokemon by base_name to get all variants that share the same URL
    pokemon_by_base = {}
    for pokemon in pokemon_list:
        base_name = pokemon.get('base_name')
        name = pokemon.get('name')
        if base_name:
            if base_name not in pokemon_by_base:
                pokemon_by_base[base_name] = []
            pokemon_by_base[base_name].append(name)
    
    print(f"Found {len(pokemon_by_base)} unique Pokemon base forms")
    
    # Create output directory for individual Pokemon files
    output_dir = DATA_DIR / "pokemon_moves"
    output_dir.mkdir(exist_ok=True)
    
    successful_count = 0
    failed = []  # Track Pokemon that failed (404 or no data found)
    errors = []  # Track Pokemon with errors during processing
    
    for i, (base_name, variant_names) in enumerate(pokemon_by_base.items(), 1):
        print(f"[{i}/{len(pokemon_by_base)}] Fetching moves for: {base_name}")
        
        try:
            url = make_pokemon_url(base_name)
            soup = fetch_html(url)
            
            moves = parse_serebii_moves(soup, base_name, variant_names, url=url)
            
            if moves:
                # Create individual JSON file keyed by full Pokemon name
                output_data = {}
                for pokemon_name, move_data in moves.items():
                    output_data[pokemon_name] = move_data
                    output_data[pokemon_name]['url'] = url
                
                # Save to individual file
                output_file = output_dir / f"{base_name}.json"
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(output_data, f, indent=2, ensure_ascii=False)
                
                successful_count += 1
                print(f"  ✓ Saved: {', '.join(moves.keys())}")
            else:
                # No moves found - could be missing variants
                failed.append({
                    'base_name': base_name,
                    'variants': variant_names,
                    'reason': 'No moves found on page',
                    'url': url
                })
                print(f"  ✗ No moves found")
            
            # Be polite to the server
            time.sleep(0.3)
            
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                failed.append({
                    'base_name': base_name,
                    'variants': variant_names,
                    'reason': '404 Not Found',
                    'url': make_pokemon_url(base_name)
                })
                print(f"  ✗ Not found (404)")
            else:
                errors.append({
                    'base_name': base_name,
                    'variants': variant_names,
                    'error': str(e),
                    'url': make_pokemon_url(base_name)
                })
                print(f"  ✗ Error: {e}")
        except Exception as e:
            errors.append({
                'base_name': base_name,
                'variants': variant_names,
                'error': str(e),
                'url': make_pokemon_url(base_name) if base_name else 'N/A'
            })
            print(f"  ✗ Error: {e}")
    
    # Save failures to a file for later fixing
    if failed or errors:
        failures_file = DATA_DIR / "pokemon_moves_failures.json"
        with open(failures_file, 'w', encoding='utf-8') as f:
            json.dump({
                'failed': failed,
                'errors': errors,
                'summary': {
                    'total_failed': len(failed),
                    'total_errors': len(errors)
                }
            }, f, indent=2, ensure_ascii=False)
        print(f"\n✓ Saved failures to {failures_file}")
    
    print(f"\n=== Summary ===")
    print(f"✓ Successful: {successful_count}/{len(pokemon_by_base)} Pokemon")
    print(f"✗ Failed (404 or no data): {len(failed)}")
    if failed[:5]:
        print(f"  Examples: {', '.join([f['base_name'] for f in failed[:5]])}")
    print(f"✗ Errors: {len(errors)}")
    if errors[:3]:
        for err_info in errors[:3]:
            print(f"  {err_info['base_name']}: {err_info['error'][:50]}")
    print(f"\nIndividual files saved to: {output_dir}/")


if __name__ == "__main__":
    main()
