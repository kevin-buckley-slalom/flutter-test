#!/usr/bin/env python3
"""Replace single newlines with double-newlines in the detailed_effect field of moves.json.

Creates a backup at the provided backup path (default: input + '.bak_newlines').
"""
import argparse
import json
from pathlib import Path
import time


def normalize_newlines(s: str) -> str:
    s = s.replace("\r\n", "\n")
    # collapse any existing multiple blank-lines into a single newline
    while "\n\n\n" in s:
        s = s.replace("\n\n\n", "\n\n")
    # ensure consistent single-newline baseline
    s = s.replace("\n\n", "\n")
    # now replace every single newline with a double-newline
    s = s.replace("\n", "\n\n")
    return s


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input", "-i", default="assets/data/moves.json")
    p.add_argument("--backup", "-b", action="store_true")
    p.add_argument("--backup-path", default=None)
    args = p.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        raise SystemExit(f"Input file not found: {input_path}")

    data = json.loads(input_path.read_text(encoding="utf-8"))

    changed = 0
    for k, v in data.items():
        if isinstance(v, dict) and "detailed_effect" in v and isinstance(v["detailed_effect"], str):
            orig = v["detailed_effect"]
            new = normalize_newlines(orig)
            if new != orig:
                v["detailed_effect"] = new
                changed += 1

    if args.backup:
        backup_path = args.backup_path or (input_path.with_suffix(input_path.suffix + ".bak_newlines"))
        # avoid overwriting an existing backup: append timestamp
        if Path(backup_path).exists():
            backup_path = Path(str(backup_path) + f".{int(time.time())}")
        input_path.rename(backup_path)
        print(f"Backup written to: {backup_path}")

    input_path.write_text(json.dumps(data, ensure_ascii=False, indent=4), encoding="utf-8")
    print(f"Updated {input_path} — changed {changed} entries.")


if __name__ == "__main__":
    main()
