"""Phase 30 (development only): the early screen with the Phase 29 hint-follow
check (docs/extreme90_phase30.md, D).
  python3 tools/extreme90_screen30.py <shortlist.json> <out dir> <godot>
1. tools/extreme90_screen28.py, unchanged (tokens, overlap, quick report with the
   40 ms gates, strict essentiality, filler).
2. For every PASS board: tools/ta90_hintfollow29.gd - the engine's own hint
   (Solver.recommend_move, what the page's touch solver follows) from the start
   position must reach an empty board. Three different failures are kept apart:
     "unsolvable"            - the screen's report says so (step 1);
     "hint loop"             - solvable, but following the hint never empties
                               the board (the R05 case in Phase 29);
     browser harness failure - only seen in the web test, never inferred here.
Writes <out dir>/screen30.json: screen28's result per board, PASS boards
re-labelled "hint loop" when step 2 fails."""
import json, os, subprocess, sys
SRC, OUT, G = sys.argv[1], sys.argv[2].rstrip('/'), sys.argv[3]
here = os.path.dirname(os.path.abspath(__file__))
subprocess.run([sys.executable, os.path.join(here, 'extreme90_screen28.py'), SRC, OUT, G], check=True)
res = json.load(open(OUT + '/screen.json'))
ok = [k for k, v in res.items() if v['result'] == 'PASS']
if ok:
    with open(OUT + '/hintfollow.log', 'w') as f:
        subprocess.run(['timeout', '1800', G, '--headless', '--path', '.', '--script', 'res://tools/ta90_hintfollow29.gd', '--',
                        '--boards=' + ','.join(ok), '--file=' + SRC], stdout=f, stderr=subprocess.STDOUT)
    log = open(OUT + '/hintfollow.log').read()
    for k in ok:
        passed = ('%s HINT-FOLLOW PASS' % k) in log
        res[k]['hint_follow'] = 'PASS' if passed else ('FAIL' if ('%s HINT-FOLLOW FAIL' % k) in log else 'NOT RUN')
        if not passed:
            res[k]['result'] = 'hint loop' if res[k]['hint_follow'] == 'FAIL' else 'hint-follow not run'
json.dump(res, open(OUT + '/screen30.json', 'w'), indent=1)
for k, v in res.items():
    print('%-22s %-14s %s' % (k, v['result'], v.get('hint_follow', '')))
print('SCREEN30: %d boards, %d PASS' % (len(res), sum(1 for v in res.values() if v['result'] == 'PASS')))
