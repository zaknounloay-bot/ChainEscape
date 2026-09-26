#!/usr/bin/env python3
"""Renders the placeholder music themes: assets/audio/music_<theme>.wav

    python3 tools/generate_music.py            # all themes
    python3 tools/generate_music.py w3 master  # selected themes

One looping theme per World plus a Master Level theme. They share one
engine (pad, pluck arpeggio, bass, drums) and differ in tempo, key, harmony,
rhythmic density and timbre, so difficulty "feels" different without 100
songs:

    w1      calm, welcoming       92 BPM  C major maj7 chords
    w2      rhythmic, focused    100 BPM  A minor, busier arpeggio
    w3      tension, energy      108 BPM  D minor, driving bass, clap
    w4      intense, neon        116 BPM  E minor, 16th arps, brighter timbre
    w5      advanced / master    104 BPM  B minor, wide arps, big pad
    master  Level 100            84 BPM   C minor, bells, deep drums

Everything is rendered into a circular buffer, so note tails wrap around
and each loop is sample-seamless. A RIFF 'smpl' chunk marks the loop so
Godot loops it automatically. Requires numpy.
"""
import os
import struct
import sys
import numpy as np

RATE = 22050
BARS = 8


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


THEMES = {
    "w1": dict(bpm=92, chords=[[48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 59]],
               arp="eighths", bass="half", kick=[0, 2], clap=[], hat=0.035, bright=0.3, pad=0.055, arp_vol=0.075),
    "w2": dict(bpm=100, chords=[[45, 52, 55, 60], [41, 48, 52, 57], [48, 52, 55, 60], [43, 50, 55, 59]],
               arp="syncopated", bass="pulse", kick=[0, 1.5, 2], clap=[], hat=0.04, bright=0.35, pad=0.05, arp_vol=0.075),
    "w3": dict(bpm=108, chords=[[50, 57, 60, 65], [46, 53, 58, 62], [41, 48, 53, 57], [48, 55, 60, 64]],
               arp="eighths_up", bass="eighths", kick=[0, 1, 2, 3], clap=[1, 3], hat=0.045, bright=0.45, pad=0.045, arp_vol=0.07),
    "w4": dict(bpm=116, chords=[[52, 59, 64, 67], [48, 55, 60, 64], [43, 50, 55, 59], [50, 57, 62, 66]],
               arp="sixteenths", bass="eighths", kick=[0, 1, 2, 3], clap=[1, 3], hat=0.05, bright=0.7, pad=0.04, arp_vol=0.06),
    "w5": dict(bpm=104, chords=[[47, 54, 59, 62], [43, 50, 55, 59], [50, 57, 62, 66], [45, 52, 57, 61]],
               arp="wide", bass="pulse", kick=[0, 2, 2.5], clap=[1, 3], hat=0.04, bright=0.5, pad=0.07, arp_vol=0.07),
    "master": dict(bpm=84, chords=[[48, 55, 60, 63], [44, 51, 56, 60], [51, 58, 63, 67], [43, 50, 55, 59]],
                   arp="bells", bass="half", kick=[0, 2.5], clap=[2], hat=0.02, bright=0.4, pad=0.08, arp_vol=0.08),
}


def render(name, cfg):
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

    def kick(dur=0.35):
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
    for bar in range(BARS):
        chord = cfg["chords"][bar % 4]
        t0 = bar * 4 * beat
        for note in chord[1:]:
            add(t0, cfg["pad"] * tone(midi(note), 4 * beat + 0.6, [(1, 1.0), (2, 0.15)], attack=0.6, release=0.9, detune=0.004))
        # Bass
        pattern = {"half": [(0, 1.6), (2, 1.4)], "pulse": [(0, 0.9), (1.5, 0.45), (2, 0.9), (3.5, 0.45)],
                   "eighths": [(i * 0.5, 0.42) for i in range(8)]}[cfg["bass"]]
        for bt, ln in pattern:
            add(t0 + bt * beat, 0.2 * tone(midi(chord[0] - 12), ln * beat, [(1, 1.0), (2, 0.3)], attack=0.01, decay=0.4, release=0.06))
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
        else:  # eighths (w1)
            pat = [0, 1, 2, 3, 4, 3, 2, 1] if bar < 4 else [0, 2, 4, 3, 1, 3, 4, 2]
            steps = [(i * 0.5, tones[pat[i] % len(tones)]) for i in range(8)]
        for k, (bt, note) in enumerate(steps):
            vel = cfg["arp_vol"] * (1.0 if k % 2 == 0 else 0.75)
            dec = 0.9 if style == "bells" else 0.16
            add(t0 + bt * beat, vel * tone(midi(note + 12), 1.2 if style == "bells" else 0.5, pluck, decay=dec))
        # Drums
        for bt in cfg["kick"]:
            add(t0 + bt * beat, 0.28 * kick(0.5 if name == "master" else 0.35))
        for bt in cfg["clap"]:
            add(t0 + bt * beat, 0.05 * noise(0.18, 22))
        sub = 4 if style == "sixteenths" else 2
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
    print("wrote %-40s %.1fs  loop edge jump %.3f" % (os.path.normpath(out), length / RATE, edge))


if __name__ == "__main__":
    names = sys.argv[1:] or list(THEMES)
    for n in names:
        render(n, THEMES[n])
