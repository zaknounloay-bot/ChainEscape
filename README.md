# Chain Escape — v0.5.1

A one-handed portrait puzzle game built with **Godot 4.3 (GDScript)** for iOS, Android and mobile Web.

> Tap a block → it escapes in its arrow direction → space opens → more blocks can leave → chain the exits. Clear the board.

v0.5 makes progression feel much stronger. **Every 10 levels is a new Chapter** with its own:

- look (background, ambient decoration and particles, accents)
- music identity
- block material

The Chapters build toward **Silver and Gold reward blocks**, a **Chapter Complete** moment and a **Chapter chest** that upgrades with your stars. The puzzles themselves keep getting harder.

The feeling it aims for: *"I progressed, the game changed, and I want to see the next Chapter."*

**v0.5.1 is a stabilization release** (no new features). It fixes three problems testers reported:

- sessions ending unexpectedly
- saves / CONTINUE lost with levels relocked, especially on iPhone inside itch.io
- a score that seemed to drop between levels

See *v0.5.1 stabilization* below.

Everything from v0.4 is kept:

- 100 levels and the Master Level
- save / continue
- score, personal best, 3 stars and PERFECT
- hearts, limited Undo and hints
- spinners, locks and mystery
- coins, the Shop, the Hint and Hammer boosters, and the inventory
- the mobile Web audio unlock with Stream playback

Not included, on purpose: leaderboards, country ranking, accounts/login, backend, real-money purchases, ads, Daily Challenge and multiplayer.

---

## What's new in v0.5

| Area | Change |
|---|---|
| **Audio cleanup** | The verified iOS fix is kept unchanged: the page-level unlock inside the first gesture, and Stream playback on Web. The temporary diagnostics are removed: the test beep, `?audiotest`, `?audiodebug`, `?audiomode` and the `[CE-Audio]` logging. Only failures are logged now. |
| **Chapters** | Ten Chapters of 10 levels, defined in `data/chapters.json`. Each Chapter has its own background, accent palette, ambient decoration, particles, music and block material. It is recalculated on every level load and applied through every entry point. |
| **Music** | Ten Chapter music identities plus the Master theme: 5 harmonic families × 2 intensities, 88 → 126 BPM, with more layers as you go. Transitions are clean and sequential. The music is imported as QOA, so all 11 loops total 1.8 MB (v0.4's 6 loops were 5 MB). |
| **Block material** | Saturation, gloss, rim and glow grow Chapter by Chapter. Hues never change, and arrows are drawn last. |
| **Silver / Gold blocks** | Reward blocks that follow the normal rules. Silver pays **+5** (from Chapter 4) and Gold **+15** (from Chapter 6); both values are configurable. Each pays **once per save**, a Hammer never pays, and escaping one plays a premium burst and chime and flies "+N COINS" to the counter. **Diamond** is reserved in the data model. |
| **Chapter Complete** | Fires **once** per Chapter. Shows the Chapter's stars / 30, coins earned, PERFECT levels, Silver/Gold found, the chest, and a preview of the next Chapter in its own colors. |
| **Chapter chest** | One chest per Chapter that upgrades with stars: Bronze **20★**, Silver **25★**, Gold **30★** (the Gold tier adds a Hammer). Each tier is claimed once, from Level Select or the Chapter card. |
| **Level Select** | Grouped by Chapter: headers in the Chapter's colors, stars / 30, a complete tick, chest tiers, and gems on levels with uncollected Silver/Gold. |
| **Difficulty** | Levels 61–95 were tuned harder, so every Chapter's average difficulty now rises: 42.1 → 46.1 → 49.9 → 53.3 → 58.8 for Chapters 6–10. Before, Chapter 7 dipped to 37.5. The verifier enforces the rise. |
| **Save v3** | Adds completed Chapters, collected reward blocks, coins per Chapter and tips seen. v0.4 saves migrate without losing or double-paying anything. |
| **101+ architecture** | Chapters 11+ come from the data (`overflow.cycle`). The generator gets `chapter_plan(c)` (profile, difficulty band, reward frequency) and `classify(level)`. |

---

## v0.5.1 stabilization

No new gameplay, levels, rewards or progression. This release fixes the three problems real testers reported.

### 1. "Kicked out" around levels 45–58

**What was measured**

- **In-engine soak** (`tools/Soak.tscn`): 200 levels in one process (1 → 100 twice) through real touch input, the real NEXT button and every Chapter Complete card, with music and SFX on and a save after every step.
  - Nodes, objects and resources are **identical** between cycles, and there are **0 orphan nodes**.
  - Tweens and effect nodes settle back to 0.
  - Memory rises only in cycle 1, while each Chapter's music loads once (to 37.7 MB), and then **stays flat** through cycle 2.
  - The game itself doesn't leak.
- **Real browser** (`tools/web_persistence_test.mjs`): levels 1 → 70 continuously in one page. No reload, no page error, and the WebAssembly heap stays bounded (see *Test results*).
- **Known engine issue ruled out:** the iOS audio-worklet leak that reloads pages ([godot#107390](https://github.com/godotengine/godot/issues/107390), fixed by [#107948](https://github.com/godotengine/godot/pull/107948)) affects **Sample** playback in Godot **4.4+**. This build is 4.3 with Stream playback.

- **Browser heap (the finding):** Chromium heap snapshots over time, with forced garbage collection. The JS heap of the v0.5 build kept **3–5 MB per minute** of retained memory, even while the game sat idle on the title. An empty Godot 4.3 project stays flat. A heap diff put the growth in eight Emscripten WebGL object tables (+5.6 MB of array slots in 60 s).

**Root cause: a WebGL id leak from redrawing geometry every frame.**

- In Godot 4.3's Web runtime, every WebGL buffer, vertex array and similar object gets an id from `GL.counter++`, and Emscripten pads **every** GL table up to that counter. **Ids are never reused.**
- Any `CanvasItem` that redraws non-rectangle geometry (polygons, arcs, circles, anti-aliased lines, rounded `StyleBoxFlat`s) **every frame** makes the renderer create new GL buffers every frame. The tables grow without limit.
- v0.5 had many such per-frame redraws:
  - the animated Chapter background (a gradient polygon, decorations and particles)
  - every spinner block (the ring's idle wobble) and every Silver/Gold block (shine sweep and gem twinkle)
  - the hint ring, the escape ghosts, the reward ring
  - the tutorial finger
  - the title logo
- The later Chapters have more spinners, reward blocks and particles, so memory grew faster exactly there. After 30–60 minutes of play (around levels 45–58), iOS Safari's per-tab memory limit kills or reloads the page. On a GPU reset, Godot 4.3's Web runtime also shows a blocking `alert("WebGL context lost, please reload the page")` and **never recovers** (confirmed in the exported engine code).
- The page reload, together with the save loss below, looked like "kicked out and back to level 1".

**Fixes**

- **Draw once, animate transforms.** Everything that moves is now drawn once, as a child node, and animated only through `position`, `rotation`, `scale` and `modulate`, which create no GL objects. Geometry is redrawn only on a real state change (a Chapter change, a block turn, a lock opening, a mystery reveal).
  - `chapter_background.gd`: the gradient is rect bands; decorations and particles are draw-once shapes.
  - `block_view.gd`: the arrow, spinner ring, shine, gem twinkle, overlay, hint ring and tap flash are separate parts.
  - `escape_ghost.gd`, Board's reward ring, `tutorial_hint.gd` and the title logo work the same way.
  - **Result:** the retained JS heap is now flat (title and in-game idle, 60 s each: 56.6 → 56.6 MB, 56.7 → 56.8 MB), like the empty project.
- **No generated JavaScript at runtime.** Every game → page call (audio state, save mirror, diagnostics) is a function call on one cached object (`scripts/core/web_bridge.gd`), not `JavaScriptBridge.eval()` of a new source string.
- **WebGL context loss:** replaced the engine's dead-end alert with a short native note ("The browser reset the graphics. Reloading – your progress is saved.") and a reload. The progress is now safely stored (see 2), so the player lands on **CONTINUE – LEVEL X**.
- **Diagnostics that name the cause on a real phone:**
  - **Per level:** one `[Diag]` line per level transition, never per frame. It covers memory, objects, nodes, orphan nodes, resources, tweens, effect nodes, music and SFX players, the save sequence number, and on Web the WebAssembly and JS heap sizes.
  - **Page events:** `web/audio_unlock.js` records backgrounding, page hide, JS errors, engine aborts and context loss in localStorage.
  - **At the next launch** the game states how the previous session ended: *closed normally*, *page was in the background (browser discarded it)*, *GRAPHICS RESET*, *ENGINE ABORT: …*, *JS ERROR: …*, or *CRASHED WHILE VISIBLE* (no page-hide event, the signature of a browser web-process crash). It also gives the level, the time played and the last `[Diag]` line.
  - **On a phone:** tap the level title 5 times to open the debug panel, which shows all of it.

### 2. Save / Continue lost, levels relocked

**Root cause, from two Web behaviors confirmed in this environment and in the engine source**

- **The save reached browser storage late or not at all.** Godot 4.3 stores `user://` in IndexedDB through an **asynchronous** whole-filesystem sync that runs a frame or more after each write.
  - **Measured on the shipped v0.5:** closing the browser 300 ms after finishing a level kept the *previous* save (level 4 instead of 5), while after 3 s it was kept. A crash or tab close inside that window loses the newest progress.
  - **If IndexedDB can't be opened,** Godot only prints "IndexedDB not available" and silently runs from memory: everything is gone on reload.
- **Safari (every iPhone browser) makes storage in a cross-origin iframe ephemeral.** itch.io embeds HTML5 games in an iframe on another domain (itch.zone). WebKit partitions that iframe's storage and clears it when Safari closes ([WebKit tracking prevention](https://webkit.org/tracking-prevention/): third-party localStorage and IndexedDB are "partitioned… and also made ephemeral"; [godot#38498](https://github.com/godotengine/godot/issues/38498)). No save format can survive that inside the embed. It's a browser policy.

**Fixes: one authoritative model, `PlayerProgress` (save v4)**

- **Durable writes.** Every change saves immediately. Each save is written atomically (a `.tmp` file, verified, renamed, with the previous copy kept as `.bak`). On Web it is also mirrored **synchronously** into `localStorage` (`chain_escape_save`), so the copy exists the moment the save returns, before any IndexedDB sync.
- **Newest-copy load.** The loader reads **every** copy (main, `.bak`, `.tmp`, Web mirror) and keeps the intact one with the highest **save sequence number**. That handles an interrupted rename, a lagging IndexedDB, or a crash mid-write.
- **Never a silent reset.** An unreadable copy is kept aside (`progress.cfg.corrupt-<source>-<hash>`), the next-best copy is used, and if none parse, every intact entry is **salvaged** (multi-line values included). A blank start happens only when nothing at all is readable, and it is logged as `source=unreadable`.
- **Never relocked.** `highest_unlocked` is stored explicitly, only ever raised, and re-derived on load from completions and best scores. A partial save can't grey out levels.
- **Save points:** level start (last played), level completion (unlock, stars, best score, total, coins), every coin earn or spend, chest claims, booster use or purchase, reward blocks, settings, and leaving the app (focus out, pause, close request).
- **Safari embed:** when the game detects Safari/WebKit in a cross-origin iframe, the title shows a small native banner: *"Safari deletes progress saved inside this embedded page when it closes. Open the game in its own tab to keep your progress."* The **OPEN GAME** button opens the same build as a normal page, where saving works. The button is a real DOM tap, so it is never popup-blocked. The banner never appears where saving works, and it also warns when storage is blocked entirely (for example private browsing).
- `navigator.storage.persist()` is requested, which makes browsers less likely to evict saves.
- **Logging:** `[Save] load: source=mirror version=4 seq=13 last_played=5 … issues=[copies: file#12 bak#11 mirror#13]` and `[Save] write #14: … file=ok mirror=ok`.

**Save model (v4), everything in `scripts/core/player_progress.gd`:**

| Field | Meaning |
|---|---|
| `meta/version`, `meta/seq`, `meta/saved_unix` | format version, save sequence number (+1 per write), timestamp |
| `progress/current_level` | last played level (the CONTINUE target) |
| `progress/last_completed_level` | the last level finished (any clear) |
| `progress/highest_completed` | furthest level ever completed |
| `progress/highest_unlocked` | every level up to this is playable (never lowered) |
| `progress/total_score` | stored copy of the Total Score (cross-checked on load) |
| `[scores]`, `[stars]`, `progress/perfect_levels` | best score and best stars per level, PERFECT levels |
| `economy/coins`, `economy/inventory`, `economy/claimed_chests` | coins, boosters, chest tiers |
| `[chapters]` | completed Chapters, collected Silver/Gold blocks, coins per Chapter, tips seen |
| `[settings]` | Music, Sound Effects, Vibration |

Migration: v1 (v0.3) → v2 (v0.4) → v3 (v0.5) → v4 happens automatically, keeping everything. Unknown keys are preserved.

### 3. Score "dropped" from 8,200 to 6,000

**Root cause.** The level-complete card showed one big unlabeled number: *that level's* score. Level 12 might score 8,200 and level 13 6,000, so moving on *looked* like losing points. There was no running total anywhere.

**Score model.** Every number now says what it is:

| Name | Where | Rule |
|---|---|---|
| **LEVEL SCORE** | level card (big number) | this run of this level |
| **LEVEL BEST** / **NEW BEST!** | level card | best score ever on this level; never goes down |
| **TOTAL SCORE** | level card, title, Level Select | **sum of the best score of every completed level**. It only grows: a first clear adds the level's score, a better replay adds the improvement ("+800"), and a worse replay, a repeat or moving to the next level changes nothing. |
| CHAPTER SCORE | Chapter Complete card | sum of the Chapter's best scores |

There is no separate "session score". Replays can't farm Total Score, because it counts each level's best once.

### How to test on itch.io and on phones

**Upload**

- Export with the **Web** preset (`build/web/`: `index.html`, `.js`, `.wasm`, `.pck`, `.audio.worklet.js`), zip the folder contents, and upload as an HTML game. Leave *SharedArrayBuffer support* off; the build is single-threaded.
- Recommended itch settings: *Mobile friendly*, *Fullscreen button*.

**Where saving works**

| Where it runs | Saves survive… |
|---|---|
| Chrome / Edge / Firefox / Android, embedded on itch.io | reload, closing the tab, closing the browser, sleep/wake (storage is partitioned per site, but persistent) |
| **Safari / any iPhone browser, embedded on itch.io** | reload and sleep/wake only. **Closing Safari clears the embed's storage** (browser policy). The title shows a banner with **OPEN GAME**, which opens the game in its own tab, where everything persists. |
| Any browser, game opened in its own tab (the OPEN GAME button, or the itch iframe URL opened directly) | everything: reload, closing the tab or browser, returning later |
| Private / incognito browsing | the current session only (the title warns) |

**Manual checklist (iPhone Safari and Android Chrome)**

1. **A:** Open the itch page and play to Level 12. Close the browser app completely, then reopen the page.
   - Chrome: expect **CONTINUE – LEVEL 12**.
   - Safari embed: expect the banner. Tap **OPEN GAME**, play to Level 12 in that tab, close Safari, reopen that tab, and expect CONTINUE – LEVEL 12.
2. **B:** Play to Level 45, close the tab and reopen. Level Select must show 1–45 unlocked and 46+ locked.
3. **C:** Note your coins, stars and boosters, reload, and compare. They must be identical.
4. **D:** Note the **TOTAL SCORE** on the title. Complete another level. The card's TOTAL SCORE must be equal or higher, and never lower.
5. **E / F:** Play 40 → 70 in one sitting, including the Chapter changes. If the game ever reloads or freezes, reopen it, tap the level title **5 times** to open the debug panel, and read the lines under the buttons:
   - *Previous session:* how the last session ended (GRAPHICS RESET / CRASHED WHILE VISIBLE / page was in the background / ENGINE ABORT / JS ERROR / closed normally), at which level and after how long, and the last `[Diag]` line (memory and resource counts)
   - *Save:* where the save loaded from (`file`, `mirror`, `bak` …), its sequence number, last played / highest completed / highest unlocked, the total score and coins
   - *Storage:* whether this browser context can keep data
6. **Mobile audio:** the first tap still starts the music; Chapter changes fade the music.

A screenshot of the debug panel text is enough to diagnose a real-phone failure. On desktop, the same lines are in the browser console (`[Diag]`, `[Save]`).

## Save / Continue

`scripts/core/player_progress.gd` is the single authoritative progress model (save **v4**). It is saved to `user://progress.cfg`, which is IndexedDB on the Web, plus a synchronous `localStorage` mirror there.

**What is saved:**

- the last played level (the CONTINUE target), the last completed level, the highest completed level and the **highest unlocked level** (explicit, never lowered)
- stars and best score per level, PERFECT levels, and the Total Score (a cross-checked copy)
- coin balance and booster inventory
- claimed chest tiers and achievements (for example `master`)
- completed Chapters, collected Silver/Gold blocks (`"level:block"`), coins earned per Chapter, and one-time tips seen
- Music, Sound Effects and Vibration settings
- the save sequence number and timestamp

**Launch:**

- A returning player sees **CONTINUE – LEVEL X** with the Chapter, Total Score, stars and coins, plus **LEVEL SELECT**.
- A new player sees **PLAY**.
- The last played level is already loaded behind the title, so continuing is instant.

**Robustness** (details in *v0.5.1 stabilization*):

- **Atomic and durable:** a verified `.tmp` file is renamed over the main file, the previous copy is kept as `.bak`, and on the Web a synchronous `localStorage` mirror is written too.
- **Newest-copy load:** every copy is read, and the intact one with the highest save sequence number wins.
- **No silent reset:** an unreadable copy is quarantined, the next copy is used, and failing that, intact entries are salvaged. Unlocks are re-derived and never lowered.
- **Version-aware:** `_migrate()` upgrades v1 → v2 → v3 → v4 in place. Unknown keys are preserved.

## Chapters

Every 10 levels is a Chapter. The mapping is `Chapters.chapter_of(n) = (n − 1) / 10 + 1`, so it has no upper bound: Chapter 11 = 101–110, Chapter 12 = 111–120, and so on.

| Ch | Levels | Name | Look | Particles | Music | Block material |
|---|---|---|---|---|---|---|
| 1 | 1–10 | First Light | soft lilac, floating bubbles, orange accent | motes | c01 · light, welcoming · 88 BPM | matte |
| 2 | 11–20 | Sunny Meadow | fresh mint, tumbling confetti, pink accent | petals | c02 · playful · 100 | light gloss |
| 3 | 21–30 | Deep Current | calm blues, wave arcs | rising bubbles | c03 · focused · 96 | gloss + thin rim |
| 4 | 31–40 | Ember Ridge | warm coral, drifting triangles | embers | c04 · more rhythmic · 108 | gloss + rim |
| 5 | 41–50 | Twilight Grid | indigo dusk, tactical grid nodes, amber accent | dust | c05 · strategic tension · 100 | + first glow |
| 6 | 51–60 | Midnight Tide | deep navy, concentric rings, cyan accent | glints | c06 · deeper, serious · 94 | stronger glow |
| 7 | 61–70 | Neon Night | dark indigo, neon lines, cyan/magenta | sparks | c07 · energetic · 118 | neon glow |
| 8 | 71–80 | Crimson Circuit | dark crimson, circuit traces, orange accent | pulses | c08 · advanced · 122 | bright rim |
| 9 | 81–90 | Storm Summit | storm slate, aurora ribbons, violet accent | snow | c09 · intense · 126 | strong rim + glow |
| 10 | 91–100 | Golden Summit | deep teal and gold, twinkling stars | gold dust | c10 · master, premium · 112 | gold edge, full finish |
| ★ | 100 | Master Level | black and gold, slow golden rays | gold dust | master · the finale · 84 | gold edge, maximum |

The Chapters get gradually darker and richer. Chapters 1–4 are light, 5 is dusk and 6–10 are dark.

**Data-driven.** Every color, decoration, particle type, music id and block style lives in `data/chapters.json`. `scripts/core/chapters.gd` parses it, and no UI code contains a theme. Chapters past the list use `"overflow": {"cycle": [3, …, 10]}`: Chapter 11 is "Deep Current II", Chapter 19 is "Deep Current III", and so on. Adding a hand-made Chapter 11 means adding one entry to the list.

**Readability rules** (enforced by a unit test for every theme):

- title text vs. background: contrast ratio ≥ 4.5
- soft text: ≥ 2.6
- every block color vs. the board: CIE ΔE ≥ 35
- every arrow vs. its block: ≥ 2.0

Block hues and arrows never change, and the ambient layers stay faint (alpha 0.05–0.35).

**How a Chapter is applied** (no stale visuals):

- **Recalculated on every level load.** `GameManager.start_level()` is the single path used by NEXT LEVEL, Level Select, Continue, Replay, Restart, debug jumps and relaunch. It calls `_apply_chapter_theme(n)`, which re-applies **every** Chapter surface unconditionally:
  - background gradient, decoration and particles (`ChapterBackground`)
  - board and slot tint
  - block material (`Palette.block_style`, re-applied to every block view)
  - HUD text and accent colors (progress bar, NEXT and CONTINUE buttons, coin pill, chain text)
  - celebration particles
  - the music theme
- **No leftovers:** the background cross-fade starts from what is on screen and ends by snapping to the exact target. A settle guard snaps even if a fade is interrupted. `ChapterBackground.is_settled()` reports it.
- **Entering a Chapter** shows a "CHAPTER 4 · EMBER RIDGE" banner and plays a short chime. The HUD line reads `LEVEL NAME · CHAPTER 4 · 5/10`.
- **Debug:** debug builds print one line per load, for example `[Chapter] level=41 chapter=5 theme=Twilight Grid (id 5, prev 4) music=c05  <- transition`. `GameManager.chapter_state()` returns what is actually applied, and the tests use it.

## Music progression

`tools/generate_music.py` renders the loops from one shared engine (pad, arpeggio, bass, drums and optional layers). Instead of 10 unrelated songs, there are **five harmonic families**, each rendered twice at rising intensity. The second Chapter of a family keeps the harmony and adds tempo, percussion and layers:

| Family | Chapter | Feel | BPM | What changes |
|---|---|---|---|---|
| A (C maj7) | c01 | light, welcoming | 88 | soft pad, gentle arpeggio |
| | c02 | playful | 100 | bouncy bass, syncopated arpeggio, light claps |
| B (A minor) | c03 | focused | 96 | steady arpeggio, soft 16th hats |
| | c04 | more rhythmic | 108 | four-on-the-floor, claps, eighth-note bass |
| C (D minor) | c05 | strategic tension | 100 | suspended chords, bell motif, pulse bass |
| | c06 | deeper, serious | 94 | lower register, long pad, sub bass, deep kick |
| D (E minor) | c07 | energetic | 118 | 16th arpeggio, claps, bright timbre |
| | c08 | advanced | 122 | + counter-melody lead, octave bass |
| E (B minor) | c09 | intense | 126 | 16th bass, snare fills, double kick |
| | c10 | master, premium | 112 | majestic pad, bells, shimmer and choir layers |
| M (C minor) | master | the finale (Level 100) | 84 | bells, choir pad, deep drums, shimmer |

- **Seamless loops:** each is rendered into a circular buffer with a WAV loop point.
- **Compression:** all are imported as **QOA** (`compress/mode=2` in the `.import` files), which is decoded by Godot's mixer and so works with Web Stream playback. The 11 loops total 1.8 MB, and the Web `.pck` went from 5.3 MB to 2.1 MB.
- **Clean transitions** (`AudioManager.set_music_theme`): the old theme fades out over 0.8 s, and the new one starts 0.55 s later and fades in over 1.1 s. Only a short tail overlaps, never two full themes. Rapid changes cut cleanly, and the playtest checks that exactly one player remains afterwards.
- **Ducking:** music ducks under the level-complete, PERFECT, Chapter Complete and Master jingles.
- **Settings:** Music, Sound Effects and Vibration are saved and restored, and Music and SFX use separate buses.
- **Real tracks:** to replace a theme, drop `music_<id>.ogg` into `assets/audio/` and point the Chapter's `"music"` at it.

**Mobile Web audio (iOS Safari, verified on device).** The v0.4.x fix is kept exactly. `web/audio_unlock.js` is inlined into the page head through the Web export preset:

1. Before the engine loads, it wraps `AudioContext` so it can see the engine's context.
2. On every `touchend` / `pointerup` / `mouseup` / `click` / `keydown` until audio runs, and synchronously inside the gesture, it:
   - sets `navigator.audioSession.type = "playback"` (iOS 17+), so the silent switch doesn't mute the game
   - plays a silent `<audio>` once on older iOS
   - calls `resume()` on a suspended or interrupted context and starts a one-frame silent buffer
   - A failed tap is retried on the next one.
3. `AudioManager` polls the context. Only when it is **running** after a real gesture does it start the music (if ON) and allow SFX (if ON). This happens once, and music is never restarted.
4. The Web playback type is **Stream** (`audio/general/default_playback_type.web = Stream`). The export is single-threaded, which is itch.io-compatible and needs no special headers.

v0.5 removed the temporary diagnostics. Only failures are logged: `console.warn` from the page script, plus one `push_warning` if the browser keeps audio blocked after 3 taps. The page still publishes `window.chainEscapeAudio` (unlocked / musicPlaying / musicPos / theme / settings / context / sfxPlayed) and `window.ceAudio.state()/info()` for the automated browser test. These are state only, with no logging.

After editing `web/audio_unlock.js`, run `python3 tools/sync_web_head.py`, then re-export.

**Quick iPhone re-check:** serve `build/web/` over HTTPS or LAN, open it in Safari and tap PLAY. The music should start, and a block tap should click. Repeat with the silent switch on, and after locking and unlocking the phone.

## Silver and Gold blocks

Special **reward blocks** that follow the normal puzzle rules. They are still their color (locks depend on it), keep their arrow, and can be spinners or locked.

| Rarity | Map token | Coins | First appears | In the campaign |
|---|---|---|---|---|
| Silver | `$S` | **+5** | Chapter 4 (level 32) | 39 blocks: 5–6 levels in each Chapter from 4 on |
| Gold | `$G` | **+15** | Chapter 6 (level 51) | 18 blocks: 2–4 levels in each Chapter from 6 on, including 2 on the Master Level |
| Diamond | `$D` | (40) | reserved | **disabled**; the data model, token and config exist, and no level uses it |

- **Configurable:** coins, the first level and the on/off switch are in `data/economy.json` under `reward_blocks`.
- **Look:** a thick metallic frame, a gem in the top-left corner (the padlock uses top-right) and a halo in the metal's color. A light sweep crosses the face every few seconds, more often on Gold. Everything sits around the edge, and the arrow is always drawn on top.
- **Escape:** metal sparkles, an expanding ring and a short chime (Gold is richer). "+5 COINS" / "+15 COINS" pops at the block and flies into the coin counter in about 0.8 s. Nothing pauses, and input is never blocked.
- **First encounter:** a single line, "Silver Block: let it escape for +5 coins" (and the same for Gold), shown once per save.
- **Placement:** `tools/place_reward_blocks.gd` places them deterministically from the Chapter plan. Gold goes on a block that is cleared late in a correct solution, so earning it takes planning. Silver goes on one from the second half. Hidden blocks and the final block are never chosen.

### Reward rules (anti-farming)

| Situation | Result |
|---|---|
| Escaped by normal play, first time | Pays its coins **immediately** and is saved at once (`reward_blocks` in the save) |
| Undo, then the same block escapes again | Nothing. It comes back drawn "spent" (a faint frame, no gem or halo). |
| Restart / Replay / out of hearts / relaunch | Nothing. The block stays "spent" for this save. |
| **Hammer** smashes it | **No coins** ("Smashed – Silver/Gold coins only pay when a block escapes"). It is not marked collected, so it can still be earned by play later. |
| Level card | Counts reward coins in the attempt total ("Gold +15"). They are never paid twice. |
| Level Select | A small gem on each level that still has an uncollected reward block |

## Chapter completion

- **When:** the first time **every level of a Chapter** is cleared. Usually that's the 10th level, but finishing out of order works too. The moment is recorded in `completed_chapters` and **never fires twice**, including after replays and relaunches.
- **Flow:** the level card's primary button changes to **CONTINUE**, which opens the **Chapter Complete** card. That card's CONTINUE starts the next Chapter, with its banner and new music. If the player replays instead, the card waits for the next NEXT in that Chapter.
- **The card shows:**
  - "CHAPTER 4 / COMPLETE! / EMBER RIDGE"
  - the Chapter's stars as ★ n / 30 with a bar
  - coins earned in the Chapter, PERFECT levels, and Silver/Gold found
  - the Chapter chest, whose tiers can be claimed right there
  - an **UP NEXT** panel in the next Chapter's own colors, with its title and what's new (for example "NEW: Silver Blocks", "NEW: Gold Blocks", "NEW: the Master Level")
- **Bonus:** +50 coins, once, per Chapter.
- **Level 100** ends Chapter 10: the Master celebration comes first, then the Chapter 10 card ("More Chapters are coming").

## Chapter rewards (Chapter chest)

Each Chapter has 30 possible stars and **one chest that upgrades** with them. The values are configurable in `data/economy.json` under `chest_tiers`:

| Tier | Stars | Reward |
|---|---|---|
| Bronze | 20★ | 25 coins |
| Silver | 25★ | 50 coins |
| Gold | 30★ | 90 coins + 1 Hammer |

- Each tier is claimed once, from Level Select or the Chapter card. `Economy.claim_chest()` refuses anything already claimed.
- The ids are `g<chapter-1>_t<tier>`. These are the same ids the v0.4 chests used, since v0.4 chests were already per 10 levels, so claims carry over.
- The 25★ and 30★ tiers need near-perfect play. That, plus the Silver/Gold gems in Level Select, gives a reason to replay levels with missing stars.

## Coin economy

`scripts/core/economy.gd` reads every value from **`data/economy.json`**. These are prototype values, meant to be tuned.

| Reward | Coins |
|---|---|
| First clear of a level | 3 × Chapter multiplier |
| Each star earned for the first time | 4 × Chapter multiplier |
| First PERFECT on a level | 10 × Chapter multiplier |
| Silver / Gold block (escaped by play, once each) | 5 / 15 |
| Chapter complete (once) | 50 |
| Chapter chest (once per tier) | 25 / 50 / 90 + Hammer |
| Clearing the Master Level | 300 (once, plus the `master` achievement) |
| Starting grant | 60 coins + 1 Hint booster |

- **Chapter multiplier:** 1.0, 1.1, 1.2, 1.35, 1.5, 1.6, 1.75, 1.85, 2.0, 2.2 for Chapters 1–10. Past that it rises 0.1 per Chapter, capped at 3.0.
- **Only improvements pay.** Replaying without a new star or first PERFECT pays nothing, and every one-time reward (reward blocks, Chapter bonus, chest tiers, Master) is saved the moment it pays. Nothing can be farmed.
- **Available in the campaign:** 195 coins from Silver blocks, 270 from Gold, 500 from Chapter bonuses, and up to 1,650 from chests.
- The coin pill counts up, and tapping it opens the Shop. The level card shows "+N COINS (Clear · +2 stars · Gold +15 …)".
- **Coins can't be bought** with real money.
- **Coins per Chapter:** `PlayerProgress.add_coins(amount, chapter)` counts coins *earned* per Chapter for the Chapter card. Spending isn't counted.

## Shop and boosters

- **Shop:** tap the coin pill (or the Hammer button with none owned). Prices are in `data/economy.json`: Hint **30**, Hammer **60**. A purchase fails harmlessly if you can't afford it.
- **Hint booster:** uses the existing Hint logic (one legal move that keeps the level solvable, highlighted, never played for you). Free hints are used first, then boosters; the badge shows `free+owned`. A booster hint costs −250 points, loses ★★ and PERFECT.
- **Hammer booster:** tap HAMMER, then a block.
  - It only works if the level stays solvable (`GameManager.is_hammer_safe`). A rejected smash doesn't use the Hammer.
  - Limit 1 per level, −400 points, no ★★ and no PERFECT.
  - **v0.5 rule:** a Hammer never collects a Silver/Gold reward.
- **Inventory:** boosters are saved, and their counts are shown on the buttons. The Gold chest tier adds a Hammer.

## Advanced spinner rules

| Rule | Token | Turns (1st, 2nd, 3rd, …) | Indicator | Introduced |
|---|---|---|---|---|
| Clockwise ↻ | `@` | ↻ ↻ ↻ … | ring arrows point clockwise | Level 9 |
| Counter-clockwise ↺ | `@-` | ↺ ↺ ↺ … | ring arrows point counter-clockwise | Level 31 |
| Alternating | `@~` | ↻ ↺ ↻ ↺ … | 2-dot strip (● ○); the next turn's dot is bigger | Level 35 |
| Pattern | `@*` | ↻ ↻ ↺, repeat | 3-dot strip (● ● ○); the next turn's dot is bigger | Level 52 |

- **Never random.** A spinner's next turn depends only on its rule and how many turns it has made (`BlockData.turn_is_cw(rule, step)`).
- The ring's arrowheads always point the way the **next** turn will go, and Undo restores the step counter exactly.
- The solver includes the sequence position in its memo key, and the unit tests check that the model and solver agree turn by turn.
- Mystery arrows are never on spinners, so a spinner's rule is always visible.

## 100-level progression

Cosmetic progression never replaces puzzle progression. Every Chapter's **average difficulty** must be at least 2.0 above the previous Chapter's, and the verifier fails otherwise:

| Chapter | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Avg difficulty | 4.7 | 11.1 | 18.2 | 27.4 | 32.4 | 42.1 | **46.1** | **49.9** | **53.3** | **58.8** |
| v0.4 | 4.7 | 11.1 | 18.2 | 27.4 | 32.4 | 42.1 | 37.5 | 46.5 | 48.1 | 56.5 |

In v0.4, Chapter 7 (levels 61–70, the CCW/ALT introduction) was *easier* than Chapter 6, and Chapter 9 barely beat Chapter 8.

v0.5 **tuned 34 levels (61–78, 80–95; ▲ in the table)** with `tools/strengthen_levels.gd`:

- **How it tunes:** it hill-climbs each level toward a target using the generator's own mutations: turning an arrow, the spinner trap motif, toggling a spinner, changing a spinner rule within the kinds the level already uses, moving a block, or adding up to 3 blocks.
- **What's kept:** each level keeps its size, name, mechanics and rule identity. The CCW and ALT introduction levels 61 and 63 stay the gentlest of their Chapter.
- **What every step must pass:** solvable; ≤ 2 starting moves; depth ≥ 8; ≥ 4 decision points; all four directions, none on more than 45% of blocks.
- **What the final version must pass:** every mechanic essential or impactful, mystery provably fair, and not similar to another board.

The result: 61–100 now use **fewer obvious first moves** (always ≤ 2), **deeper ordering** (depth 10–25), **more decision points** (11–21), **mixed spinner rules with lock dependencies**, and fair mystery information every 10th level. Level 100 stays the hardest (67.7).

| Levels | Chapter | What makes it harder |
|---|---|---|
| 1–10 | 1 · First Light | tap, blocking, chains; spinners (9); mystery (10) |
| 11–20 | 2 · Sunny Meadow | order and traps; locks (16); lock depth |
| 21–30 | 3 · Deep Current | spinner traps + lock-only planning boards |
| 31–40 | 4 · Ember Ridge | CCW (31) and ALT (35) spinners, spinner + lock; **Silver blocks** |
| 41–50 | 5 · Twilight Grid | spinner + lock combinations, key rings |
| 51–60 | 6 · Midnight Tide | PATTERN spinner (52), 6×7 boards; **Gold blocks** |
| 61–70 | 7 · Neon Night | mixed CCW/ALT with locks, a trap at the start, 2 starting moves |
| 71–80 | 8 · Crimson Circuit | ALT + PATTERN in one puzzle, 3 locks, 12–16 decision points |
| 81–90 | 9 · Storm Summit | 7×7 boards, all four spinner rules together, deep dependency chains |
| 91–100 | 10 · Golden Summit | 14–21 decision points, depth up to 25, difficulty 55–68 |

**Level 100 – The Master** keeps its unique treatment:

- the black-and-gold theme with golden rays and gold dust
- its own music (bells, choir pad and a shimmer layer)
- a crown in Level Select
- "MASTER LEVEL" in place of "LEVEL 100"
- a 7×7 board with 7 spinners (4 rules), 3 locks and 3 fair hidden arrows
- **2 Gold and 1 Silver** blocks, placed on blocks cleared late in a correct solution, so no luck is involved

On completion it gives a quadruple burst, a "MASTER!" stamp, the Master jingle, +300 coins and the `master` achievement, then the Chapter 10 card.

**All 100 levels** (✦ = Mystery, 👑 = Master, ▲ = tuned harder in v0.5; from `tools/verify_levels.gd`):

| # | Ch | Name | Size | Blocks | Spinners (rules) | Locks | Hidden | Start | Traps | Decisions | Depth | Diff | Reward |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | First Steps | 3×3 | 3 | 0 | 0 | 0 | 3 | 0 | 0 | 1 | 1.5 |  |
| 2 | 1 | In The Way | 3×3 | 3 | 0 | 0 | 0 | 1 | 0 | 0 | 2 | 3.1 |  |
| 3 | 1 | One After Another | 3×3 | 3 | 0 | 0 | 0 | 1 | 0 | 0 | 3 | 3.8 |  |
| 4 | 1 | Around The Corner | 4×4 | 4 | 0 | 0 | 0 | 1 | 0 | 0 | 4 | 4.5 |  |
| 5 | 1 | Two Ways In | 4×4 | 6 | 0 | 0 | 0 | 2 | 0 | 0 | 3 | 3.7 |  |
| 6 | 1 | Rush Hour | 5×5 | 15 | 0 | 0 | 0 | 6 | 0 | 0 | 5 | 5.2 |  |
| 7 | 1 | Crossroads | 5×5 | 9 | 0 | 0 | 0 | 2 | 0 | 0 | 7 | 6.5 |  |
| 8 | 1 | Look Closer | 5×5 | 13 | 0 | 0 | 0 | 1 | 0 | 0 | 9 | 8.8 |  |
| 9 | 1 | Spinner | 4×4 | 4 | 1 | 0 | 0 | 1 | 0 | 0 | 3 | 4.4 |  |
| 10 ✦ | 1 | Hidden Arrow | 4×4 | 5 | 0 | 0 | 1 | 1 | 0 | 0 | 4 | 5.2 |  |
| 11 | 2 | Order Matters | 4×4 | 5 | 1 | 0 | 0 | 2 | 1 | 1 | 4 | 7.6 |  |
| 12 | 2 | Quarter Turn | 4×4 | 9 | 1 | 0 | 0 | 2 | 0 | 2 | 5 | 9.7 |  |
| 13 | 2 | Wrong Way | 4×4 | 11 | 1 | 0 | 0 | 3 | 1 | 2 | 8 | 12.2 |  |
| 14 | 2 | Pinwheel | 5×5 | 13 | 2 | 0 | 0 | 1 | 0 | 1 | 10 | 12.3 |  |
| 15 | 2 | Tight Squeeze | 4×4 | 10 | 1 | 0 | 0 | 3 | 1 | 3 | 7 | 13.4 |  |
| 16 | 2 | Locked | 4×4 | 5 | 0 | 1 | 0 | 2 | 0 | 0 | 4 | 5.0 |  |
| 17 | 2 | Second Thoughts | 5×5 | 14 | 2 | 0 | 0 | 2 | 0 | 2 | 11 | 14.5 |  |
| 18 | 2 | Key Colors | 4×4 | 9 | 0 | 2 | 0 | 1 | 0 | 0 | 7 | 8.7 |  |
| 19 | 2 | Crosswind | 5×5 | 15 | 2 | 0 | 0 | 3 | 0 | 4 | 11 | 17.9 |  |
| 20 ✦ | 2 | Fog | 5×5 | 11 | 0 | 0 | 3 | 1 | 0 | 0 | 8 | 9.8 |  |
| 21 | 3 | Knots | 5×5 | 13 | 2 | 0 | 0 | 3 | 0 | 6 | 9 | 20.2 |  |
| 22 | 3 | Padlocks | 5×5 | 11 | 0 | 2 | 0 | 1 | 0 | 0 | 11 | 11.3 |  |
| 23 | 3 | Clockwork | 5×5 | 16 | 3 | 0 | 0 | 3 | 1 | 4 | 13 | 20.8 |  |
| 24 | 3 | Combination | 5×5 | 12 | 0 | 3 | 0 | 1 | 0 | 0 | 10 | 11.7 |  |
| 25 | 3 | Gridlock | 6×6 | 20 | 3 | 0 | 0 | 3 | 0 | 4 | 14 | 21.0 |  |
| 26 | 3 | Master Key | 5×5 | 12 | 0 | 3 | 0 | 1 | 0 | 0 | 11 | 12.3 |  |
| 27 | 3 | Domino Line | 5×5 | 13 | 2 | 0 | 0 | 3 | 2 | 7 | 10 | 25.9 |  |
| 28 | 3 | Safe House | 5×5 | 16 | 0 | 2 | 0 | 2 | 0 | 0 | 13 | 12.8 |  |
| 29 | 3 | Traffic Jam | 6×6 | 19 | 4 | 0 | 0 | 2 | 1 | 6 | 14 | 26.6 |  |
| 30 ✦ | 3 | Smoke and Mirrors | 6×6 | 17 | 2 | 0 | 3 | 2 | 1 | 2 | 14 | 19.6 |  |
| 31 | 4 | Twisted Lanes | 6×6 | 15 | 3 (1 CCW) | 0 | 0 | 3 | 1 | 8 | 12 | 27.9 |  |
| 32 | 4 | Vault | 5×5 | 17 | 0 | 4 | 0 | 2 | 0 | 0 | 12 | 13.9 | Silver |
| 33 | 4 | Hairpin | 5×5 | 19 | 3 | 0 | 0 | 2 | 0 | 7 | 17 | 28.8 |  |
| 34 | 4 | Strongroom | 6×6 | 17 | 0 | 4 | 0 | 1 | 0 | 0 | 16 | 16.8 | Silver |
| 35 | 4 | Gearbox | 6×6 | 21 | 4 (1 ALT) | 0 | 0 | 2 | 1 | 9 | 13 | 32.6 |  |
| 36 | 4 | Spin the Lock | 6×6 | 15 | 3 | 2 | 0 | 2 | 1 | 6 | 12 | 26.0 | Silver |
| 37 | 4 | Rush Order | 6×6 | 19 | 4 | 0 | 0 | 2 | 1 | 11 | 13 | 35.5 |  |
| 38 | 4 | Tumblers | 6×6 | 17 | 2 | 2 | 0 | 2 | 0 | 7 | 12 | 26.7 | Silver |
| 39 | 4 | Labyrinth | 6×6 | 19 | 3 | 0 | 0 | 2 | 1 | 11 | 16 | 36.9 |  |
| 40 ✦ | 4 | Night Shift | 6×6 | 19 | 2 | 0 | 3 | 2 | 0 | 7 | 13 | 28.6 | Silver |
| 41 | 5 | Gatekeeper | 6×6 | 14 | 3 | 2 | 0 | 2 | 0 | 8 | 10 | 27.4 | Silver |
| 42 | 5 | Whirlpool | 6×6 | 20 | 4 | 0 | 0 | 2 | 1 | 11 | 17 | 38.1 |  |
| 43 | 5 | Turnstile | 6×6 | 18 | 3 | 2 | 0 | 2 | 1 | 6 | 15 | 28.2 | Silver |
| 44 | 5 | Chain Reaction | 6×6 | 23 | 5 | 0 | 0 | 2 | 1 | 11 | 17 | 39.5 |  |
| 45 | 5 | Deadbolt | 5×5 | 14 | 3 | 2 | 0 | 2 | 1 | 10 | 13 | 34.0 | Silver |
| 46 | 5 | Key Ring | 6×6 | 20 | 4 | 3 | 0 | 2 | 1 | 8 | 16 | 34.2 | Silver |
| 47 | 5 | Grand Tangle | 6×6 | 21 | 3 | 0 | 0 | 2 | 1 | 15 | 14 | 43.5 |  |
| 48 | 5 | Lockstep | 6×6 | 20 | 4 | 2 | 0 | 2 | 1 | 9 | 15 | 34.7 | Silver |
| 49 | 5 | Long Way Round | 6×6 | 18 | 0 | 3 | 0 | 1 | 0 | 0 | 18 | 17.4 |  |
| 50 ✦ | 5 | Eclipse | 6×6 | 17 | 3 | 1 | 3 | 2 | 0 | 6 | 13 | 26.9 | Silver |
| 51 | 6 | Great Escape | 6×7 | 25 | 6 | 0 | 0 | 2 | 1 | 14 | 22 | 48.6 | Gold |
| 52 | 6 | Clockmaker | 6×6 | 22 | 5 (1 PAT) | 3 | 0 | 2 | 1 | 10 | 15 | 39.0 | Silver |
| 53 | 6 | Escape Room | 6×6 | 20 | 5 | 3 | 0 | 2 | 1 | 10 | 16 | 38.5 |  |
| 54 | 6 | Mechanism | 6×6 | 18 | 4 | 3 | 0 | 2 | 1 | 12 | 16 | 41.5 | Silver |
| 55 | 6 | Cyclone | 6×7 | 22 | 6 | 0 | 0 | 2 | 1 | 8 | 17 | 33.7 |  |
| 56 | 6 | Pressure | 6×7 | 22 | 5 | 3 | 0 | 2 | 1 | 11 | 17 | 41.3 | Silver + Gold |
| 57 | 6 | Grand Vault | 6×6 | 23 | 5 | 3 | 0 | 2 | 1 | 12 | 17 | 43.4 |  |
| 58 | 6 | Last Lock | 6×6 | 18 | 4 | 2 | 0 | 2 | 1 | 15 | 14 | 45.2 | Silver |
| 59 | 6 | Final Turn | 6×6 | 21 | 4 | 2 | 0 | 2 | 1 | 16 | 20 | 51.1 |  |
| 60 ✦ | 6 | The Last Secret | 6×6 | 22 | 4 | 2 | 4 | 2 | 0 | 10 | 15 | 38.3 | Silver |
| 61 | 7 | Neon Gate | 6×6 | 23 | 5 (2 CCW) | 2 | 0 | 2 | 1 | 11 | 18 | 41.9 ▲ | Gold |
| 62 | 7 | Afterglow | 6×6 | 22 | 5 (3 CCW) | 2 | 0 | 2 | 1 | 13 | 17 | 45.2 ▲ | Silver |
| 63 | 7 | Static | 6×6 | 17 | 5 (2 CCW, 2 ALT) | 1 | 0 | 2 | 1 | 14 | 10 | 42.2 ▲ |  |
| 64 | 7 | Night Circuit | 6×6 | 20 | 5 (2 CCW) | 2 | 0 | 2 | 1 | 15 | 15 | 47.2 ▲ | GS |
| 65 | 7 | Flicker | 6×6 | 24 | 7 (2 CCW, 3 ALT) | 2 | 0 | 2 | 1 | 12 | 17 | 46.1 ▲ |  |
| 66 | 7 | Voltage | 6×6 | 25 | 5 (2 CCW, 2 ALT) | 2 | 0 | 2 | 1 | 13 | 19 | 47.8 ▲ | Silver |
| 67 | 7 | Backspin | 6×6 | 20 | 5 (1 CCW) | 2 | 0 | 2 | 1 | 15 | 16 | 47.5 ▲ |  |
| 68 | 7 | Glowline | 6×6 | 25 | 4 (1 CCW, 2 ALT) | 2 | 0 | 2 | 1 | 14 | 16 | 47.1 ▲ | Silver + Gold |
| 69 | 7 | Prism | 6×6 | 19 | 4 (2 CCW, 1 ALT) | 2 | 0 | 2 | 1 | 16 | 14 | 48.5 ▲ |  |
| 70 ✦ | 7 | Blackout | 6×7 | 25 | 5 (2 ALT) | 2 | 5 | 2 | 0 | 12 | 20 | 47.9 ▲ | Silver |
| 71 | 8 | Overdrive | 6×6 | 21 | 6 (1 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 14 | 15 | 48.4 ▲ | GS |
| 72 | 8 | Synthwave | 6×6 | 22 | 6 (1 ALT, 1 PAT) | 2 | 0 | 2 | 0 | 15 | 17 | 49.0 ▲ |  |
| 73 | 8 | Pulse Lock | 6×7 | 24 | 6 (1 CCW, 3 ALT, 2 PAT) | 2 | 0 | 2 | 1 | 12 | 20 | 48.7 ▲ | Silver |
| 74 | 8 | Arcade | 6×7 | 24 | 6 (2 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 14 | 16 | 50.0 ▲ | Gold |
| 75 | 8 | Relay | 6×6 | 23 | 5 (1 ALT, 3 PAT) | 2 | 0 | 2 | 1 | 14 | 18 | 50.0 ▲ | Silver |
| 76 | 8 | Dynamo | 6×7 | 21 | 6 (2 ALT, 2 PAT) | 2 | 0 | 2 | 1 | 15 | 15 | 50.1 ▲ | Silver |
| 77 | 8 | Feedback | 6×6 | 20 | 5 (2 PAT) | 3 | 0 | 2 | 1 | 16 | 15 | 50.9 ▲ |  |
| 78 | 8 | Wavelength | 6×7 | 19 | 6 (1 CCW, 1 ALT, 1 PAT) | 3 | 0 | 2 | 1 | 15 | 16 | 50.0 ▲ | Silver + Gold |
| 79 | 8 | Hyperloop | 6×7 | 20 | 5 (1 CCW, 2 ALT, 1 PAT) | 2 | 0 | 2 | 1 | 15 | 19 | 51.3 |  |
| 80 ✦ | 8 | Dark Matter | 6×7 | 23 | 6 (1 CCW, 1 ALT, 1 PAT) | 3 | 4 | 2 | 0 | 14 | 17 | 50.7 ▲ | Silver |
| 81 | 9 | Summit Path | 6×7 | 25 | 7 (2 CCW, 3 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 12 | 17 | 51.0 ▲ | Silver + Gold |
| 82 | 9 | Thin Air | 7×7 | 22 | 6 (1 CCW, 3 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 15 | 16 | 52.5 ▲ |  |
| 83 | 9 | Ridge Line | 6×7 | 27 | 7 (1 CCW, 1 ALT, 1 PAT) | 2 | 0 | 2 | 1 | 14 | 21 | 52.0 ▲ | GS |
| 84 | 9 | Iron Crown | 7×7 | 23 | 7 (2 CCW, 2 ALT, 1 PAT) | 2 | 0 | 2 | 1 | 16 | 17 | 53.8 ▲ |  |
| 85 | 9 | Avalanche | 7×7 | 24 | 7 (2 CCW, 1 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 15 | 17 | 53.0 ▲ | Silver |
| 86 | 9 | Glacier | 7×7 | 24 | 7 (3 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 14 | 20 | 53.5 ▲ | GS |
| 87 | 9 | Stormwatch | 6×7 | 24 | 7 (1 CCW, 3 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 14 | 18 | 54.2 ▲ |  |
| 88 | 9 | High Pass | 6×7 | 29 | 5 (3 CCW, 1 ALT, 1 PAT) | 3 | 0 | 2 | 1 | 15 | 20 | 54.0 ▲ | GS |
| 89 | 9 | Keystone | 7×7 | 21 | 7 (1 CCW, 1 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 17 | 15 | 54.9 ▲ |  |
| 90 ✦ | 9 | Eclipse Peak | 6×6 | 24 | 5 (1 CCW, 2 ALT, 2 PAT) | 3 | 5 | 2 | 0 | 14 | 20 | 54.2 ▲ | Silver |
| 91 | 10 | Grandmaster | 7×7 | 25 | 7 (1 CCW, 2 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 15 | 17 | 55.9 ▲ | Silver + Gold |
| 92 | 10 | Checkmate | 7×7 | 26 | 7 (2 CCW, 2 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 15 | 19 | 55.1 ▲ |  |
| 93 | 10 | Gordian Knot | 7×7 | 30 | 7 (1 CCW, 2 ALT, 2 PAT) | 2 | 0 | 2 | 1 | 14 | 25 | 56.3 ▲ | GS |
| 94 | 10 | Clockwork Crown | 7×7 | 27 | 7 (1 CCW, 1 ALT, 2 PAT) | 2 | 0 | 2 | 1 | 15 | 20 | 56.5 ▲ |  |
| 95 | 10 | Paradox | 7×7 | 24 | 6 (1 CCW, 2 PAT) | 3 | 0 | 2 | 1 | 18 | 18 | 57.9 ▲ | Silver |
| 96 | 10 | Endgame | 7×7 | 22 | 6 (1 CCW, 2 ALT, 1 PAT) | 3 | 0 | 2 | 1 | 18 | 18 | 58.0 | GS |
| 97 | 10 | Apex | 7×7 | 22 | 6 (1 CCW, 1 ALT, 1 PAT) | 2 | 0 | 2 | 1 | 19 | 18 | 58.5 |  |
| 98 | 10 | Zenith | 6×7 | 23 | 6 (1 CCW, 1 ALT, 2 PAT) | 3 | 0 | 2 | 1 | 19 | 18 | 61.0 | Silver + Gold |
| 99 | 10 | Last Light | 6×7 | 25 | 6 (2 CCW, 1 ALT, 1 PAT) | 2 | 0 | 2 | 1 | 19 | 21 | 61.1 |  |
| 100 👑 | 10 | The Master | 7×7 | 24 | 7 (1 CCW, 2 ALT, 2 PAT) | 3 | 3 | 2 | 1 | 21 | 19 | 67.7 | Silver + 2 Gold |

## Score rules (`scripts/core/score_rules.gd`)

| | Points |
|---|---|
| Each escape | **100 + 20 × (chain − 1)**, with the chain bonus capped at +200 (chain ×11) |
| Board cleared | +500 |
| Hearts remaining | +200 each. Levels without hearts count 3 minus mistakes. |
| No blocked/locked tap | +300 |
| No Hint used | +300 |
| No Undo used | +300 |
| **PERFECT** | **+1000** |
| Blocked or locked tap | −100 each |
| Undo | −150 each |
| Hint (free or booster) | −250 each |
| Hammer booster | −400 each |

- There's no time component in Classic mode.
- Escape points are stored in the Undo snapshot, so an undone move also takes back its points. You can't farm points with Undo.
- The score never goes below 0.
- The best possible score is `ScoreRules.max_score(blocks)`: one unbroken chain and PERFECT.

## Star rules

The defaults, overridable per level:

| Star | Default rule |
|---|---|
| ★ | Complete the level |
| ★★ | `no_hints`: complete without a Hint or Hammer |
| ★★★ | `perfect_or_score`: PERFECT, or a score ≥ the level's target |

- Stars are cumulative: star 3 also needs star 2.
- The automatic 3-star target is `max_score − 1500`. A clean run that used Undo once still reaches it, but a run with a blocked tap does not.
- A level can override any rule in its JSON: `"stars": {"two": "no_mistakes", "three": "no_undo", "score": 9000}`.
- Available rule names: `complete`, `no_hints`, `no_undo`, `no_mistakes`, `perfect`, `score`, `perfect_or_score`.
- The best stars and best score per level are saved, and they never go down.

## PERFECT rules

A PERFECT clear needs **no heart lost** (no blocked or locked tap), **no Undo**, **no Hint** and **no Hammer**. In onboarding levels without hearts, "no heart lost" means no blocked tap. It gives:

- +1000 points
- a golden "PERFECT!" stamp over the board, a double celebration burst and a special jingle (the music ducks)
- a gold-framed card titled **PERFECT!**
- a guaranteed ★★★

## Undo rules

- **3 Undos per level attempt.** The count left is shown as a badge on the button, and the button is disabled at 0 or when there's nothing to undo.
- Each Undo costs 150 points, removes the No-Undo bonus and prevents PERFECT.
- Undo restores the board, spinner directions, hidden arrows, locks, the chain and the escape points. It does not refund hearts or penalties.
- If you're stuck with no Undos left, the game says *"No moves left – tap Restart"*.
- Restart and Replay start a fresh attempt with 3 Undos.

## Hint rules

- Free allowance per level: **levels 1–19: 0** · **20–29: 1** · **30+: 2**. A level can override this with `"hints": n`.
- When the free hints are used up, the HINT button uses **Hint boosters** from the inventory.
- A hint highlights one recommended **legal** move that keeps the level solvable. It never plays the move and never shows more than one.
- Each hint costs 250 points, removes the No-Hint bonus (and therefore ★★) and prevents PERFECT.
- If the board is already lost, Hint points to Undo instead, and nothing is spent.
- **Debug mode** (F1, or `--debug`) has unlimited, free hints.

## Locked blocks

- A locked block shows a **padlock in its key color** and a soft veil. It can't escape while **any block of the key color** is still on the board.
- It still blocks other blocks' lanes while it waits.
- Tapping a locked block counts as a blocked tap: it costs a heart and −100 points. The block rattles and all its key blocks hop, so the rule explains itself.
- When the last key-color block escapes, the padlock **pops open**, with a burst in the key color, a flash, an unlock chime and a haptic tick.
- In level data it's written `B>#G` (a blue right-arrow block locked by green), or `"lock": "green"` in the explicit form.
- The lock state is derived from the board, so Undo re-locks correctly, and the solver needs no extra state.
- **Future lock types.** `BlockData.lock_color` and `BoardModel.is_locked()` / `key_blocks()` are the single extension point. A new condition would add a field and one branch there. None are implemented yet.
- **Teaching.** Level 16 has one lock and two green keys, with a short hint and a finger. Levels 18–34 are lock-only boards with growing depth. From 36, locks combine with spinners.

## Mystery levels

- Levels **10, 20, 30, …, 90** (and the Master Level 100). They have a slightly deeper board tint, a purple **"? MYSTERY"** label, and a "?" marker in Level Select.
- A hidden block shows its **color** but a **"?"** in place of its arrow, with a dashed inner border.
- **Reveal rule:** the arrow is revealed as soon as **an orthogonally adjacent block escapes**, with a card-flip animation and a sparkle sound.
- **A hidden block can't escape until it's revealed**, and tapping it is free: it wobbles and explains, with no heart lost and no penalty. So you never have to *guess* an arrow.
- **Fairness is proven by the verifier.** At every state along the solution, for each still-hidden arrow and each of its three other possible directions, the trap status of every risky visible move must stay the same (`Solver.mystery_fairness()`). So a player can always choose a good move from visible information only; hidden arrows are uncovered, not guessed. Alternatives that would make the level unsolvable are ignored.
- Mystery combines with other mechanics gradually:
  - 10 and 20: mystery only
  - 30 and 40: mystery + spinners
  - 50–90 and 100: mystery + spinners (including the new rules from 70) + locks
- In level data it's written `Y>?`. Spinners and locked blocks can't be hidden.

## Level generator and levels 101+

```bash
godot --headless --path . --script res://tools/generate_levels.gd -- --profile=w5_expert --count=3 --seed=7 [--out=user://generated]
godot --headless --path . --script res://tools/strengthen_levels.gd -- --targets=62:45 [--steps=1200] [--write]
godot --headless --path . --script res://tools/place_reward_blocks.gd [-- --write]
```

The pipeline:

1. Reverse construction (solvable by design).
2. Hill-climbing mutations: arrows, spinners, spinner rules, locks, colors and hidden arrows.
3. Solver validation.
4. Metric rejection: start moves, direction diversity, depth, decision points, start traps, and required mechanics and spinner rules.
5. Repetition filter.
6. `LevelAnalysis` gate: no decorative mechanic, and every mystery proven fair.

**v0.5: Chapters continue past 100.**

- `Chapters.chapter_of(n)` is unbounded, and themes for Chapters 11+ come from `data/chapters.json` (`overflow.cycle`). The Chapter multiplier keeps rising, capped.
- `LevelGenerator.chapter_plan(c)` returns, for any Chapter:
  - the profile (mechanic mix and rejection rules)
  - the difficulty band (`chapter_target(c)`: the campaign's measured Chapter averages, +3 per Chapter after 10)
  - the reward frequency: how many of its 10 levels carry Silver / Gold, with Diamond reserved at 0
  - the maximum rewards per level
- `profile_for_level(n)`, `target_difficulty(n)` and `generate_for_level(n)` follow the plan, and every 10th level from 60 on is a mystery.
- `reward_slots(c, count, phase)` and `assign_reward_blocks(level, silver, gold)` place reward blocks deterministically: Gold late in the solution, Silver in the second half, never on hidden blocks or the last block.
- `LevelGenerator.classify(level, n)` sorts a level by:
  - Chapter and difficulty
  - spinner complexity (0 none, 1 clockwise only, 2 one extra rule, 3 mixed rules)
  - lock complexity and mystery complexity (0–3)
  - reward blocks and reward frequency
  - solvability

Generated levels go to a separate folder for human curation and are never released automatically.

---

## Run it locally

1. Install **Godot 4.3** or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, select this folder's `project.godot`.
3. Press **F5** (Run Project).

The desktop window opens at phone proportions (405×720). Mouse clicks are treated as touches.

```bash
godot --path .                                  # play
godot --path . -- --level=40                    # start directly on level 40 (skips the title)
godot --path . -- --debug                       # start with the debug panel open (unlimited hints)
```

### Controls

| Action | How |
|---|---|
| Escape a block | Tap it |
| Undo (3 per level) | **UNDO**. The badge shows the uses left. |
| Hint | **HINT**. The badge shows free hints left + owned boosters, e.g. `1+2` (∞ in debug). |
| Hammer | **HAMMER**, then tap a block. The badge shows owned Hammers. |
| Shop | Tap the coin pill (under the gear) |
| Level Select | Grid icon, top left |
| Restart level | **RESTART** |
| Settings | Gear icon, top right |
| Debug panel | **F1**, or tap the "LEVEL X" title 5× quickly on a device |
| Debug shortcuts (panel open) | `R` restart · `H` play one correct move · `S` auto-solve · `[` / `]` previous/next level |

### Saved progress

See **Save / Continue** above for what is saved and how.

### Export to mobile

The project uses the **Compatibility** renderer, a portrait orientation and `canvas_items` stretch with `expand` aspect, so it scales across phone sizes and respects notches and safe areas.

1. *Editor → Manage Export Templates* → download the templates for your version.
2. *Project → Export → Add…* → **Android** (needs the Android SDK and a debug keystore) or **iOS** (needs macOS + Xcode).
3. **Web:** `export_presets.cfg` has a ready **Web** preset (single-threaded, so it runs without special server headers). Run `godot --headless --path . --export-release "Web" build/web/index.html`, then serve `build/web/` over HTTP.
4. Levels are plain JSON. Godot 4 exports `.json` automatically, but if levels are missing in a build, add `levels/*.json` under *Export → Resources → Filters to export non-resource files*.

---

## Automated checks

Run `godot --headless --path . --import` once on a fresh checkout, so Godot registers the script classes and imports the QOA music.

```bash
godot --headless --path . --script res://tools/run_tests.gd        # unit tests
godot --headless --path . --script res://tools/verify_levels.gd    # 100-level analysis + campaign rules
godot --headless --path . res://tools/Playtest.tscn                # end-to-end play-through (-- --chapters-only for the v0.5 part)
godot --headless --path . res://tools/Soak.tscn -- --cycles=2        # long session: 1 -> 100 twice in one process
godot --headless --path . --export-release "Web" build/web/index.html && node tools/web_audio_test.mjs   # real browser
node tools/web_persistence_test.mjs                                  # Web save scenarios A-F (itch-like iframe)
xvfb-run godot --path . res://tools/Capture.tscn -- --gallery=5,15,25,36,45,56,64,78,86,96,100 --out=/tmp/shots   # screenshots
```

**Unit tests** (`run_tests.gd`) cover everything since v0.1. v0.5 adds:

- **Chapters:** the boundaries 10/11 … 91–100 and 101+/111+; 10 distinct theme ids, music identities, decorations and block styles; block finish growing Chapter by Chapter; every music file present; the Master theme; the overflow themes for Chapter 11 and 12.
- **Readability of every theme:** text contrast ≥ 4.5 (≥ 2.6 soft), every block color vs. the board ΔE ≥ 35, and every arrow on its block.
- **Reward blocks:**
  - the `$S` / `$G` / `$D` tokens, combined with other modifiers
  - the round trip through JSON and the explicit block format
  - rarity never changes the rules
  - Silver +5 and Gold +15, Diamond disabled
- **Anti-farming:** each block pays once, including after a repeat escape and a relaunch; rewards are counted per level; reward coins count toward the Chapter total.
- **Chapter complete** fires and pays once, and persists.
- **Chapter chest:** tiers at 20 / 25 / 30, upgrade level, the Hammer item, never duplicated, persisted, and v0.4 chest ids kept.
- **Save migration v2 → v3** from a real v0.4 file (see *Compatibility*).
- **Generator for 101+:**
  - Chapter targets rising through Chapter 15
  - the Chapter plan: Silver from Chapter 4, Gold from Chapter 6, no Diamond
  - reward slots stay inside their Chapter
  - `classify()` on levels 5 and 100
  - reward placement on a generated level survives JSON and keeps it solvable

**Level verifier** (`verify_levels.gd`): all v0.4 campaign rules, plus the rising Chapter averages and the reward-placement rules (the first level for each rarity, at most 2 per level, 3 on the Master Level, no disabled rarity).

**Playtest** (`Playtest.tscn`) clears **all 100 levels** through the real scene with injected touches: a blocked tap, a hint, an Undo and a solver-driven clear per level. It also runs these scenarios:

- **Chapter transitions** 10→11, 20→21, 30→31, 40→41, 50→51, 60→61, 70→71, 80→81, 90→91 and 99→100, through:
  - **NEXT LEVEL** and **Level Select**
  - **Replay** and **Restart** (levels 11, 31, 51, 71, 91 and 100)
  - **debug jumps**, including backwards and across Chapters
  - **rapid** transitions that interrupt the fades (39→40→41, 70→71→61→90)
  - **Continue** after a real relaunch (57 and 81)

  With music ON, it checks after each one:
  - the calculated Chapter and every theme id
  - the exact background colors, decoration and particle colors
  - the board tint and accent (progress bar, coin pill)
  - the block material, on the `Palette` and on **every real block view**
  - the music theme, with exactly one player left playing

  It also checks the HUD's "CHAPTER n · k/10" line and Level Select's 10 Chapter groups.
- **Silver (level 32) and Gold (level 51):**
  - the one-time tip
  - +5 / +15 paid on escape, and "+N COINS" flying to the counter, which then updates
  - **Undo** brings the block back spent and pays nothing again
  - **Restart** shows it spent and pays nothing
  - the level card counts the Gold
  - **Hammer** on a Gold block pays nothing, doesn't mark it collected, and it can still be earned by play after a Restart
  - persisted to disk
- **Chapter complete:**
  - clearing level 30 completes Chapter 3, the card says so, and the button reads CONTINUE
  - the card shows stars / 30 and previews "CHAPTER 4 · EMBER RIDGE" with "NEW: Silver Blocks"
  - chest tiers are claimed from the card, never twice
  - CONTINUE starts Chapter 4 (fully applied)
  - clearing level 30 again fires nothing, and NEXT goes straight on
  - persisted to disk
- **Relaunch:** CONTINUE – LEVEL 57, and the title shows "CHAPTER 6 · MIDNIGHT TIDE". Coins, boosters, stars, bests, chests, **completed Chapters and collected reward blocks** are all restored.
- The v0.4 scenarios: web audio gate, Shop / Hammer, Hint booster, coins, chests and the Master Level. The v0.3 scenarios: PERFECT, bests, Replay, Undo/Hint limits, locks, mystery, hearts, Restart and a trap.

**Web audio test** (`tools/web_audio_test.mjs`, real Chromium, strict autoplay policy). The game has **no test hooks**: the test taps the screen, reads `window.chainEscapeAudio` and measures the **real output signal** through an analyser on the audio destination. It runs these cases:

- mobile first visit
- returning player with Music ON
- Music OFF and SFX OFF, set by editing the real save file in IndexedDB from a same-origin page, then reloading
- an iOS-like context forced to start **suspended**
- desktop mouse

Each case checks:

- nothing unlocked and silent output before the first gesture
- the saved settings are restored
- the context is running after one tap, and `resume()` ran inside the gesture (suspended case)
- the music signal reaches the output, and the output stays silent with Music OFF
- later taps never restart the music (its playback position keeps running)
- the RESTART click plays a sound effect and reaches the output, or is silent with SFX OFF
- **no `[CE-Audio]` logging and no test hooks** (`ceSetSetting`, `testTone`) remain

**Current results (v0.5):**

| Check | Result |
|---|---|
| Unit tests | `UNIT TESTS PASSED`: 10,029 checks, 0 failures |
| Level verifier | `ALL 100 LEVELS SOLVABLE AND PASS CAMPAIGN RULES`. Chapter difficulty rises C1 4.7 … C6 42.1, C7 46.1, C8 49.9, C9 53.3, C10 58.8. Level 100 is the hardest (67.7). All mystery levels are fair. There are 39 Silver and 18 Gold blocks, all within the placement rules. |
| Playtest | `PLAYTEST PASSED`: all 100 levels cleared through real touch input, plus the Chapter transitions (10 boundaries × NEXT / Level Select / Replay / Restart / debug / rapid / relaunch, with music on), Silver/Gold rewards and anti-farming, Chapter Complete + chest, and every v0.3/v0.4 scenario |
| Web audio (real browser) | `WEB AUDIO TEST PASSED`: 75 checks (Chromium, strict autoplay). Covers mobile first visit, returning player with Music ON / Music OFF / SFX OFF, a suspended (iOS-like) context and desktop mouse. The real output signal is measured, and it confirms no debug logging and no test hooks remain. |
| Rendering | Screenshots at 720×1280 of one level from every Chapter and the Master Level, Silver/Gold blocks on light and dark Chapters, the Chapter Complete card and the Chapter-grouped Level Select |

The tests write progress to separate files (`user://test_*.cfg`, `user://playtest_progress.cfg`), never to the player's save.

## Compatibility

- **v0.4 saves (v2)** load and migrate to v3 automatically. Nothing is lost:
  - progress, bests, stars, PERFECTs, coins, inventory, settings and achievements are kept
  - **completed Worlds 1–5 become Chapters 1–10 complete** (two each). Their World bonus was already paid, so no second bonus, and no old "Chapter Complete" card fires.
  - a Chapter that was fully cleared inside an unfinished World never paid anything, so it gets its +50 once, silently, and is marked complete
  - **chests:** v0.4 chests were already per 10 levels with the same ids, so every claimed tier stays claimed. The old 24★ / 27★ claims count as the new 25★ / 30★ tiers, so no tier pays twice.
  - reward blocks start uncollected, so returning players can earn them on replays
- **v0.3 saves (v1)** still migrate: v1 → v2 (starting coins, PERFECT from 3★), then v2 → v3.
- **Tuned levels 61–78 and 80–95** kept their names, sizes and mechanics. Stars and best scores earned on the old versions are kept (they never go down). The 3-star score target follows the new layout.
- **Economy retune:** Chapter multipliers replace World multipliers, the Chapter bonus (+50 per 10 levels) replaces the World bonus (+100 per 20), and the chest tiers moved to 20 / 25 / 30.
- **Removed:** `scripts/core/worlds.gd` (replaced by `Chapters` + `data/chapters.json`), the `music_w1..w5` loops (replaced by `music_c01..c10`), and the temporary web-audio debug flags.

---

## Project structure

```
data/economy.json             Tunable economy (prices, rewards, Chapter multipliers, chest tiers, reward blocks)
data/chapters.json            Chapter themes: colors, decoration, particles, music, block material, 101+ overflow
levels/level_01..100.json     Level data (map tokens: @ @- @~ @* spinners, ? hidden, #K locked, $S $G reward)
assets/audio/music_*.wav      Eleven generated music loops (c01..c10, master), imported as QOA
export_presets.cfg            Web export preset (single-threaded, head include = web/audio_unlock.js)
scripts/
  game_manager.gd             Orchestration: title/continue, Chapters, rules, history, hearts, limits,
                              score, stars, coins, reward blocks, Chapter complete, chests, shop, boosters
  core/
    chapters.gd               Chapter mapping (unbounded) + themes from data/chapters.json
    block_data.gd             Block data incl. spinner rule + step, reward rarity
    board_model.gd            Rules: lanes, spinners, locks, hidden arrows, snapshots
    solver.gd                 Search solver, hints, analysis, fairness
    level_analysis.gd         Mechanic impact + fairness report
    level_generator.gd        Generator: profiles, Chapter plan, targets, reward placement, classify
    economy.gd                Coins, reward blocks, Chapter chests + milestone, shop (reads data/economy.json)
    player_progress.gd        Authoritative save v4: seq-numbered atomic write, .bak, Web localStorage
                              mirror, newest-copy load, quarantine + salvage, migration v1..v3
    diagnostics.gd            [Diag] line per level transition, session marker, how the last session ended
    web_bridge.gd             Game -> page calls on one cached JS object (no runtime eval)
    score_rules.gd / level_manager.gd / level_data.gd / direction.gd / history.gd
    board.gd / block_view.gd  Board + blocks (Chapter material, Silver/Gold frame, gem, halo, shine);
                              animated parts drawn once, moved by transform/modulate only
  ui/
    ui_manager.gd             HUD, 4-button bar, coin pill + flying coins, Chapter banner, cards, settings
    chapter_card.gd           Chapter Complete card (stars /30, coins, chest, next-Chapter preview)
    chapter_background.gd     Gradient + ambient decoration + particles per Chapter
    title_screen.gd           CONTINUE - LEVEL X (+ Chapter) / PLAY + LEVEL SELECT
    level_select.gd           Chapter-grouped grid, chest tiers, Mystery marker, reward gems, Master crown
    shop_panel.gd / coin_pill.gd / stars_row.gd / shapes.gd / hearts_bar.gd / pill_button.gd /
    progress_bar.gd / tutorial_hint.gd / palette.gd (incl. block material + metals)
  audio/ audio_manager.gd (Chapter themes, sequential fades, web unlock), haptics.gd
tools/ run_tests.gd, verify_levels.gd, Playtest.tscn, Soak.tscn, Capture.tscn, generate_levels.gd,
       strengthen_levels.gd, place_reward_blocks.gd, generate_music.py, web_audio_test.mjs,
       web_persistence_test.mjs, sync_web_head.py
web/   audio_unlock.js (page-level Web Audio unlock, save mirror, page-event forensics, WebGL
       context-loss reload; inlined via export_presets.cfg)
```

## Architecture

```
            taps                      rules/solver           snapshots
  Board ───────────────► GameManager ───────► BoardModel     History
    ▲  escape/bump/turn/     │   │            Solver ▲          ▲
    │  hint highlight        │   └───────────────────┴──────────┘
    │                        ├──► UIManager   (hearts, chain, progress, cards, settings)
    └────────────────────────┤◄── UIManager signals: undo / hint / restart / next / setting
                             ├──► AudioManager (autoload: Music + SFX buses) + Haptics
                             ├──► Chapters (data/chapters.json) → ChapterBackground, Board, UI, music
                             ├──► Economy (data/economy.json: coins, reward blocks, chests, milestones)
                             ├──► PlayerProgress (ConfigFile v4: progress, bests, stars, rewards, settings)
                             ├──► ScoreRules (score, PERFECT, stars)
                             └──► TutorialHint, DebugPanel
```

- **Model vs. view split.** `BoardModel` holds the grid and rules, and `BoardModel.remove()` returns the spinners it turned. `Board`/`BlockView` only draw and animate. `GameManager` asks the model what is legal, then tells the view what to play.
- **Solver.** It works on a compact in-place copy of the board, and memoizes dead states by remaining blocks plus spinner directions. Locks (color counts) and reveals (whether any original neighbor has escaped) are derived from the alive set, so the memo key stays exact. Its key pruning rule is that a free block with no spinner neighbor is *always* safe to remove, because it only frees space and turns nothing. So it removes those greedily, and it branches only on moves that turn spinners. That keeps hints instant on a phone. A node limit guards against pathological boards.
- **Undo = snapshots.** Unchanged since v0.1. Spinner directions and hidden flags live in the block snapshot. Locks are derived from the board (color counts), so Undo re-locks automatically. Escape points are in the snapshot too, so an undone move also takes back its points. Hearts, mistakes and penalties are deliberately *not* in the snapshot.
- **Locks and mystery in the model.** `BoardModel.move_state(id)` returns `ok`, `blocked`, `locked` or `hidden`. `remove()` reports turned spinners, `last_revealed` and `last_unlocked`, so the Board can animate them.
- **Grid, not pixels.** The board fits any rows × columns. 3×3 up to 6×7 are in use.
- **Logic first, animation second.** A tap updates the model immediately and the animation follows, so fast chains are never throttled.
- **Rewards never touch the rules.** Rarity is data on `BlockData` that `BoardModel` and the `Solver` ignore. `GameManager._escape()` asks `Economy.collect_reward_block()`, which pays once and saves at once; `_smash()` never asks. So Undo snapshots, Restart and the solver need no reward state, and farming is impossible by construction.
- **Chain system.** Unchanged: consecutive escapes without a blocked tap. As the chain grows, the pitch climbs a pentatonic scale, the text grows, the particles strengthen and exits get faster. Finishing a level with no blocked taps shows **PERFECT CHAIN!**

## Level format

One JSON file per level: `levels/level_NN.json`, discovered by number.

**Map form (recommended).** Comments here are for illustration only; JSON files can't contain them.

```jsonc
{
  "name": "Order Matters",
  "hint": "Order matters now - look before you tap",  // optional start message
  "hint_finger": false,        // optional: show the animated finger with the hint (default true)
  "blocked_hint": "…",         // optional: shown once after the first blocked tap
  "hearts": 3,                 // optional: override the heart rule (0 = none)
  "map": [
    ".   .   .   .",
    ".   B^@ G<  R<",
    "P>  Yv  .   .",
    ".   .   .   ."
  ]
}
```

Each cell is `.` (empty) or a color letter + arrow, then optional modifiers in this order: `@` spinner (`@` clockwise, `@-` counter-clockwise, `@~` alternating, `@*` pattern), `?` hidden arrow (mystery), `#K` locked by color K, `$R` reward rarity (`$S` Silver, `$G` Gold, `$D` Diamond, reserved). For example: `B>`, `R^@`, `R^@~`, `Y<?`, `G>#P`, `B>@*#R`, `Y^#B$S`, `G^@~$G`.

- Colors: `R` red, `B` blue, `G` green, `Y` yellow, `P` purple.
- Arrows: `^` up, `v` down, `<` left, `>` right.

**Explicit form:**

```json
{ "rows": 4, "columns": 4,
  "blocks": [ { "row": 1, "column": 2, "color": "red", "direction": "up", "spinner": true, "spin": "alt", "lock": "green", "hidden": false, "rarity": "gold" } ] }
```

Optional level keys:

- `mystery` (bool)
- `hints` (per-level hint allowance)
- `stars` (star rules)
- `hearts`, `hint`, `hint_finger`, `blocked_hint`

---

## Known limitations

- **Real devices:** the iOS Safari audio fix was verified on an iPhone (v0.4.x), and v0.5 keeps that mechanism unchanged. The v0.5 build itself was tested in Chromium (mobile emulation, touch, strict autoplay, and a forced-suspended context). WebKit and Edge can't run in this build environment; Edge uses the Chromium engine that was tested. Please re-check on an iPhone: the first tap starts the music, and a Chapter change fades the music cleanly.
- **Stream playback mixes on the main thread** in the single-threaded Web build. If the frame rate collapses, the music can stutter.
- **Real-phone crash confirmation:** the WebGL id leak was measured and fixed in Chromium. iPhone Safari can't run here, so the long-session fix needs one real 40 → 70 session on an iPhone. If anything still ends a session, the debug panel names how it ended.
- **Short UI tweens still redraw** (hearts, stars, the coin counter) for a fraction of a second per event. That growth is tiny and bounded per level, unlike the per-frame animations that were fixed.
- **Web saves** live in the browser's IndexedDB plus a localStorage mirror. Clearing site data or private browsing loses progress, and **Safari clears storage inside itch.io's embed when it closes** (the game shows an OPEN GAME banner there). There are no accounts or cloud sync (not in scope).
- **Economy values are first guesses** (`data/economy.json`), not tuned with players.
- **Levels 61–95 were tuned by metrics**, with every rule re-verified, but not by human playtests. Late Chapters are long, planning-heavy boards (19–30 blocks, depth up to 25).
- **Locks depend on color.** Silver/Gold keep the block's color, so lock readability is unchanged. A symbol-per-color option is still future work.
- **Mystery fairness** is proven along the solver's solution line, not for every possible detour.
- **Placeholder audio and art.** The music and sound effects are generated, and the UI uses the system font.
- **Headless runs print an exit warning** about leaked audio resources. It comes from the dummy audio driver and is harmless.

## Recommended next steps

1. **Playtest v0.5 on real phones:** do Chapter changes feel like "somewhere new"? Is Gold exciting, and is Silver too frequent? Do players replay for the 25★ / 30★ chest tiers?
2. **Tune the economy** from real coin income: reward-block values, chest tiers and Chapter multipliers are all in `data/economy.json`.
3. **Real music per Chapter family**, dropped in as `music_cNN.ogg`.
4. **Chapter 11+:** add hand-made themes to `data/chapters.json`, generate with `generate_for_level(n)`, place rewards with `place_reward_blocks.gd`, and curate.
5. **Then** the next phase: Daily Challenge, leaderboards and store billing (deliberately not in v0.5).
