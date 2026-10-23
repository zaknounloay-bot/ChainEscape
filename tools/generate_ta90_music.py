#!/usr/bin/env python3
"""Renders the 90-second Time Attack prototype's music (development only):
data/dev/ta90_audio/music_ta90_<stage>.wav

    python3 tools/generate_ta90_music.py

ONE original theme (tools/generate_music.py's synthesiser and harmony:
family A, C maj7 - Am7 - Fmaj7 - G), rendered as four full mixes. The three
timed stages share key, chords, tempo (112 BPM) and loop length (8 bars,
17.1 s), so a stage change is a cross-fade at the SAME loop position
(scripts/audio/stage_music.gd): the beat never jumps, only the arrangement
grows.

    stage    clock        feel                      what is added
    green    1:30-1:01    light, playful, focused    soft pad, gentle eighth arpeggio, light hats
    orange   1:00-0:31    rhythmic urgency           syncopated arp, pulse bass, kick on 1 and 3,
                                                     claps on 2 and 4, sixteenth hats
    red      0:30-0:00    stronger pulse, tension    sixteenth arp, eighth bass, four-on-the-floor
                                                     kick, a high bell motif, a counter-melody,
                                                     brighter timbre - no alarm sounds
    calm     untimed      softer, calmer             92 BPM: pad, bell arpeggio, a soft choir and
                                                     shimmer, no drums (played after TIME UP if
                                                     the player continues without the clock)

Every voice is synthesised here (sine partials and filtered noise): no
samples, no third-party recordings. Mono, 22050 Hz, loop-marked WAVs that
the .import files compress as QOA, like the game's own music.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_music as gm  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "dev", "ta90_audio")

STAGES = {
    "ta90_green": dict(family="A", bpm=112, arp="eighths", bass="half", kick=[], clap=[], hat=0.022, hat_div=2,
                       pad=0.06, arp_vol=0.07, bright=0.3),
    "ta90_orange": dict(family="A", bpm=112, arp="syncopated", bass="pulse", kick=[0, 2], clap=[1, 3], hat=0.04,
                        hat_div=4, pad=0.055, arp_vol=0.07, bright=0.36),
    "ta90_red": dict(family="A", bpm=112, arp="sixteenths", bass="eighths", kick=[0, 1, 2, 3], clap=[1, 3],
                     hat=0.045, hat_div=4, pad=0.05, arp_vol=0.065, bright=0.45, bells=0.035,
                     lead=[0, 2, 4, 2, 1, 3, 4, 3]),
    "ta90_calm": dict(family="A", bpm=92, arp="bells", bass="half", kick=[], clap=[], hat=0.0, hat_div=2,
                      pad=0.07, arp_vol=0.06, bright=0.25, choir=0.03, shimmer=0.02),
}

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in sys.argv[1:] or list(STAGES):
        gm.render(name, STAGES[name], out_dir=OUT_DIR)
