#!/usr/bin/env python3
"""Renders the placeholder music themes: assets/audio/music_<theme>.wav

    python3 tools/generate_music.py            # all themes
    python3 tools/generate_music.py c03 master # selected themes

v0.5: one music identity per Chapter (c01..c10) plus the Master Level.
Not ten unrelated songs: five harmonic FAMILIES (key + chord loop), each
rendered twice at rising intensity. The second Chapter of a family keeps
the harmony and adds tempo, percussion and layers, so progress is heard
as "the same world, getting more focused":

    family  chapter  feel                 BPM  what changes
    A (C)   c01      light, welcoming      88  soft pad, gentle arpeggio
            c02      playful              100  bouncy bass, syncopated arp, light claps
    B (Am)  c03      focused               96  steady arp, soft 16th hats
            c04      more rhythmic        108  four-on-the-floor, claps, eighth bass
    C (Dm)  c05      strategic tension    100  suspended chords, bell motif, pulse bass
            c06      deeper, serious       94  lower register, long pad, deep kick
    D (Em)  c07      energetic            118  16th arpeggio, claps, bright timbre
            c08      advanced             122  + counter-melody lead, octave bass
    E (Bm)  c09      intense              126  16th bass, snare fills, double kick
            c10      master, premium      112  majestic pad, bells + shimmer layer
    master  L100     the finale            84  C minor bells, choir pad, deep drums

Everything is rendered into a circular buffer, so note tails wrap around
and each loop is sample-seamless. A RIFF 'smpl' chunk marks the loop so
Godot loops it automatically (the .import files compress it as QOA).
Requires numpy.
"""
import os
import struct
import sys
import numpy as np

RATE = 22050
BARS = 8


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


FAMILY = {
    "A": [[48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 59]],   # C maj7 - Am7 - Fmaj7 - G
    "B": [[45, 52, 55, 60], [41, 48, 52, 57], [48, 52, 55, 60], [43, 50, 55, 59]],   # Am - F - C - G
    "C": [[50, 57, 60, 65], [46, 53, 58, 62], [48, 55, 60, 65], [45, 52, 57, 61]],   # Dm - Bb - Csus - A
    "D": [[52, 59, 64, 67], [48, 55, 60, 64], [43, 50, 55, 59], [50, 57, 62, 66]],   # Em - C - G - D
    "E": [[47, 54, 59, 62], [43, 50, 55, 59], [50, 57, 62, 66], [45, 52, 57, 61]],   # Bm - G - D - A
    "M": [[48, 55, 60, 63], [44, 51, 56, 60], [51, 58, 63, 67], [43, 50, 55, 59]],   # Cm - Ab - Eb - G
}

BASE = dict(transpose=0, arp="eighths", bass="half", kick=[0, 2], clap=[], snare_fill=False, hat=0.035,
            hat_div=2, bright=0.3, pad=0.055, arp_vol=0.075, lead=None, shimmer=0.0, choir=0.0, bells=0.0,
            sub=False, kick_len=0.35)

THEMES = {
    "c01": dict(family="A", bpm=88, pad=0.06, arp_vol=0.07, hat=0.02),
    "c02": dict(family="A", bpm=100, arp="syncopated", bass="pulse", kick=[0, 1.5, 2], clap=[1, 3], hat=0.035,
                bright=0.38, arp_vol=0.075),
    "c03": dict(family="B", bpm=96, arp="eighths_up", bass="pulse", kick=[0, 2], hat=0.03, hat_div=4, bright=0.35),
    "c04": dict(family="B", bpm=108, arp="syncopated", bass="eighths", kick=[0, 1, 2, 3], clap=[1, 3], hat=0.045,
                bright=0.45, pad=0.045),
    "c05": dict(family="C", bpm=100, arp="bells", bass="pulse", kick=[0, 2.5], clap=[3], hat=0.03, bright=0.4,
                pad=0.06, bells=0.05),
    "c06": dict(family="C", bpm=94, transpose=-2, arp="wide", bass="half", kick=[0, 2, 2.5], clap=[1, 3], hat=0.03,
                bright=0.35, pad=0.075, sub=True, kick_len=0.5),
    "c07": dict(family="D", bpm=118, arp="sixteenths", bass="eighths", kick=[0, 1, 2, 3], clap=[1, 3], hat=0.05,
                hat_div=4, bright=0.7, pad=0.04, arp_vol=0.06),
    "c08": dict(family="D", bpm=122, transpose=1, arp="sixteenths", bass="octaves", kick=[0, 1, 2, 3], clap=[1, 3],
                hat=0.05, hat_div=4, bright=0.75, pad=0.04, arp_vol=0.055, lead=[0, 2, 4, 2, 5, 4, 2, 1]),
    "c09": dict(family="E", bpm=126, arp="sixteenths", bass="sixteenths", kick=[0, 0.75, 1, 2, 2.75, 3], clap=[1, 3],
                snare_fill=True, hat=0.055, hat_div=4, bright=0.8, pad=0.04, arp_vol=0.05, lead=[4, 2, 0, 2, 4, 5, 4, 2]),
    "c10": dict(family="E", bpm=112, transpose=2, arp="wide", bass="pulse", kick=[0, 2.5], clap=[2], hat=0.035,
                bright=0.5, pad=0.08, arp_vol=0.06, bells=0.06, shimmer=0.03, choir=0.03, sub=True, kick_len=0.5),
    "master": dict(family="M", bpm=84, arp="bells", bass="half", kick=[0, 2.5], clap=[2], hat=0.02, bright=0.4,
                   pad=0.08, arp_vol=0.08, bells=0.05, shimmer=0.035, choir=0.05, sub=True, kick_len=0.5),
}


def render(name, overrides):
    cfg = dict(BASE)
    cfg.update(overrides)
    chords = [[n + cfg["transpose"] for n in ch] for ch in FAMILY[cfg["family"]]]
    rng = np.random.default_rng(7)
    beat = 60.0 / cfg["bpm"]
    length = int(round(BARS * 4 * beat * RATE))
    buf = np.zeros(length)

    def add(start_s, sig):
        i = int(round(start_s * RATE)) % length
        n = len(sig)
        if i + n <= length:
            buf[i:i + n] += sig
            return
        first = length - i
        buf[i:] += sig[:first]
        rest = sig[first:]
        while len(rest):
            k = min(len(rest), length)
            buf[:k] += rest[:k]
            rest = rest[k:]

    def tone(freq, dur, harm, attack=0.005, decay=None, release=0.05, detune=0.0):
        t = np.arange(int(dur * RATE)) / RATE
        s = np.zeros_like(t)
        for mult, amp in harm:
            s += amp * np.sin(2 * np.pi * freq * mult * t)
            if detune:
                s += amp * 0.6 * np.sin(2 * np.pi * freq * mult * (1 + detune) * t)
        env = np.minimum(1.0, t / max(attack, 1e-4))
        if decay:
            env *= np.exp(-t / decay)
        return s * env * np.clip((dur - t) / release, 0, 1)

    def kick(dur):
        t = np.arange(int(dur * RATE)) / RATE
        f = 45 + 70 * np.exp(-t * 28)
        return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 11)

    def noise(dur, decay):
        n = int(dur * RATE)
        x = np.diff(rng.standard_normal(n), prepend=0)
        t = np.arange(n) / RATE
        return x * np.exp(-t * decay) * np.minimum(1, t * 800)

    b = cfg["bright"]
    pluck = [(1, 1.0), (2, 0.3 + b * 0.4), (3, 0.08 + b * 0.25), (4, b * 0.12)]
    bell = [(1, 1.0), (2.76, 0.35), (5.4, 0.12)]
    for bar in range(BARS):
        chord = chords[bar % 4]
        t0 = bar * 4 * beat
        for note in chord[1:]:
            add(t0, cfg["pad"] * tone(midi(note), 4 * beat + 0.6, [(1, 1.0), (2, 0.15)], attack=0.6, release=0.9, detune=0.004))
        if cfg["choir"]:
            for note in chord[1:]:
                add(t0, cfg["choir"] * tone(midi(note + 12), 4 * beat + 0.8, [(1, 1.0), (3, 0.2), (5, 0.08)],
                                            attack=1.0, release=1.0, detune=0.006))
        # Bass
        root = chord[0] - 12
        pattern = {"half": [(0, 1.6), (2, 1.4)], "pulse": [(0, 0.9), (1.5, 0.45), (2, 0.9), (3.5, 0.45)],
                   "eighths": [(i * 0.5, 0.42) for i in range(8)],
                   "octaves": [(i * 0.5, 0.42) for i in range(8)],
                   "sixteenths": [(i * 0.25, 0.22) for i in range(16)]}[cfg["bass"]]
        for k, (bt, ln) in enumerate(pattern):
            n = root + (12 if cfg["bass"] == "octaves" and k % 2 == 1 else 0)
            add(t0 + bt * beat, 0.2 * tone(midi(n), ln * beat, [(1, 1.0), (2, 0.3)], attack=0.01, decay=0.4, release=0.06))
        if cfg["sub"]:
            add(t0, 0.12 * tone(midi(root - 12), 4 * beat, [(1, 1.0)], attack=0.05, release=0.3))
        # Arpeggio
        tones = chord[1:] + [chord[1] + 12, chord[2] + 12]
        style = cfg["arp"]
        if style == "sixteenths":
            steps = [(i * 0.25, tones[[0, 1, 2, 3, 4, 3, 2, 1][i % 8]]) for i in range(16)]
        elif style == "syncopated":
            steps = [(p, tones[k % len(tones)]) for k, p in enumerate([0, 0.75, 1.5, 2, 2.75, 3.5])]
        elif style == "eighths_up":
            steps = [(i * 0.5, tones[i % len(tones)]) for i in range(8)]
        elif style == "wide":
            steps = [(i * 0.5, tones[i % len(tones)] + (12 if i % 4 == 3 else 0)) for i in range(8)]
        elif style == "bells":
            steps = [(i * 1.0, tones[[0, 2, 4, 1][i]] + 12) for i in range(4)]
        else:  # eighths
            pat = [0, 1, 2, 3, 4, 3, 2, 1] if bar < 4 else [0, 2, 4, 3, 1, 3, 4, 2]
            steps = [(i * 0.5, tones[pat[i] % len(tones)]) for i in range(8)]
        for k, (bt, note) in enumerate(steps):
            vel = cfg["arp_vol"] * (1.0 if k % 2 == 0 else 0.75)
            dec = 0.9 if style == "bells" else 0.16
            add(t0 + bt * beat, vel * tone(midi(note + 12), 1.2 if style == "bells" else 0.5, pluck, decay=dec))
        # Bell motif (tension / premium)
        if cfg["bells"]:
            for k, bt in enumerate([0, 1.5, 3]):
                add(t0 + bt * beat, cfg["bells"] * tone(midi(tones[(bar + k) % len(tones)] + 24), 1.4, bell, decay=0.7))
        # Counter-melody lead (advanced chapters)
        if cfg["lead"]:
            seq = cfg["lead"]
            for k in range(8):
                note = tones[seq[(bar * 2 + k) % len(seq)] % len(tones)] + 12
                add(t0 + k * 0.5 * beat, 0.05 * tone(midi(note), 0.45 * beat, [(1, 1.0), (2, 0.5), (3, 0.3)],
                                                      attack=0.01, decay=0.3))
        # Shimmer: soft high sparkles (premium / master)
        if cfg["shimmer"]:
            for k in range(4):
                bt = (k + (0.5 if bar % 2 else 0)) * 1.0
                add(t0 + bt * beat, cfg["shimmer"] * tone(midi(tones[(k * 2 + bar) % len(tones)] + 36), 0.8,
                                                           [(1, 1.0), (2, 0.2)], decay=0.35))
        # Drums
        for bt in cfg["kick"]:
            add(t0 + bt * beat, 0.28 * kick(cfg["kick_len"]))
        for bt in cfg["clap"]:
            add(t0 + bt * beat, 0.05 * noise(0.18, 22))
        if cfg["snare_fill"] and bar % 4 == 3:
            for i in range(4):
                add(t0 + (3 + i * 0.25) * beat, 0.035 * (0.6 + 0.15 * i) * noise(0.12, 30))
        sub = cfg["hat_div"]
        for i in range(4 * sub):
            if i % 2 == 1 or sub == 4:
                add(t0 + i * beat / sub, cfg["hat"] * noise(0.07, 70))

    buf = np.tanh(buf * 1.2)
    buf *= 0.7 / np.max(np.abs(buf))
    pcm = (buf * 32767).astype('<i2').tobytes()
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music_%s.wav" % name)
    fmt = struct.pack('<HHIIHH', 1, 1, RATE, RATE * 2, 2, 16)
    smpl = struct.pack('<9I', 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0) + struct.pack('<6I', 0, 0, 0, length - 1, 0, 0)
    riff = (b'WAVE' + b'fmt ' + struct.pack('<I', len(fmt)) + fmt + b'smpl' + struct.pack('<I', len(smpl)) + smpl
            + b'data' + struct.pack('<I', len(pcm)) + pcm)
    with open(out, 'wb') as f:
        f.write(b'RIFF' + struct.pack('<I', len(riff)) + riff)
    edge = abs(float(buf[0]) - float(buf[-1]))
    print("wrote %-40s %5.1fs  %3d BPM  loop edge jump %.3f" % (os.path.normpath(out), length / RATE, cfg["bpm"], edge))


if __name__ == "__main__":
    names = sys.argv[1:] or list(THEMES)
    for n in names:
        render(n, THEMES[n])
