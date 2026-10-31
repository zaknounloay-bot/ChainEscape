"""Phase 28 (development only): the EARLY SCREEN, run on a run's whole
shortlist before any full evaluation (docs/extreme90_phase28.md, section D).
Verification only - it decides nothing a full evaluation would not decide;
it only stops boards that would certainly fail one from using the budget.
  python3 tools/extreme90_screen28.py <shortlist.json> <out dir> <godot>
shortlist.json: {"name": {"map": [...], "mechanic": "switch,armor"}, ...}
In order, cheapest first:
  1. engine-valid tokens (tools/extreme90_tokens26.py, the xb28 rules);
  2. bank overlap < 0.40 (tools/extreme90_stage2.py's sim);
  3. ONE quick design report for all of them (tools/ta90_design.gd --quick:
     Category A including the 40 ms TIME UP gate, Category B including every
     mechanic's counterfactual) - verdict, and the STRICT essentiality rule
     (unsolvable without the mechanic, or >= 2 distinct mistakes / >= 3
     decision steps fewer) on every mechanic and on spinners;
  4. ONE filler pass for the survivors (tools/xb90_filler.gd): 0 trivial pieces.
Writes <out dir>/screen.json: per board the first failed step, or "PASS"."""
import json, os, re, subprocess, sys

sys.path.insert(0, os.path.dirname(__file__))
from extreme90_tokens26 import check

SRC, OUT, G = sys.argv[1], sys.argv[2].rstrip('/'), sys.argv[3]
os.makedirs(OUT, exist_ok=True)
_argv = sys.argv
sys.argv = ['x', OUT, '0']
exec(open(os.path.join(os.path.dirname(__file__), 'extreme90_stage2.py')).read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
sys.argv = _argv
G = _argv[3]
KNOWN = bank()


def essential(txt):
    if not isinstance(txt, str) or 'unsolvable' in txt:
        return True
    m = re.search(r'without it: (\d+) decision steps, (\d+) distinct mistakes \(with it: (\d+), (\d+)\)', txt)
    if not m:
        return True
    s, d, S, Dd = map(int, m.groups())
    return Dd - d >= 2 or S - s >= 3


def godot(args, log):
    with open(log, 'w') as f:
        subprocess.run(['timeout', '3000', G, '--headless', '--path', '.', '--script'] + args, stdout=f, stderr=subprocess.STDOUT)


drafts = json.load(open(SRC))
res, live = {}, {}
for k, d in drafts.items():
    if check(d['map']):
        res[k] = {'result': 'invalid token', 'detail': check(d['map'])}
        continue
    ov = max((round(sim(d['map'], b), 2), n) for n, b in KNOWN.items())
    if ov[0] >= 0.40:
        res[k] = {'result': 'overlap', 'detail': ov}
        continue
    live[k] = {'map': d['map'], 'target': 'EXTREME', 'facts': [], 'mechanic': d.get('mechanic', ''), 'max_positions': 2000, 'overlap': ov}
if live:
    json.dump(live, open(OUT + '/screen_in.json', 'w'), indent=1)
    godot(['res://tools/ta90_design.gd', '--', '--file=' + OUT + '/screen_in.json', '--quick', '--out=' + OUT + '/screen_report.json'], OUT + '/screen_report.log')
    rep = json.load(open(OUT + '/screen_report.json'))
    fill = []
    for k in live:
        r = rep.get(k, {})
        why = [w for w in r.get('why_a', []) + r.get('why_b', []) if 'incomplete' not in str(w) and 'learner' not in str(w) and 'parity' not in str(w)]
        bad = [m for m, v in r.get('B', {}).items() if (m.startswith('without_') or m == 'spinner_dependence') and not essential(v)]
        if r.get('A', {}).get('winnable') is None and not r.get('B'):
            res[k] = {'result': 'Category A', 'detail': r.get('why_a')}
        elif why:
            res[k] = {'result': 'Category A/B', 'detail': why}
        elif bad:
            res[k] = {'result': 'not essential', 'detail': {m: r['B'][m] for m in bad}}
        else:
            fill.append(k)
            res[k] = {'result': 'pending filler', 'B': {m: v for m, v in r['B'].items() if not m.startswith('line')},
                      'A': {x: r['A'].get(x) for x in ('positions', 'solution', 'solve_ms', 'timeup_worst_ms')}, 'overlap': live[k]['overlap']}
    if fill:
        godot(['res://tools/xb90_filler.gd', '--', '--file=' + OUT + '/screen_in.json', '--name=' + ','.join(fill), '--out=' + OUT + '/screen_filler.json'], OUT + '/screen_filler.log')
        fl = json.load(open(OUT + '/screen_filler.json'))
        for k in fill:
            n = fl.get(k, {}).get('trivial_removals', 1)
            res[k]['result'] = 'PASS' if n == 0 else 'filler'
            res[k]['filler'] = fl.get(k, {}).get('trivial', [])
json.dump(res, open(OUT + '/screen.json', 'w'), indent=1)
for k, v in res.items():
    print('%-22s %-14s %s' % (k, v['result'], str(v.get('detail', v.get('filler', '')))[:150]))
print('SCREEN: %d boards, %d PASS' % (len(res), sum(1 for v in res.values() if v['result'] == 'PASS')))
