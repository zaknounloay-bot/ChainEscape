"""Phase 32 (development only): generator job files for one round of the
Phase 31 method (docs/extreme90_phase32.md). Writes nothing but specs and a
job file; tools/extreme90_jobs30.py runs it.
  python3 tools/extreme90_gen32.py <worktree A> <godot> <round> <rng seed> <core> [<core> ...]
The method is Phase 31 arm A / AM1, unchanged: the generator of commit
c1ddc89 (Phase 27) in its own git worktree, --ops=v20, piece_free 13,
max_pieces 17, suffix_rate 0.30, patience 8, 12 minutes, batch 40, beam 5.
The repository's generator is not used and not changed. Every output board
then goes through the unchanged modern screen and full evaluation.
A core is a Phase 32 core (data/dev/extreme90_p32/cores/seed_<core>.json)
or a Phase 30 core (data/dev/extreme90_p30/seed_<core>.json)."""
import json, os, sys

WA, G = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
RND, SEED, CORES = sys.argv[3], int(sys.argv[4]), sys.argv[5:]
ROOT = os.path.abspath('.')
P32 = ROOT + '/data/dev/extreme90_p32'
OLD = {'piece_free': 13, 'max_pieces': 17, 'suffix_rate': 0.30}
jobs = []
os.makedirs(P32 + '/specs', exist_ok=True)
for c in CORES:
    src = '%s/cores/seed_%s.json' % (P32, c)
    if not os.path.exists(src):
        src = ROOT + '/data/dev/extreme90_p30/seed_%s.json' % c
    spec = json.load(open(src))
    spec.update(OLD)
    spec['phase32_method'] = 'Phase 31 arm A / AM1 (c1ddc89 generator, --ops=v20, Phase 25-27 parameters)'
    sp = '%s/specs/seed_%s.json' % (P32, c)
    json.dump(spec, open(sp, 'w'), indent=1)
    d = '%s/runs/%s_s%d' % (P32, c, SEED)
    os.makedirs(d, exist_ok=True)
    jobs.append({'name': 'gen_%s_s%d' % (c, SEED), 'dir': d, 'cpu': True,
                 'cmd': ['timeout', '1000', G, '--headless', '--path', WA, '--script', 'res://tools/ta90_search.gd', '--',
                         '--file=' + sp, '--minutes=12', '--batch=40', '--beam=5', '--patience=8',
                         '--seed=%d' % SEED, '--ops=v20', '--out=%s/run.json' % d]})
out = '%s/jobs_gen_%s.json' % (P32, RND)
json.dump(jobs, open(out, 'w'), indent=1)
print('%d generator jobs -> %s' % (len(jobs), out))
