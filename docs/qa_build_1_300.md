# Chain Escape: private QA build (Levels 1–300)

The QA build is for the project owner. It opens any level from 1 to 300 directly and lets you play on from there. It reuses the existing Experience Lab QA jump, extended from Levels 2–200 to 2–300.

It plays the frozen production boards and uses its own save, completely separate from the real game. The public Friend Test build is unchanged and ignores every QA parameter.

## Builds

| Export preset | Feature | What it is |
|---|---|---|
| **Web Friend Test** (preset 1) | `player_build` | The public game: no debug panel and no developer pages. It ignores `?experiencelab`, `&qareset` and all other developer parameters. |
| **Web QA** (preset 2) | `qa_build` | Always a QA session. Without parameters it resumes the last QA session, or starts at Level 1. It never opens the normal save, Friend Challenge or the other developer pages. |
| **Web** (preset 0) | — | The developer build. `?experiencelab=N` behaves as in the QA build; without the parameter it is the normal game on the real save. |

To export the QA build:

```
godot --headless --path . --export-release "Web QA" build/web_qa/index.html
```

## Addresses

| Address | What happens |
|---|---|
| `index.html?experiencelab=N` (N = 2–300) | Opens Level N.<br>• **New checkpoint** (different from the stored session, or no QA save): starts a fresh QA session at N.<br>• **Same N again** (a Safari reload or an evicted tab): **resumes** the session where it was. |
| `index.html?experiencelab=N&qareset=1` | Restarts the session fresh at N. The `qareset` part is then removed from the address bar, so a later reload resumes instead of resetting again. |
| `index.html` (QA build only) | Resumes the stored QA session, or starts a fresh one at Level 1. |

Other parameters such as itch.io's `?v=…` can sit alongside these, in any order.

## A fresh session at Level N

A fresh session holds what a player arriving at N would have:
- Levels 1 to N-1 cleared, with 0 stars and score 0;
- the starting coins and starting boosters of a new save;
- no achievements and no collected reward blocks;
- the earlier Chapters complete;
- the earlier lessons and tips marked as seen. The "NEW MECHANIC" card of a mechanic introduced before N does not show again.

Level N itself plays as a first visit. Its lesson or hint, first clear, milestone, Chapter Complete, the Grand Master at 200 and its one-time bonus all behave normally, inside the QA save only.

NEXT continues through the campaign as normal, including 200 → 201. In the QA build, the debug panel's auto-solve (F1 then S, or tap the level title five times) acts on the QA session only.

## Isolation, even on the same browser origin

The QA session never reads or writes the normal game's storage. It has its own copies of everything the game stores:

| Data | Normal game | QA session |
|---|---|---|
| Save file (plus `.bak` and `.tmp`) | `progress.cfg` | `experience_lab_qa.cfg` |
| `localStorage` save mirror | `chain_escape_save` | `chain_escape_experiencelab_qa_save` |
| Save beacon | `chain_escape_beacon` | `chain_escape_experiencelab_qa_beacon` |
| Session diagnostics | `chain_escape_diag_last`, `chain_escape_session` | `chain_escape_qa_diag_last`, `chain_escape_qa_session` |
| Page crash log | `chain_escape_page_events` | `chain_escape_qa_page_events` (QA build) |

Friend Challenge and shared-challenge links never open in a QA session.

The QA save records the checkpoint it started from, as `[qa] origin=N`, which is how a reload knows to resume. The engine's GPU shader cache is shared by every build; it holds no player data.

## Tests

- **`tools/ExperienceLabQaCheck.tscn` (headless).** Run once per level:
  ```
  -- --experiencelab=N --qareset                 # fresh session: open, first visit, clear, NEXT to N+1
  -- --experiencelab=N --qaexpect=resume         # same N again: resumes at N+1 with N cleared
  -- --experiencelab=N --qaexpect=fresh          # new checkpoint / reset: a fresh session at N
  ```
  Each run also checks that the real save, the Lab and Opening Lab saves, the Lab log and the normal session diagnostics are byte-identical.
- **`tools/web_qa_build_test.mjs` (browser).** Runs the QA and Friend Test builds on one origin, at three iPhone sizes, and checks:
  - every checkpoint 50–275: a fresh session, clear, NEXT (200 → 201), and resume after a reload;
  - resume in a new tab; reset; the QA build without parameters;
  - every non-QA stored copy byte-identical after all QA play;
  - the Friend Test build continuing the owner's save and ignoring QA parameters;
  - audio unlocking on the first tap;
  - no page or console errors.
- **`tools/web_friend_build_test.mjs`** additionally checks `?experiencelab=250&qareset=1` and `?experiencelab=300` in the Friend Test build.
