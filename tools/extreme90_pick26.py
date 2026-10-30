"""Phase 26 (development only): shortlist a generator run's qualifying boards
(docs/extreme90_phase26.md, section E). Verification only.
  python3 tools/extreme90_pick26.py <run.json> <prefix> <n> <out.json> [max_positions]
Keeps the qualifying boards (tools/ta90_search.gd's own EXTREME targets),
drops those above max_positions (default 900: the 40 ms TIME UP gate fails
well before that on most boards), and writes the n cheapest distinct maps,
in the drafts format of tools/extreme90_eval25.py, with the core's mechanic."""
import json, sys

run, pre, n, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
cap = int(sys.argv[5]) if len(sys.argv) > 5 else 900
seed = json.load(open(run.replace('/run_', '/seed_').rsplit('_s', 1)[0] + '.json'))
q = [b for b in json.load(open(run))['qualifying'] if b['positions'] <= cap]
q.sort(key=lambda b: (b['positions'], -b['score']))
seen, picks = set(), {}
for b in q:
    k = tuple(b['map'])
    if k in seen:
        continue
    seen.add(k)
    picks['%s_c%d' % (pre, len(picks) + 1)] = {'map': b['map'], 'mechanic': seed['mechanic'], 'positions': b['positions'], 'score': b['score']}
    if len(picks) >= n:
        break
json.dump(picks, open(out, 'w'), indent=1)
print('%s: %d qualifying, %d under %d positions, picked %d' % (run, len(json.load(open(run))['qualifying']), len(q), cap, len(picks)))
