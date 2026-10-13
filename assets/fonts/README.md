# Fonts for user-written messages (Social)

Fallback fonts for personal messages only; the game UI font is unchanged.
See `scripts/social/message_text.gd`.

| File | Covers | Source |
|---|---|---|
| `NotoSansArabic-SemiBold.woff2` | Arabic (shaping, Arabic-Indic digits) | Noto Sans Arabic, unhinted, converted to WOFF2 |
| `NotoSansHebrew-SemiBold.woff2` | Hebrew | Noto Sans Hebrew, unhinted, converted to WOFF2 |
| `NotoColorEmoji-Subset5.ttf` | 🏆 ❤️ 🔥 ⭐ 🧩 only (colour bitmaps, 11.8 KB) | Noto Color Emoji 2.047, subset with `pyftsubset --unicodes="U+1F3C6,U+2764,U+FE0F,U+1F525,U+2B50,U+1F9E9"`; imported with embedded bitmaps on |

All from https://github.com/notofonts and https://github.com/googlefonts/noto-emoji (The Noto Project Authors), licensed
under the SIL Open Font License 1.1 (`OFL.txt`). SemiBold matches the
weight of the engine's built-in Open Sans SemiBold used on the Web build.
