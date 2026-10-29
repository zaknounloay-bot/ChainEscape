"""EXTREME bank stage 2 (Phase 21 protocol, applied mechanically; used unchanged in Phase 22).
  python3 tools/extreme90_stage2.py <data dir> <seed> [godot binary]   (from the repo root; appends to <dir>/stage2_state.json)
Candidates of the round -> similarity pre-filter -> full reports one at a time,
round-robin across families -> acceptance rules -> filler -> accepted list."""
import json, glob, os, re, subprocess, sys

D = sys.argv[1].rstrip('/')
G = sys.argv[3] if len(sys.argv) > 3 else 'godot'
P = json.load(open(D + '/protocol.json'))
FAM = {k: f for f, ks in P['families'].items() for k in ks}
SIM_MAX, REPORTS_MAX, ACCEPT_MAX, PER_FAMILY = 0.40, 40, 10, 3
STATE = D + '/stage2_state.json'


def cells(m):
    return {(r, c): ('@' in t, t == 'M', t[:1] == 'O' and len(t) == 2) for r, row in enumerate(m) for c, t in enumerate(row.split()) if t != '.'}


def syms(m):
    g = [row.split() for row in m]
    out = []
    for _ in range(4):
        out.append(g)
        out.append([r[::-1] for r in g])
        g = [list(x) for x in zip(*g[::-1])]
    return [[" ".join(r) for r in x] for x in out]


def sim(a, b):
    oa = cells(a)
    best = 0
    for s in syms(b):
        ob = cells(s)
        inter = sum(1 for k in oa if k in ob and oa[k] == ob[k])
        best = max(best, inter / len(set(oa) | set(ob)))
    return best


def diff(a, b):
    ca = [c for row in a for c in row.split()]
    cb = [c for row in b for c in row.split()]
    return sum(x != y for x, y in zip(ca, cb)) if len(ca) == len(cb) else 99


def bank():
    known = {}
    for f in glob.glob('data/dev/ta90_n*.json'):
        for b in json.load(open(f))["boards"]:
            known[b["id"]] = b["puzzle"]["map"]
    return known


def essential(B, mechs):
    """Every listed mechanic essential: unsolvable without it, or >= 2 distinct / >= 3 steps fewer."""
    why = []
    for m in mechs:
        w = str(B.get('without_' + m, ''))
        if 'unsolvable' in w or 'falls apart' in w:
            continue
        x = re.match(r'without it: (\d+) decision steps, (\d+) distinct mistakes \(with it: (\d+), (\d+)\)', w)
        if not x:
            why.append('%s: %s' % (m, w or 'no counterfactual'))
            continue
        s, d, s0, d0 = map(int, x.groups())
        if not (d0 - d >= 2 or s0 - s >= 3):
            why.append('%s marginal (%s)' % (m, w))
    return why


def godot(args, log):
    with open(log, 'w') as f:
        subprocess.run(['timeout', '3000', G, '--headless', '--path', '.', '--script'] + args, stdout=f, stderr=subprocess.STDOUT)


def main(seed):
    st = json.load(open(STATE)) if os.path.exists(STATE) else {"accepted": [], "reports": 0, "log": []}
    known = bank()
    acc_maps = {a['key']: a['map'] for a in st['accepted']}
    # 1. candidates of this round
    pool = []
    for f in sorted(glob.glob(f'{D}/run_*_s{seed}.json')):
        core = os.path.basename(f)[4:-len(f'_s{seed}.json')]
        j = json.load(open(f))
        reps = []
        for q in sorted(j.get('qualifying', []), key=lambda x: -x['score']):
            if all(diff(q['map'], r['map']) > 3 for r in reps):
                reps.append(q)
            if len(reps) == 2:
                break
        for i, q in enumerate(reps):
            pool.append({'key': f'{core}_s{seed}_{i + 1}', 'core': core, 'family': FAM[core], 'map': q['map'], 'score': q['score'],
                         'search': {k: q.get(k) for k in ('distinct', 'steps', 'shortcut', 'positions', 'pieces')}})
    # 2. similarity pre-filter (bank, accepted, better-ranked pool boards)
    kept = []
    for c in sorted(pool, key=lambda x: -x['score']):
        sb = max(((sim(c['map'], m), k) for k, m in list(known.items()) + list(acc_maps.items())), default=(0, ''))
        sp = max(((sim(c['map'], k['map']), k['key']) for k in kept), default=(0, ''))
        c['closest'] = {'known': sb[1], 'overlap': round(sb[0], 2), 'pool': sp[1], 'pool_overlap': round(sp[0], 2)}
        if sb[0] >= SIM_MAX:
            st['log'].append({'key': c['key'], 'stage': 'prefilter', 'decision': 'dropped', 'why': 'overlap %.2f with %s' % sb})
        elif sp[0] >= SIM_MAX:
            st['log'].append({'key': c['key'], 'stage': 'prefilter', 'decision': 'dropped', 'why': 'overlap %.2f with the better candidate %s' % sp})
        else:
            kept.append(c)
    # 3. round-robin across families, best score first within a family
    by = {}
    for c in kept:
        by.setdefault(c['family'], []).append(c)
    order = []
    while any(by.values()):
        for fam in P['families']:
            if by.get(fam):
                order.append(by[fam].pop(0))
    json.dump({'pool': pool, 'order': [c['key'] for c in order]}, open(f'{D}/stage2_round_s{seed}.json', 'w'), indent=1)
    cands = {c['key']: {'map': c['map'], 'target': 'EXTREME', 'facts': [], 'mechanic': json.load(open(f"{D}/seed_{c['core']}.json")).get('mechanic', ''),
                        'max_positions': json.load(open(f"{D}/seed_{c['core']}.json")).get('max_positions', 700)} for c in order}
    json.dump(cands, open(f'{D}/cands_s{seed}.json', 'w'), indent=1)
    # 4. reports and acceptance
    for c in order:
        if len(st['accepted']) >= ACCEPT_MAX or st['reports'] >= REPORTS_MAX:
            st['log'].append({'key': c['key'], 'stage': 'report', 'decision': 'not reached', 'why': 'stopping rule (10 accepted or 40 reports)'})
            continue
        accs = st['accepted']
        if any(a['core'] == c['core'] for a in accs):
            st['log'].append({'key': c['key'], 'stage': 'report', 'decision': 'skipped', 'why': 'a board of this core is already accepted'})
            continue
        if sum(a['family'] == c['family'] for a in accs) >= PER_FAMILY:
            st['log'].append({'key': c['key'], 'stage': 'report', 'decision': 'skipped', 'why': 'family cap (3) reached'})
            continue
        sa = max(((sim(c['map'], a['map']), a['key']) for a in accs), default=(0, ''))
        if sa[0] >= SIM_MAX:
            st['log'].append({'key': c['key'], 'stage': 'report', 'decision': 'skipped', 'why': 'overlap %.2f with accepted %s' % sa})
            continue
        st['reports'] += 1
        out = f"{D}/report_{c['key']}.json"
        godot(['res://tools/ta90_design.gd', '--', f'--file={D}/cands_s{seed}.json', f"--name={c['key']}", f'--out={out}'], out[:-5] + '.log')
        r = json.load(open(out))[c['key']]
        why = []
        if r.get('verdict') != 'HUMAN-REVIEW CANDIDATE':
            why += r.get('why_a', []) + r.get('why_b', []) or ['verdict ' + str(r.get('verdict'))]
        else:
            why += essential(r['B'], [m for m in cands[c['key']]['mechanic'].split(',') if m])
        if not why:
            fo = f"{D}/filler_{c['key']}.json"
            godot(['res://tools/xb90_filler.gd', '--', f'--file={D}/cands_s{seed}.json', f"--name={c['key']}", f'--out={fo}'], fo[:-5] + '.log')
            fl = json.load(open(fo))[c['key']]
            if int(fl.get('trivial_removals', 99)) > 0:
                why.append('filler: %d trivial removals %s' % (fl['trivial_removals'], fl.get('trivial')))
            c['filler'] = fl
        if why:
            st['log'].append({'key': c['key'], 'stage': 'report', 'decision': 'rejected', 'why': '; '.join(map(str, why))})
        else:
            c['report'] = out
            c['fingerprint'] = r['A']['fingerprint']
            st['accepted'].append(c)
            st['log'].append({'key': c['key'], 'stage': 'report', 'decision': 'ACCEPTED', 'why': ''})
        print(st['log'][-1], flush=True)
        json.dump(st, open(STATE, 'w'), indent=1)
    json.dump(st, open(STATE, 'w'), indent=1)
    print('accepted %d, reports %d' % (len(st['accepted']), st['reports']))


if __name__ == '__main__':
    main(int(sys.argv[2]))
