#!/usr/bin/env python3
import json, re
p='assets/data/moves.json'
d=json.load(open(p,'r',encoding='utf-8'))

def iter_moves(data):
    if isinstance(data, dict):
        for k, v in data.items():
            yield v if isinstance(v, dict) else {k: v}
    elif isinstance(data, list):
        for item in data:
            yield item

samples = []
for m in iter_moves(d):
    if not isinstance(m, dict):
        continue
    txt = m.get('detailed_effect', '')
    if not txt:
        continue
    if re.search(r'\bingrain\b', txt, re.I) or re.search(r'\b1/\d+\b', txt) or '/16' in txt:
        samples.append((m.get('name', '<no-name>'), txt))

print('Found', len(samples), 'matching examples; showing up to 8:')
for name, txt in samples[:8]:
    print('\n---', name, '---')
    print(txt)
    print('---end---')
