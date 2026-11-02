"""Phase 31 (development only): the two shortlist rules on ONE run's
qualifying pool (docs/extreme90_phase31.md, section C). Verification only.
  python3 tools/extreme90_sel31.py <run.json> <seed spec> <prefix> <n> <out.json>
Both rules keep engine-valid tokens only (tools/extreme90_tokens26.py - a
reliability fix kept for every arm) and distinct maps:
  S_old  Phase 25/26 (tools/extreme90_pick26.py): <= 900 positions, the n
         cheapest (fewest positions; ties: higher search score)
  S_p30  Phase 28-30 as executed (tools/extreme90_shortlist28.py with the
         Phase 30 cap): <= 1000 positions, the n with the lowest bank
         overlap (ties: fewer positions)
Writes the union {"name": {"map", "mechanic", "positions", "overlap", "rules": [...]}}
for ONE screen (tools/extreme90_screen30.py), so both rules are reviewed by
the same screen run."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from extreme90_tokens26 import check
run, spec, pre, n, out = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
_argv = sys.argv
sys.argv = ['x', os.path.dirname(os.path.abspath(out)), '0']
exec(open(os.path.join(os.path.dirname(__file__), 'extreme90_stage2.py')).read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
sys.argv = _argv
known = bank()
mech = json.load(open(spec))['mechanic']
q = json.load(open(run))['qualifying']
rows, seen = [], set()
for b in q:
    k = tuple(b['map'])
    if k in seen or check(b['map']):
        continue
    seen.add(k)
    ov = max(sim(b['map'], m) for m in known.values())
    rows.append({'map': b['map'], 'positions': b['positions'], 'score': b.get('score', 0), 'overlap': round(ov, 2)})
old = sorted([r for r in rows if r['positions'] <= 900], key=lambda r: (r['positions'], -r['score']))[:n]
new = sorted([r for r in rows if r['positions'] <= 1000], key=lambda r: (r['overlap'], r['positions']))[:n]
res, idx = {}, {}
for rule, lst in (('S_old', old), ('S_p30', new)):
    for r in lst:
        k = tuple(r['map'])
        if k not in idx:
            idx[k] = '%s_%d' % (pre, len(idx))
            res[idx[k]] = {'map': r['map'], 'mechanic': mech, 'positions': r['positions'], 'overlap': r['overlap'], 'rules': []}
        res[idx[k]]['rules'].append(rule)
json.dump(res, open(out, 'w'), indent=1)
print('%s: %d qualifying, %d valid distinct; S_old %d (pos %s), S_p30 %d (pos %s), union %d' % (
    os.path.basename(os.path.dirname(run)) or run, len(q), len(rows), len(old), [r['positions'] for r in old], len(new), [r['positions'] for r in new], len(res)))
