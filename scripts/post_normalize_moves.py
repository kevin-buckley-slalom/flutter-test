#!/usr/bin/env python3
import argparse
import json, re

p='assets/data/moves.json'
with open(p,'r',encoding='utf-8') as fh:
    data=json.load(fh)

def iter_moves(data):
    if isinstance(data, dict):
        for k,v in data.items():
            yield v if isinstance(v, dict) else {k:v}
    elif isinstance(data, list):
        for item in data:
            yield item

def post_normalize(text: str) -> str:
    if not text:
        return text
    t = text
    t = t.replace('⁄','/')
    # Ensure space after punctuation if missing
    t = re.sub(r'([,.;:!?])(?=[A-Za-z0-9])', r'\1 ', t)
    # Add spaces around fraction tokens lacking spaces
    t = re.sub(r'(?<!\s)(\d+/\d+)(?!\s)', r' \1 ', t)
    # Insert space between lowercase/number and CapitalizedWord
    t = re.sub(r'([a-z0-9])([A-Z][a-z])', r'\1 \2', t)
    # Remove sentences referencing glossary
    t = re.sub(r'[^.]*glossary[^.]*\.?', '', t, flags=re.I)
    # Collapse whitespace
    t = re.sub(r'\s+', ' ', t).strip()
    return t
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--names', help='Comma-separated move names to process (case-insensitive)')
    ap.add_argument('--dry-run', action='store_true', help='Do not write changes; just show diffs')
    args = ap.parse_args()

    target = None
    if args.names:
        target = set([s.strip().lower() for s in args.names.split(',') if s.strip()])

    changes = []
    for m in iter_moves(data):
        if not isinstance(m, dict):
            continue
        name = m.get('name','').strip()
        if not name:
            continue
        if target and name.lower() not in target:
            continue
        orig = m.get('detailed_effect','')
        new = post_normalize(orig)
        if new != orig:
            changes.append((name, orig, new))
            if not args.dry_run:
                m['detailed_effect'] = new

    if args.dry_run:
        for name, orig, new in changes:
            print('\n===', name, '===')
            print('\n-- original --\n')
            print(orig)
            print('\n-- normalized --\n')
            print(new)
        print(f'\nDry-run: {len(changes)} entries would be changed')
    else:
        if changes:
            # backup and write
            with open(p + '.bak2', 'w', encoding='utf-8') as fh:
                json.dump(data, fh, ensure_ascii=False, indent=2)
            with open(p, 'w', encoding='utf-8') as fh:
                json.dump(data, fh, ensure_ascii=False, indent=2)
        print('Post-normalized', len(changes), 'entries; backup saved to', p + '.bak2' if changes else 'none')


if __name__ == '__main__':
    main()
