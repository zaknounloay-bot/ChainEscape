"""Phase 30 (development only): a small job runner for generator runs and
evaluations (docs/extreme90_phase30.md, D). It replaces the Phase 29 shell
waits, one of which matched its own command line with pgrep and never
returned.
- Every job has its own directory (refused if it already holds a DONE marker,
  so a finished job is never re-run or overwritten), its own log, and a
  DONE file written only when the process has exited: {"exit": code,
  "seconds": s, "pid": pid, "cmd": [...]}.
- Processes are tracked by the Popen handle (PID + exit status), never by
  pgrep.
- "cpu": true = a generator run. "quiet": true = a screen or evaluation (it
  measures the 40 ms gates): never run beside a cpu job. "timing": true = an
  isolated re-measurement: runs alone on an otherwise idle runner.
  python3 tools/extreme90_jobs30.py jobs.json [max_parallel]
jobs.json: [{"name": "...", "dir": "...", "cmd": [...], "cpu": bool, "quiet": bool, "timing": bool}, ...]"""
import json, os, subprocess, sys, time

jobs = json.load(open(sys.argv[1]))
par = int(sys.argv[2]) if len(sys.argv) > 2 else 2
names = [j['name'] for j in jobs]
dirs = [os.path.abspath(j['dir']) for j in jobs]
assert len(set(names)) == len(names), 'duplicate job names'
assert len(set(dirs)) == len(dirs), 'two jobs share an output directory'
pending = [j for j in jobs if not os.path.exists(os.path.join(j['dir'], 'DONE'))]
for j in jobs:
    if j not in pending:
        print('SKIP %s (already DONE)' % j['name'], flush=True)
running = []  # (job, Popen, start, logfile)
while pending or running:
    for r in list(running):
        code = r[1].poll()
        if code is None:
            continue
        r[3].close()
        dt = round(time.time() - r[2], 1)
        json.dump({'exit': code, 'seconds': dt, 'pid': r[1].pid, 'cmd': r[0]['cmd']}, open(os.path.join(r[0]['dir'], 'DONE'), 'w'))
        print('DONE %s exit=%d %.0fs' % (r[0]['name'], code, dt), flush=True)
        running.remove(r)
    while pending:
        j = pending[0]
        if any(r[0].get('timing') for r in running) or len(running) >= par:
            break  # a timing job runs alone
        if j.get('timing') and running:
            break  # ... so it waits for an idle machine
        if j.get('quiet') and any(r[0].get('cpu') for r in running):
            break  # screens / evaluations never share the machine with a generator
        if j.get('cpu') and any(r[0].get('quiet') for r in running):
            break  # ... nor a generator with them
        os.makedirs(j['dir'], exist_ok=True)
        log = open(os.path.join(j['dir'], 'job.log'), 'w')
        p = subprocess.Popen(j['cmd'], stdout=log, stderr=subprocess.STDOUT)
        print('START %s pid=%d' % (j['name'], p.pid), flush=True)
        running.append((j, p, time.time(), log))
        pending.pop(0)
    time.sleep(2)
print('ALL DONE', flush=True)
