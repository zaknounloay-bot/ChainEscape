"""Phase 31 (development only): the controlled generator comparison
(docs/extreme90_phase31.md, section C). Writes the per-arm seed specs and
the job file; it runs nothing itself (tools/extreme90_jobs30.py runs it).
  python3 tools/extreme90_exp31.py <worktree A> <worktree C> <godot>
Arms (identical hand cores = the Phase 30 seed files, identical RNG seeds =
the seed of the Phase 30 run they are paired with):
  A   the Phase 25-27 method: the generator of commit c1ddc89 (Phase 27,
      before the token guard / strict essentiality / spinners_max), --ops=v20,
      Phase 25-27 search parameters (piece_free 13, max_pieces 17,
      suffix_rate 0.30, patience 8).
  B   Phase 30 as EXECUTED (recorded, not re-run): the Phase 30 generator
      WITHOUT --ops=v20 (baseline operators; the protocol said v20),
      piece_free 15, max_pieces 19, suffix_rate 0.45, patience 12.
  C1  hybrid: the Phase 30 generator (every Phase 28-30 fix incl.
      core_essential) + --ops=v20 + the Phase 25-27 parameters.
  C2  ops-only control (4 cores): the Phase 30 generator + --ops=v20 with
      the Phase 30 parameters - C2 vs B isolates the operator change, C1 vs
      C2 the parameter change, A vs C1 the reliability fixes.
Every arm's output then goes through the SAME modern pipeline (token check,
bank overlap, design report with the 40 ms gates, strict essentiality,
filler, hint-follow: tools/extreme90_screen30.py)."""
import json, os, sys

WA, WC, G = [os.path.abspath(x) for x in sys.argv[1:4]]
ROOT = os.path.abspath('.')
P30 = ROOT + '/data/dev/extreme90_p30'
EXP = ROOT + '/data/dev/extreme90_p31/exp'
# core -> RNG seed of the paired Phase 30 run (data/dev/extreme90_p30/runs/)
CORES = {'T01r_PULLEDTRIGGER': 302, 'T03r_PULLTHEKEY': 302, 'T05r_ARMOREDLINK': 302, 'T27r_TRIGGERLINK': 302,
         'T48_BOOMERANGDOOR': 303, 'T57_TWOEFFECTS': 305, 'T59_AIMEDRAM': 305, 'T61_BOOMERANGRAM': 307}
C2_CORES = ['T01r_PULLEDTRIGGER', 'T27r_TRIGGERLINK', 'T59_AIMEDRAM', 'T61_BOOMERANGRAM']
OLD = {'piece_free': 13, 'max_pieces': 17, 'suffix_rate': 0.30}
ARMS = {'A': (WA, OLD, 8, list(CORES)), 'C1': (WC, OLD, 8, list(CORES)), 'C2': (WC, {}, 12, C2_CORES)}
jobs = []
for arm, (wt, over, pat, cores) in ARMS.items():
    os.makedirs('%s/specs/%s' % (EXP, arm), exist_ok=True)
    for c in cores:
        spec = json.load(open('%s/seed_%s.json' % (P30, c)))
        spec.update(over)
        spec['phase31_arm'] = arm
        sp = '%s/specs/%s/seed_%s.json' % (EXP, arm, c)
        json.dump(spec, open(sp, 'w'), indent=1)
        sd = CORES[c]
        d = '%s/runs/%s_%s_s%d' % (EXP, arm, c, sd)
        os.makedirs(d, exist_ok=True)
        jobs.append({'name': 'gen_%s_%s_s%d' % (arm, c, sd), 'dir': d, 'cpu': True,
                     'cmd': ['timeout', '1000', G, '--headless', '--path', wt, '--script', 'res://tools/ta90_search.gd', '--',
                             '--file=' + sp, '--minutes=12', '--batch=40', '--beam=5', '--patience=%d' % pat,
                             '--seed=%d' % sd, '--ops=v20', '--out=%s/run.json' % d]})
json.dump(jobs, open(EXP + '/jobs_gen.json', 'w'), indent=1)
print('%d generator jobs -> %s/jobs_gen.json' % (len(jobs), EXP))
