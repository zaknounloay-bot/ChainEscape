# VERY HARD validation: three-board independent human test (development only)

`?vhval3=1`: a separate blind test for a second, experienced player. It contains exactly three previously tested boards, **copied unchanged**.

**Not shown to the tester:** this key, the original names, any earlier ratings, and any explanation. The page shows only neutral ids and the order played.

## Boards (key for the analyst)

| Test id | Group | Original | Source file | Fingerprint (sha256 of the map) |
|---|---|---|---|---|
| V1 | X | H2 | `data/dev/extreme7.json` | `e93b4cefaf38044e61d61c657e31e22290256eabdf412ec849ccd120d1de0092` |
| V2 | Y | T3 | `data/dev/extreme5.json` | `7faf35eeee4afcbe175f67df03a658b45c7da3622d75ce1cfe5a53192ecd8081` |
| V3 | Z | T5 | `data/dev/extreme5.json` | `3f8d71fdbc12434271a104ca5b3a4d25d80fb57f425aec345a665499f3c57e07` |

- **How the file is made:** `data/dev/vh_validation3.json` is written by `tools/vhval3_build.gd`. It copies each source record's `puzzle` (map, size, rules), mechanics, first level, fingerprint, canonical form and stored measurements.
- **What is left out:** titles, explanations, misleading moves and recipe names.
- **What is checked:** the copies match their sources exactly, and each fingerprint is recomputed from its map and matches the original (`VhVal3Check`). The source files themselves are checked unchanged by hash.
- **Ids:** V1-V3 come from a seeded shuffle, so they do not follow the source order.
- **Play order:** random per tester.

## What the page records

**After each puzzle:**
- difficulty (EASY / MEDIUM / HARD / VERY HARD / EXTREME);
- comparison with Campaign Level 300;
- enjoyment 1-5;
- achievement 1-5;
- fairness (YES / MOSTLY / NO);
- planning (YES / A LITTLE / NO);
- whether the combination of mechanics made it more interesting (YES / A LITTLE / NO).

**Automatically:**
- solve time, restarts, UNDO, SHOW A MOVE;
- blocked taps, give-ups;
- the time-stamped move sequence.

**At the end:** the hardest puzzle and why. **COPY RESULTS** gives the JSON.

**Tools:** the live VERY HARD set, UNDO x3, SHOW A MOVE x1, HAMMER x0. No difficulty label is shown during play.

**Storage:** the test has its own (`user://vh_validation3_state.json`, localStorage `chain_escape_vhval3_state`). Earlier test results are not touched.

**Campaign progress:** as on the other pilot pages, a board is only offered to a player whose campaign progress covers its mechanics:
- T5 from Level 76;
- T3 from Level 121;
- H2 (armor) from Level 151.

An experienced player who answers "all 300 levels" gets all three.

## Running it

- **Open:** `index.html?vhval3=1` from `build/dev_qa/chain_escape_dev_vhval3.zip`.
- **Timing on the phone itself:** `index.html?vhval3=1&bench=1`.
