# Player Identity: Phase 3A (QA only)

**Status:** in the QA and dev builds. 3A tested on a real iPhone; the 3A polish (Settings layering, 20 characters, mixed scripts) is waiting for real-iPhone QA.

**Production is unchanged.** The player build ("Web Friend Test") has no identity: no id, no name row, and no `[profile]` written.

The switch is `BuildFlags.player_identity()` (`scripts/core/build_flags.gd`), which returns `not player_build()`.

## What it is

- **An anonymous player id.** A random UUID v4 is made on this device the first time the game starts, then kept in the save.
  - It comes from Godot's `Crypto` (mbedTLS CTR-DRBG, seeded from the OS entropy source; on the Web, `crypto.getRandomValues` through Emscripten).
  - It is **never shown** in the game. Test builds publish only a 12-character hash of it.
- **An optional display name in Settings.** The row reads "ADD YOUR NAME (OPTIONAL)" or "YOUR NAME: …", with "Optional - kept on this device only" under it.
  - Tapping the row opens the native name field: the same iPhone-safe approach as the challenge message, with the keyboard coming up from the tap and the field pinned above the keyboard.
  - The field normalizes text to Unicode NFC and trims it. The game then validates it.

## What it is not

- **Not an account and not authentication.** No server knows the id or the name, and nothing is sent anywhere: no Supabase call, no new endpoint.
- **Not cross-device recovery.**
  - The backup code is a copy of the save, so it now also carries the id and name. Restoring it on a new device continues as that player.
  - The code proves nothing and is not a credential. Anyone holding a copy has an equal copy.
  - Two devices restored from the same code share an id. This is fine today, since nothing compares players yet.
- **No change** to timing, competition eligibility, scoring, economy, levels or saves outside `[profile]`.

## Save format

This is an additive section in the same file. Version 5 and the r2 keys are unchanged.

```
[profile]
id="<uuid v4>"
name="<display name, or empty>"
name_set_unix=<when the name was last set or removed>
created_unix=<when the id was made>
```

- **Older builds** keep the section untouched (they rewrite only known keys). This is tested by rolling back to the previous QA build and forward again.
- **Identity disabled** (the player build): a `[profile]` already in a save is written back unchanged; none is ever created.

## Name rules

These live in `scripts/core/player_profile.gd` and are kept simple and predictable.

- **Length:** 2 to 20 **user-perceived characters** (grapheme clusters) after trimming. A letter with its accents or vowel points counts once, so 20 pointed Hebrew letters (60 code points) fit. Runs of spaces become one space.
  - GDScript counts with `PlayerProfile.grapheme_count` (every non-mark starts a cluster; exact for the allowed set, which has no joiners).
  - The native field counts with `Intl.Segmenter` (fallback: code points minus marks), shows a live "n / 20" and holds SAVE while over the limit. Both counts agree on every test name.
  - The saved name is never cut. Only the Settings row shrinks its font (26 → 19 px) and, past that, ends with an ellipsis on whole glyph clusters.
- **Allowed letters are exactly those the Web build can draw**, and scripts may be mixed in one name ("Loay לואי", "Loay لؤي לואי"):
  - Latin: Latin-1, Extended-A, the Extended-B letters Open Sans has (Vietnamese horn letters, Romanian comma-below, …), Welsh ŵ-accents and the Vietnamese block.
  - Greek (monotonic) and Cyrillic: from the engine's built-in Open Sans.
  - Hebrew letters, with points, maqaf, geresh and gershayim (Noto Sans Hebrew).
  - Arabic letters, with harakat and Arabic-Indic digits (Noto Sans Arabic).
  - Digits, spaces, and `- _ . '`.
  - ProfileCheck checks every allowed code point against those fonts. Unrenderable Latin Extended-B letters that 3A allowed are now refused.
- **Folding:** the typographic apostrophes `‘ ’ ʼ` become `'` (iPhone Smart Punctuation types `’` for `'`). Nothing else is changed.
- **At least one letter or digit.** At most 3 combining marks on one letter, and never a mark with no letter.
- **Refused, never silently stripped:**
  - control characters;
  - bidi controls (LRM/RLM, embeddings and overrides, isolates, ALM);
  - zero-width characters, joiners and BOM;
  - variation selectors, emoji and other symbols;
  - scripts without a bundled font (CJK, Armenian, Devanagari, …), and the replacement character.
- **A refused name** keeps the current one, and the row shows the reason. **An empty name** removes it. **Duplicate names** are allowed.
- **Display:** names use `MessageText` fonts and are isolated with FSI…PDI, so an RTL name keeps its direction after "YOUR NAME:". Adjacent RTL words read right to left, as in any Unicode text: "Loay لؤي לואי" shows as "Loay לואי لؤي".

## Settings layering (3A polish)

Every control of the UI CanvasLayer draws, and receives taps, in tree order. `_build_settings()` used to run before the coin pill, TOTAL SCORE, TIME / MY BEST and the banner were added, so those drew over the Settings dimmer and card. A tap on the coins through the open Settings card opened the shop. Settings is now built after every HUD control. `settings_layer_state()` and the page state field `settings_over` report any HUD control that would draw above it, and ProfileCheck and the browser test require that list to be empty.

The level-complete / try-again card keeps the coin pill above its dimmer on purpose: it is the coin fly-in target, and the card is placed below the top HUD (`_card_fit_scale`).

## Emoji (investigated, not enabled)

- A subset of Noto Color Emoji (OFL, CBDT bitmaps) with only 🏆 ❤️ 🔥 ⭐ 🧩 is 11.8 KB (about 2.4 KB per emoji). Godot 4.3 on the Web draws it in colour as a fallback after Open Sans and Noto Hebrew, at 26 and 40 px, with or without the U+FE0F variation selector.
- Any emoji outside the subset draws as a box, and the Web build has no system emoji font. So emoji could only ever be a fixed whitelist. The full font is 10.8 MB, too large to bundle.
- The smallest safe implementation, if approved:
  1. Bundle the subset font as the last `MessageText` fallback.
  2. Accept only whitelisted emoji, each optionally followed by U+FE0F, and count each as one character (`Intl.Segmenter` already does).
  3. Keep refusing joiners, skin tones and flags.
  4. Optionally allow at most 2 emoji per name.
- Native entry on iPhone and Android uses the system emoji font and needs no change. A future leaderboard drawn in Godot would show the same subset glyphs on every platform.

## Restore and transfer: whose identity is kept

These rules are in `PlayerProgress._merge_profile`. They apply to backup restore and to the itch.io embed → own-tab transfer. Progress is still merged exactly as before.

| This save | Code / transfer | Result |
|---|---|---|
| No meaningful progress (no cleared level, score or time), or no id | Has a valid id | **adopted**: takes the source's id and name. The message says "name and player restored". |
| Has progress and its own id | A different id | **kept_local**: keeps its own id **and** name, and never takes another player's name |
| Same id | Same id | **same**: the newer name (or removal) wins, by `name_set_unix` |
| Anything | No profile or an invalid id (a pre-3A backup) | **none**: nothing changes |

A non-empty local id is never replaced while the save has progress.

**Damaged saves:**
- If the newest copy has no profile, the id is looked for in the other copies (`.bak`, `.tmp`, Web mirror) before a new one is made.
- An invalid stored id is replaced and an invalid stored name cleared; both are noted in `load_issues`.

## Isolation

- The QA build's save (`chain_escape_experiencelab_qa_save`) has its own profile.
- The release save (`chain_escape_save_r2`) and the old Friend Test save are byte-identical after QA sessions (tested).
- `?qareset=1` starts a fresh QA save, so it also gets a new id.

## Files

| File | Change |
|---|---|
| `scripts/core/player_profile.gd` (new) | UUID v4, id check, name validation and error texts |
| `scripts/core/player_progress.gd` | `[profile]` read and write, `ensure_identity()` (with recovery from other copies), `set_display_name()`, merge rules |
| `scripts/core/build_flags.gd` | `player_identity()` |
| `scripts/game_manager.gd` | Enables identity, ensures it after load / transfer / restore, Settings name handler, test state (id hash only) |
| `scripts/ui/ui_manager.gd` | Settings YOUR NAME row and note, the native-field zone and polling |
| `scripts/social/social_web.gd` | `set_name_draft()`, `take_name()` |
| `web/social_creator.js` and `export_presets.cfg` (regenerated with `tools/sync_web_head.py`) | Native name dialog (zone `name`, NFC, `dir=auto`, 18 px, SAVE / CANCEL) |
| `tools/profile_check.gd`, `tools/ProfileCheck.tscn` (new) | Headless checks |
| `tools/web_profile_test.mjs` (new) | Browser checks |

## Tests

```
godot --headless --path . res://tools/ProfileCheck.tscn
SHOTS=<dir> node tools/web_profile_test.mjs build/web_qa build/web_friend <previous QA build ZIP>
```

## Real-iPhone checklist (QA build, Safari)

1. Open `…/index.html?experiencelab=6&qareset=1` and open Settings (gear). The **ADD YOUR NAME (OPTIONAL)** row should be there.
2. Tap it. The name field should open with the keyboard up and stay visible above the keyboard.
3. Type a Hebrew name, for example דנה כהן, and tap SAVE. It should show as "YOUR NAME: דנה כהן", reading right to left.
4. Try an emoji name: it is refused with a reason and the old name stays. Then try an Arabic name (محمد) and an English one (Alex O'Neil, typed with the iPhone apostrophe).
4a. Mixed names: Loay לואי, Loay محمد, לואי Alex, Loay لؤي לואי. A 20-character name saves (the counter shows 20 / 20); at 21, SAVE waits.
4b. With Settings open in a level, the coins and TIME / MY BEST are dimmed under the card, and tapping them closes Settings without opening the shop.
5. Tap the row and SAVE with the field empty: the name is removed.
6. Set a name, close Safari completely, reopen `?experiencelab=6` **without** `qareset`: the name should still be there.
7. Check that normal play, audio and the TIME / MY BEST display are unchanged.
