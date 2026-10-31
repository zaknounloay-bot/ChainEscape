"""Phase 28 (development only): a run's shortlist for the early screen
(docs/extreme90_phase28.md). Valid tokens only, <= max positions, distinct
maps, the n with the lowest bank overlap (ties: fewer positions).
  python3 tools/extreme90_shortlist28.py <run.json> <prefix> <n> <out.json> [max_positions]"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from extreme90_tokens26 import check
run, pre, n, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
cap = int(sys.argv[5]) if len(sys.argv) > 5 else 700
_argv = sys.argv
sys.argv = ['x', os.path.dirname(run), '0']
exec(open(os.path.join(os.path.dirname(__file__), 'extreme90_stage2.py')).read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
sys.argv = _argv
known = bank()
seed = json.load(open(run.replace('/run_', '/seed_').rsplit('_s', 1)[0] + '.json'))
q = json.load(open(run))['qualifying']
rows, seen = [], set()
for b in q:
    if b['positions'] > cap or check(b['map']) or tuple(b['map']) in seen:
        continue
    seen.add(tuple(b['map']))
    rows.append((max(sim(b['map'], m) for m in known.values()), b['positions'], b))
rows.sort(key=lambda r: (round(r[0], 2), r[1]))
res = {'%s_%d' % (pre, i): {'map': r[2]['map'], 'mechanic': seed['mechanic'], 'positions': r[2]['positions']} for i, r in enumerate(rows[:n])}
json.dump(res, open(out, 'w'), indent=1)
print('%s: %d qualifying, %d valid <= %d, shortlisted %d (overlap %s)' % (os.path.basename(run), len(q), len(rows), cap, len(res), [round(r[0], 2) for r in rows[:n]]))
