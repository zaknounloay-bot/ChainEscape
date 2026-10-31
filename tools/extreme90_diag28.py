"""Phase 28 (development only): root-cause statistics of the Phase 26-27 hybrid
pipeline (docs/extreme90_phase28.md, section C). Verification only.
  python3 tools/extreme90_diag28.py <out.json> <data dir> [<data dir> ...]
Per generator run (run_*.json): qualifying boards, the share with an
engine-invalid token (tools/extreme90_tokens26.py), the share under the
700-position screening cap, the share under the bank-overlap limit.
Per full evaluation (ev/eval_*.json + ev/report_*.json): which gate decided -
Category A / B verdict, filler, overlap, the strict essentiality rule
(unsolvable without a mechanic, or >= 2 distinct mistakes / >= 3 decision
steps fewer)."""
import glob, json, os, re, sys

sys.path.insert(0, os.path.dirname(__file__))
from extreme90_tokens26 import check

OUT, DIRS = sys.argv[1], sys.argv[2:]
_argv = sys.argv
sys.argv = ['x', DIRS[0], '0']
exec(open(os.path.join(os.path.dirname(__file__), 'extreme90_stage2.py')).read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
sys.argv = _argv
KNOWN = bank()


def essential(txt):
    """The strict Phase 21 rule on one counterfactual string."""
    if txt is None or 'unsolvable' in txt:
        return True
    m = re.search(r'without it: (\d+) decision steps, (\d+) distinct mistakes \(with it: (\d+), (\d+)\)', txt)
    if not m:
        return True
    s, d, S, Dd = map(int, m.groups())
    return Dd - d >= 2 or S - s >= 3


runs, evals = [], []
for D in DIRS:
    for f in sorted(g for g in glob.glob(D + '/run_*.json') if not g.endswith('_lowov.json')):
        q = json.load(open(f)).get('qualifying', [])
        inv = [b for b in q if check(b['map'])]
        cheap = [b for b in q if not check(b['map']) and b['positions'] <= 700]
        low = [b for b in cheap if max(sim(b['map'], m) for m in KNOWN.values()) < 0.40]
        runs.append({'run': os.path.basename(f)[4:-5], 'dir': os.path.basename(D), 'qualifying': len(q), 'invalid_token': len(inv),
                     'valid_le700': len(cheap), 'valid_le700_overlap_lt040': len(low)})
    for f in sorted(glob.glob(D + '/ev/eval_*.json')):
        name = os.path.basename(f)[5:-5]
        e = json.load(open(f))
        rp = D + '/ev/report_%s.json' % name
        r = json.load(open(rp))[name] if os.path.exists(rp) else None
        why = []
        if not e.get('bench_floor'):
            why.append('bench floor (A/B pre-check)')
        if r is not None:
            if r.get('verdict') != 'HUMAN-REVIEW CANDIDATE':
                why.append('Category A/B verdict')
            if e.get('filler'):
                why.append('filler')
            if e['overlap'][0] >= 0.40:
                why.append('overlap')
            bad = [k for k, v in r['B'].items() if (k.startswith('without_') or k == 'spinner_dependence') and isinstance(v, str) and not essential(v)]
            if bad:
                why.append('not essential: ' + ', '.join(bad))
            if check(r['map']):
                why.append('invalid token')
        evals.append({'board': name, 'dir': os.path.basename(D), 'technical_fail': why})
tot = lambda k: sum(r[k] for r in runs)
summary = {
    'runs': len(runs), 'runs_with_qualifying': sum(1 for r in runs if r['qualifying']),
    'qualifying': tot('qualifying'), 'invalid_token': tot('invalid_token'),
    'invalid_token_rate': round(tot('invalid_token') / max(tot('qualifying'), 1), 3),
    'valid_le700': tot('valid_le700'), 'valid_le700_overlap_lt040': tot('valid_le700_overlap_lt040'),
    'full_evaluations': len(evals), 'technically_clean': sum(1 for e in evals if not e['technical_fail']),
    'fail_reasons': {},
}
for e in evals:
    for w in e['technical_fail']:
        k = w.split(':')[0]
        summary['fail_reasons'][k] = summary['fail_reasons'].get(k, 0) + 1
json.dump({'summary': summary, 'runs': runs, 'evaluations': evals}, open(OUT, 'w'), indent=1)
print(json.dumps(summary, indent=1))
for r in runs:
    print('%-28s %-14s qual %4d invalid %4d valid<=700 %4d  +overlap<0.40 %4d' % (r['run'], r['dir'], r['qualifying'], r['invalid_token'], r['valid_le700'], r['valid_le700_overlap_lt040']))
for e in evals:
    print('%-18s %-14s %s' % (e['board'], e['dir'], '; '.join(e['technical_fail']) or 'TECHNICALLY CLEAN'))
