"""Phase 26 (development only): occupancy overlap of a run's qualifying boards
against the bank and the boards already chosen (boards with an engine-invalid
token, tools/extreme90_tokens26.py, are skipped) (tools/extreme90_stage2.py's
sim measure, unchanged). Verification only.
  python3 tools/extreme90_overlap26.py <run.json> <chosen.json> <max_positions> <n>"""
import json, os, sys
_argv = sys.argv
sys.argv = ['x', os.path.dirname(_argv[1]), '0']
exec(open(os.path.join(os.path.dirname(__file__), 'extreme90_stage2.py')).read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
sys.argv = _argv
run, chosen, cap, n = sys.argv[1], json.load(open(sys.argv[2])), int(sys.argv[3]), int(sys.argv[4])
known = bank()
known.update({k: v['map'] for k, v in chosen.items()})
sys.path.insert(0, os.path.dirname(__file__))
from extreme90_tokens26 import check
q = [b for b in json.load(open(run))['qualifying'] if b['positions'] <= cap and not check(b['map'])]
seen, rows = set(), []
for b in q:
    if tuple(b['map']) in seen:
        continue
    seen.add(tuple(b['map']))
    ov = max((round(sim(b['map'], m), 2), k) for k, m in known.items())
    rows.append((ov[0], b['positions'], ov[1], b))
rows.sort(key=lambda r: (r[0], r[1]))
for r in rows[:n]:
    print('%.2f %-5s pos %4d dist %s sol %s' % (r[0], r[2], r[1], r[3]['distinct'], r[3]['solution']))
json.dump([r[3] for r in rows[:n]], open(run.replace('.json', '_lowov.json'), 'w'), indent=1)
