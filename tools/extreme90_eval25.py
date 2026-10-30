"""Phase 25 (development only): evaluate hand-designed drafts in one pass
(docs/extreme90_phase25.md). Verification only - it generates nothing.
  python3 tools/extreme90_eval25.py <drafts.json> <out dir> <godot> [--full] [--mech=a,b]
drafts.json: {"name": {"map": [...], "mechanic": "magnet,armor"}, ...}
1. tools/ta90_bench24.gd on every draft: solvable, positions, the human-fit
   features (distinct, steps, coverage, solution, shortcut ...).
2. With --full, every draft whose bench numbers meet the EXTREME floor
   (distinct >= 4, steps >= 8, coverage >= 0.60, solution >= 13,
   shortcut <= 0.20) gets the full report (tools/ta90_design.gd), the filler
   check (tools/xb90_filler.gd) and the occupancy overlap against the bank
   (tools/extreme90_stage2.py's measure, every data/dev/ta90_n*.json board).
Prints one line per draft and writes <out dir>/eval_<name>.json."""
import json, os, re, subprocess, sys

sys.argv, ARGS = sys.argv[:4], sys.argv[4:]
SRC, OUT, G = sys.argv[1], sys.argv[2].rstrip('/'), sys.argv[3]
FULL = '--full' in ARGS
os.makedirs(OUT, exist_ok=True)
_argv = sys.argv
sys.argv = ['x', OUT, '0']
exec(open(os.path.join(os.path.dirname(__file__), 'extreme90_stage2.py')).read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
sys.argv = _argv
G = _argv[3]  # the stage-2 code above redefines G
D = OUT


def godot(args, log):
    with open(log, 'w') as f:
        subprocess.run(['timeout', '3000', G, '--headless', '--path', '.', '--script'] + args, stdout=f, stderr=subprocess.STDOUT)
    return open(log).read()


drafts = json.load(open(SRC))
known = bank()
txt = godot(['res://tools/ta90_bench24.gd', '--', '--file=' + SRC], OUT + '/bench.log')
feat, head = {}, {}
for m in re.finditer(r'== (\S+): (\d+) positions(?: \(CAPPED\))?, winnable (\w+)', txt):
    head[m.group(1)] = (int(m.group(2)), m.group(3) == 'true')
cur = None
for line in txt.splitlines():
    m = re.match(r'== (\S+):', line)
    if m:
        cur = m.group(1)
    elif line.strip().startswith('features') and cur:
        feat[cur] = json.loads(line.strip()[len('features '):])
for name, d in drafts.items():
    pos, ok = head.get(name, (0, False))
    f = feat.get(name, {})
    ov = max(((round(sim(d['map'], b), 2), k) for k, b in known.items()), default=(0, ''))
    res = {'positions': pos, 'winnable': ok, 'features': f, 'overlap': ov}
    floor = ok and f.get('distinct', 0) >= 4 and f.get('steps', 0) >= 8 and f.get('coverage', 0) >= 0.60 and f.get('solution', 0) >= 13 and f.get('shortcut', 1) <= 0.20
    res['bench_floor'] = floor
    line = '%-10s %s pos %4d dist %s steps %s cov %s sol %s short %s eff %s | overlap %.2f %s' % (
        name, 'OK ' if ok else 'UNS', pos, f.get('distinct'), f.get('steps'), f.get('coverage'), f.get('solution'), f.get('shortcut'), f.get('effective_decisions'), ov[0], ov[1])
    if FULL and floor:
        spec = {name: {'map': d['map'], 'target': 'EXTREME', 'facts': [], 'mechanic': d.get('mechanic', ''), 'max_positions': 2000}}
        cf = OUT + '/cand_%s.json' % name
        json.dump(spec, open(cf, 'w'), indent=1)
        godot(['res://tools/ta90_design.gd', '--', '--file=' + cf, '--out=' + OUT + '/report_%s.json' % name], OUT + '/report_%s.log' % name)
        r = json.load(open(OUT + '/report_%s.json' % name))[name]
        godot(['res://tools/xb90_filler.gd', '--', '--file=' + cf, '--name=' + name, '--out=' + OUT + '/filler_%s.json' % name], OUT + '/filler_%s.log' % name)
        fl = json.load(open(OUT + '/filler_%s.json' % name))[name]
        res.update({'verdict': r.get('verdict'), 'why': r.get('why_a', []) + r.get('why_b', []), 'A': r.get('A'), 'B': {k: v for k, v in r.get('B', {}).items() if not k.startswith('line')}, 'filler': fl.get('trivial_removals'), 'trivial': fl.get('trivial')})
        line += ' || %s; filler %s; solve %s ms, timeup %s ms; %s' % (r.get('verdict'), fl.get('trivial_removals'), r['A'].get('solve_ms'), r['A'].get('timeup_worst_ms'), '; '.join(map(str, res['why']))[:200])
    json.dump(res, open(OUT + '/eval_%s.json' % name, 'w'), indent=1)
    print(line, flush=True)
