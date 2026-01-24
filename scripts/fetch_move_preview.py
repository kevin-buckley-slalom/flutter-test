#!/usr/bin/env python3
from update_moves_detailed_effects import slugify, fetch_detailed_effect
import requests
import sys

moves = sys.argv[1:]
if not moves:
    print('Usage: fetch_move_preview.py "Move Name" [Another]')
    raise SystemExit(1)

s = requests.Session()
for m in moves:
    sl = slugify(m)
    print(f'--- {m} -> slug: {sl} ---')
    d = fetch_detailed_effect(sl, s)
    if d is None:
        print('<no detailed effect found>')
    else:
        print(d)
    print('\n')
