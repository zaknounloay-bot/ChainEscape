"""Phase 31 (development only): technical endpoints of the controlled
generator comparison (docs/extreme90_phase31.md, section C).
  python3 tools/extreme90_ana31.py            -> data/dev/extreme90_p31/exp/technical.json
Per run (arms A / C1 / C2 from data/dev/extreme90_p31/exp/runs, arm B = the
recorded Phase 30 run with the same core and RNG seed):
  evaluated, qualifying, valid (engine-valid tokens, distinct maps),
  positions of the valid pool (median, share <= 400), best search score.
If screen results exist (exp/screen/<run>/screen30.json) it adds, per rule
(S_old / S_p30), how many shortlisted boards pass the modern screen and the
positions and early3 (sum of losing moves at solution steps 1-3) of the passing boards.
Measures only: no board is selected here."""
import glob, json, os, statistics, sys
sys.path.insert(0, os.path.dirname(__file__))
from extreme90_tokens26 import check

ROOT = os.path.abspath('.')
EXP = ROOT + '/data/dev/extreme90_p31/exp'
P30 = ROOT + '/data/dev/extreme90_p30/runs'


def pool(run):
    d = json.load(open(run))
    seen, valid = set(), []
    for b in d.get('qualifying', []):
        k = tuple(b['map'])
        if k in seen or check(b['map']):
            continue
        seen.add(k)
        valid.append(b)
    pos = [b['positions'] for b in valid]
    return {'generator': d.get('generator'), 'evaluated': d.get('evaluated'),
            'qualifying': len(d.get('qualifying', [])), 'valid': len(valid),
            'pos_median': statistics.median(pos) if pos else None,
            'pos_le400': round(sum(p <= 400 for p in pos) / len(pos), 2) if pos else None,
            'best_score': round(max((b.get('score', 0) for b in valid), default=0), 1)}


def screen(name):
    f = '%s/screen/%s/screen30.json' % (EXP, name)
    sl = '%s/screen/%s/shortlist.json' % (EXP, name)
    if not (os.path.exists(f) and os.path.exists(sl)):
        return None
    res, short = json.load(open(f)), json.load(open(sl))
    out = {}
    for rule in ('S_old', 'S_p30'):
        keys = [k for k, v in short.items() if rule in v['rules']]
        ok = [k for k in keys if res.get(k, {}).get('result') == 'PASS']
        e3 = {k: sum(res[k]['B']['losing_per_step'][:3]) for k in ok if 'B' in res[k]}
        out[rule] = {'shortlisted': len(keys), 'pass': len(ok),
                     'pass_positions': sorted(short[k]['positions'] for k in ok),
                     'pass_early3': sorted(e3.values()),
                     'results': sorted(res.get(k, {}).get('result', 'missing') for k in keys)}
    return out


rows = {}
for d in sorted(glob.glob(EXP + '/runs/*/run.json')):
    name = os.path.basename(os.path.dirname(d))
    arm, rest = name.split('_', 1)
    rows[name] = dict(arm=arm, core=rest.rsplit('_s', 1)[0], **pool(d))
    rows[name]['screen'] = screen(name)
    b = '%s/%s/run.json' % (P30, rest)
    if os.path.exists(b) and 'B_' + rest not in rows:
        rows['B_' + rest] = dict(arm='B', core=rest.rsplit('_s', 1)[0], **pool(b))
        rows['B_' + rest]['screen'] = screen('B_' + rest)
json.dump(rows, open(EXP + '/technical.json', 'w'), indent=1)
print('%-34s %-9s %5s %5s %5s %6s %5s %6s' % ('run', 'gen', 'eval', 'qual', 'valid', 'posmed', '<=400', 'best'))
for k in sorted(rows, key=lambda k: (rows[k]['core'], rows[k]['arm'])):
    r = rows[k]
    print('%-34s %-9s %5s %5d %5d %6s %5s %6s  %s' % (k, r['generator'], r['evaluated'], r['qualifying'], r['valid'],
          r['pos_median'], r['pos_le400'], r['best_score'], json.dumps(r['screen']) if r['screen'] else ''))
