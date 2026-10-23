# Phase 14 design pipeline: preserved state (development only)

See `docs/ta90_design.md` §4-§6 for the reading of these files.

| File | What it is |
|---|---|
| `cores.json`, `core_14B2.json` | The hand-drawn idea cores. `core_14B2` is the redrawn 14B core; the first one was rejected. |
| `seed_*.json`, `resume*.json`, `restart_14B.json` | The exact inputs of each search: map, frozen cells, target, facts, mechanics and weights. |
| `search*.json` / `search*.log` | Each bounded search's best board, its beam, the per-round log and why it stopped. `search3_14B` was stopped by hand, so it has a log only. |
| `cand_*.json` / `report_cand_*.json` | Candidates and their full A/B/C design reports (`tools/ta90_design.gd`), including the ones not used (`14B_s4`: no endgame decision; `14B_s5`: 22.5% greedy shortcut; `14B_e7`: slower twin of `e6`; `14C`: superseded by `14C2`). |
| `final_boards.json` / `final_report.json` | N1-N3 as integrated in `?ta90=1`, and their final report. |

Re-run a report:
```
godot --headless --path . --script res://tools/ta90_design.gd -- --file=data/dev/ta90_search/final_boards.json
```
