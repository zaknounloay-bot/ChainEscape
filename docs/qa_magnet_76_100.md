# QA build: Magnet campaign (Levels 76–100)

This is a private build for the project owner to check the new Magnet levels on an iPhone. It is the **Web QA** export preset (`qa_build`). It has its own save, completely separate from the real game (`docs/qa_build_1_300.md`).

**The public Friend Test build is unchanged and not replaced.**

## Upload to itch.io (a separate, private page)

1. Create a **new** itch.io project, for example "Chain Escape QA Magnet". Keep it **Draft** or **Restricted**, and do not reuse the Friend Test page.
2. Set Kind of project to **HTML**, upload `ChainEscape_Web_QA_MAGNET_76_100.zip`, and tick **This file will be played in the browser**.
3. Set the viewport to **390 × 844** and tick **Mobile friendly** (orientation: portrait). Tick **Fullscreen button** and **SharedArrayBuffer support** if offered.
4. Save, then open the page on the iPhone in Safari.

## Checkpoint addresses

Add the parameter to the game frame's address. On itch.io, the simplest way is to open the game in full screen and add it to the `html-classic.itch.zone/...index.html` URL, or test the files from any static host.

| Address | Opens |
|---|---|
| `index.html?experiencelab=76&qareset=1` | **Level 76, fresh**: NEW MECHANIC card, then the finger lesson |
| `?experiencelab=79&qareset=1` | the last lesson level, then NEXT → **80** (the transition to judge) |
| `?experiencelab=80&qareset=1` | Level 80 (unchanged) |
| `?experiencelab=85&qareset=1` | breather |
| `?experiencelab=89&qareset=1` | then NEXT → **90** (unchanged) |
| `?experiencelab=97&qareset=1` | breather |
| `?experiencelab=98&qareset=1` | the hardest Magnet level |
| `?experiencelab=99&qareset=1` | then NEXT → **100** (era finale) |
| `?experiencelab=N` (no `qareset`) | resumes the stored session if N is the same checkpoint |

N can be any level from 2 to 300. A fresh session at N has Levels 1 to N−1 cleared and earlier lessons marked as seen. Level 76 itself is a first visit.

## What to look at

- **The 76 card and lesson.** Does the card make the rule clear? Does the finger lesson feel like *your* move? Does it end on the first pull?
- **The preview.** The dotted line and bracket show which block will be pulled. Is it readable on the phone?
- **The Hammer on a magnet.** It removes the magnet, nothing is pulled, and the message says so.
- **Undo after a pull.** Both the magnet and the pulled block go back.
- **SHOW A MOVE** on 95 and 98: it should respond without a noticeable wait.
- **Difficulty feel.** 76–79 are gentle, then 80 is a big step (unchanged level). Note where you stall. The same applies to 89 → 90 and 99 → 100.
- The debug panel (tap the level title 5 times) offers auto-solve for skipping a level. It acts on the QA save only.
