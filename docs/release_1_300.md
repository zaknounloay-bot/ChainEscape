# Chain Escape — production release of the frozen 300-level campaign

The complete approved campaign, Levels 1–300, released on the existing public itch.io page in place of the earlier Friend Test build.

## Campaign content (frozen)

Everything approved through real-iPhone QA:

- **Levels 1–300:** see `docs/freeze_1_300.md`.
  - The Magnet campaign: Levels 76–99, with 80 and 90 unchanged. See `docs/magnet_campaign.md`.
  - The four Magnet cleanups: 78, 93, 94 and 96.
- **Milestones:**
  - 100: "100 LEVELS ESCAPED!", then **MASTER!**
  - 200: "200 LEVELS ESCAPED!", then **GRAND MASTER!**
  - 300: "300 LEVELS ESCAPED!", then **LEGEND!**
- **Tutorials:** every mechanic introduction card and finger lesson. Magnet's is at Level 76.

## Release build

- **Export preset:** "Web Friend Test" (preset 1), feature `player_build`.
- **What players never get:** the debug panel (F1, the five-tap title gesture), auto-solve and every developer or QA page. That covers `?experiencelab`, `?openinglab`, `?twinsprototype`, `?mechlab`, `?friendbench`, `?vhtest` and `?sharetest`, including the QA session and its separate save.
- **Page script:** the share-test page script is not included.

## One-time fresh start (pre-launch decision)

The production release starts **every player fresh at Level 1**, including players of the earlier Friend Test build. They get the normal starting coins and boosters, zero scores and stars, and every mechanic introduction and tutorial.

This is done with a **versioned save namespace**, not by clearing storage:

| | Friend Test build (before) | Production release |
|---|---|---|
| Save file (plus `.bak`, `.tmp`, `.beacon`) | `user://progress.cfg` | `user://progress_r2.cfg` |
| localStorage mirror | `chain_escape_save` | `chain_escape_save_r2` |
| Save beacon | `chain_escape_beacon` | `chain_escape_beacon_r2` |
| Embed → own-tab progress transfer (page script) | reads `chain_escape_save` | reads `chain_escape_save_r2` |

**Where it's set:**
- `PlayerProgress.use_release_namespace()`, called at startup only in the player build (`GameManager._ready`, before the save loads).
- `tools/sync_web_head.py`, for preset 1's page script only.

**What stays as it was:**
- The earlier saves remain in the browser. They are never read and never deleted.
- Development, QA and lab builds keep their own save names.

**The release names are fixed from now on.** Later updates must keep them, so saved progress carries over across reloads and future releases. Changing them would reset every player again. That is a deliberate one-time decision, never a side effect of a deployment.

## Release validation

`tools/web_release_test.mjs <old Friend Test ZIP> <new production ZIP>` tests the ZIP files themselves. Both builds are served from the same URL in the same browser profile, as on itch.io:

1. A browser holding a real old Friend Test save (Level 151) gets the production build and starts fresh: PLAY, Level 1, 60 coins, 1 hint, 0 hammers, 0 stars. The old save stays untouched.
2. Level 1 is played by touch. The progress is saved under the release key and is still there after a reload and after closing and reopening the browser.
3. A release save at Level 75: Level 76 opens the Magnet card, then the Magnet lesson.

The full regression and the other release checks are listed in the release report and the tag message.
