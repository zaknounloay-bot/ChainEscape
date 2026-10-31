"""Phase 26 (development only): flag map tokens the engine's rules forbid
(scripts/core/level_manager.gd: switches, flip targets and armored blocks are
plain arrows - no spinner; armored blocks are never locked or switches; a
block cannot be a switch and a flip target). The parser repairs such a token
with an error, so the played board would differ from the designed one.
  python3 tools/extreme90_tokens26.py <drafts.json | run_lowov.json>"""
import json, re, sys


RE = re.compile(r'^([RBGYP])([\^v<>])(@[-~*]?)?(\?)?(#[RBGYP])?(\$[SGD])?(%[ABCD])?(&[ABCD])?(\+[ABCD])?(=)?(:[\^v<>])?(![TUVW])?(\*)?$')


def bad(t):
    """Phase 28: the same rules as tools/xb28_validate.gd (token level)."""
    if t in ('.', 'M') or (len(t) == 2 and t[0] in 'XO'):
        return []
    m = RE.match(t)
    if not m:
        return ['unparsable']
    sp, hid, lock, rew, sw, flip, link, arm, seq, twin, mag = (m.group(i) for i in range(3, 14))
    why = []
    if sp and (sw or flip or arm):
        why.append('spinner with switch / flip / armor')
    if sp and hid:
        why.append('hidden spinner')
    if hid and lock:
        why.append('hidden and locked')
    if lock and lock[1] == m.group(1):
        why.append('locked by its own colour')
    if sw and flip:
        why.append('switch and flip target')
    if arm and (lock or sw):
        why.append('armored and locked / switch')
    if seq and (sp or hid or lock or rew or sw or flip or link or arm or twin or mag):
        why.append('Sequence with another mark')
    if mag and (sp or lock or sw or link or arm or seq or twin):
        why.append('magnet with a spinner / lock / switch / link / armor / Sequence / twin role')
    if twin and (sp or hid or lock or sw or arm or rew or seq):
        why.append('twin that is not a plain arrow')
    return why


def check(m):
    return ['r%dc%d %s: %s' % (r, c, t, ', '.join(bad(t))) for r, row in enumerate(m) for c, t in enumerate(row.split()) if bad(t)]


if __name__ == '__main__':
    d = json.load(open(sys.argv[1]))
    items = d.items() if isinstance(d, dict) else enumerate(d)
    for k, v in items:
        print(k, check(v['map']) or 'ok')
