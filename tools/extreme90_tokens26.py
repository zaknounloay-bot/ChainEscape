"""Phase 26 (development only): flag map tokens the engine's rules forbid
(scripts/core/level_manager.gd: switches, flip targets and armored blocks are
plain arrows - no spinner; armored blocks are never locked or switches; a
block cannot be a switch and a flip target). The parser repairs such a token
with an error, so the played board would differ from the designed one.
  python3 tools/extreme90_tokens26.py <drafts.json | run_lowov.json>"""
import json, re, sys


def bad(t):
    why = []
    if '@' in t and ('=' in t or '%' in t or '&' in t):
        why.append('spinner with switch / flip / armor')
    if '=' in t and ('#' in t or '%' in t):
        why.append('armored and locked / switch')
    if '%' in t and '&' in t:
        why.append('switch and flip target')
    return why


def check(m):
    return ['r%dc%d %s: %s' % (r, c, t, ', '.join(bad(t))) for r, row in enumerate(m) for c, t in enumerate(row.split()) if bad(t)]


if __name__ == '__main__':
    d = json.load(open(sys.argv[1]))
    items = d.items() if isinstance(d, dict) else enumerate(d)
    for k, v in items:
        print(k, check(v['map']) or 'ok')
