# Phase 15 collection: preserved state (development only)

See `docs/ta90_collection.md` for the reading of these files.

| File | What it is |
|---|---|
| `campaign_ref.json` | Measurements of campaign levels 100, 200, 274, 297 and 300 (`tools/ta90_campaign_ref.gd`; the level files are read only). |
| `cores_a.json`, `cores_b.json` | The hand-drawn idea cores (E1-E2, M1-M3; H1-H3, X1-X2). |
| `seed_*.json`, `resume_E2b.json` | The exact search inputs: map, frozen cells, target, facts, mechanics and weights. `seed_E2b` / `seed_E2c` / `seed_X1b` are the redrawn cores. |
| `search*.json` / `search*.log` | Each bounded search: its best board, beam, per-round log and why it stopped. |
| `cands_1.json`, `cands_2.json`, `report_*.json` | The candidates and their full A/B/C reports, the rejected ones included (E2b, X1 s1/s2, X1b s2, X2 s1). |
| `final_boards.json` / `final_report.json` | N4-N13 as integrated in `?ta90=1` (key N<k> = PUZZLE k), and their consolidated report. |

Re-run the final report:
```
godot --headless --path . --script res://tools/ta90_design.gd -- --file=data/dev/ta90_collection/final_boards.json
```
