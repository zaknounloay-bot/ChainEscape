#!/usr/bin/env python3
"""Renders the placeholder background music loop: assets/audio/music.wav

    python3 tools/generate_music.py

Relaxed-but-moving puzzle loop: 96 BPM, 8 bars (Cmaj7 - Am7 - Fmaj7 - G6, twice
with a varied second half), soft pad, pluck arpeggio, round bass, soft kick
and shaker. Everything is rendered into a circular buffer, so note tails
wrap around to the start and the loop is sample-seamless. A RIFF 'smpl'
chunk marks the loop so Godot loops it automatically ("Detect From WAV").

Replace assets/audio/music.wav (or add music.ogg) with real music any time.
Requires numpy.
"""
import os
import struct
import numpy as np

RATE = 22050
BPM = 96
BEAT = 60.0 / BPM
BARS = 8
LENGTH = int(round(BARS * 4 * BEAT * RATE))
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


CHORDS = [  # MIDI notes (root position voicings around middle C)
    [48, 55, 59, 64],  # Cmaj7  C G B E
    [45, 52, 55, 60],  # Am7    A E G C
    [41, 48, 52, 57],  # Fmaj7  F C E A
    [43, 50, 55, 59],  # G6     G D G B -> with E on top in arps
]

buf = np.zeros(LENGTH)


def add(start_s, signal):
    """Mix `signal` at time start_s, wrapping around the loop end."""
    i = int(round(start_s * RATE)) % LENGTH
    n = len(signal)
    end = i + n
    if end <= LENGTH:
        buf[i:end] += signal
    else:
        first = LENGTH - i
        buf[i:] += signal[:first]
        rest = signal[first:]
        while len(rest) > 0:  # tails longer than the loop keep wrapping
            k = min(len(rest), LENGTH)
            buf[:k] += rest[:k]
            rest = rest[k:]


def tone(freq, dur, harmonics=((1, 1.0),), attack=0.005, decay=None, release=0.05, detune=0.0):
    t = np.arange(int(dur * RATE)) / RATE
    s = np.zeros_like(t)
    for mult, amp in harmonics:
        s += amp * np.sin(2 * np.pi * freq * mult * t)
        if detune:
            s += amp * 0.6 * np.sin(2 * np.pi * freq * mult * (1 + detune) * t)
    env = np.minimum(1.0, t / max(attack, 1e-4))
    if decay:
        env *= np.exp(-t / decay)
    rel = np.clip((dur - t) / release, 0, 1)
    return s * env * rel


def kick(dur=0.35):
    t = np.arange(int(dur * RATE)) / RATE
    f = 45 + 70 * np.exp(-t * 28)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * np.exp(-t * 11)


def shaker(dur=0.09):
    n = int(dur * RATE)
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0)  # crude high-pass
    t = np.arange(n) / RATE
    return noise * np.exp(-t * 60) * np.minimum(1, t * 800)


for bar in range(BARS):
    chord = CHORDS[bar % 4]
    bar_t = bar * 4 * BEAT
    # Pad: whole-bar chord, slow attack/release, slightly detuned.
    for note in chord[1:]:
        add(bar_t, 0.055 * tone(midi(note), 4 * BEAT + 0.6, ((1, 1.0), (2, 0.15)),
                                attack=0.6, release=0.9, detune=0.004))
    # Bass: root on beats 1 and 3 (+ pickup on the "and" of 4 in odd bars).
    for beat, length in [(0, 1.6), (2, 1.4)] + ([(3.5, 0.45)] if bar % 2 else []):
        root = chord[0] - 12 if beat < 3.5 else chord[1] - 12
        add(bar_t + beat * BEAT, 0.22 * tone(midi(root), length * BEAT,
                                             ((1, 1.0), (2, 0.25)), attack=0.01, decay=0.5, release=0.08))
    # Arpeggio: 8th notes; second half of the loop uses a varied pattern.
    tones = chord[1:] + [chord[1] + 12, chord[3] + 12 if bar % 4 != 3 else 64 + 12]
    pattern = [0, 1, 2, 3, 4, 3, 2, 1] if bar < 4 else [0, 2, 4, 3, 1, 3, 4, 2]
    for step, idx in enumerate(pattern):
        if bar >= 4 and step in (5,):
            continue  # a breath in the variation
        note = tones[idx % len(tones)] + 12
        vel = 0.075 if step % 2 == 0 else 0.055
        add(bar_t + step * BEAT / 2, vel * tone(midi(note), 0.5,
                                                ((1, 1.0), (2, 0.3), (3, 0.08)), attack=0.004, decay=0.16, release=0.05))
    # Drums: soft kick on 1 and 3, shaker on off-beats.
    for beat in (0, 2):
        add(bar_t + beat * BEAT, 0.28 * kick())
    for eighth in range(8):
        if eighth % 2 == 1:
            add(bar_t + eighth * BEAT / 2, 0.035 * shaker())

# Gentle master: soft-clip and normalize to about -3 dBFS.
buf = np.tanh(buf * 1.2)
buf *= 0.7 / np.max(np.abs(buf))
pcm = (buf * 32767).astype('<i2').tobytes()

out = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music.wav")
fmt = struct.pack('<HHIIHH', 1, 1, RATE, RATE * 2, 2, 16)
# 'smpl' chunk with one forward loop over the whole file.
smpl = struct.pack('<9I', 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
smpl += struct.pack('<6I', 0, 0, 0, LENGTH - 1, 0, 0)
riff = b'WAVE' + b'fmt ' + struct.pack('<I', len(fmt)) + fmt \
    + b'smpl' + struct.pack('<I', len(smpl)) + smpl \
    + b'data' + struct.pack('<I', len(pcm)) + pcm
with open(out, 'wb') as f:
    f.write(b'RIFF' + struct.pack('<I', len(riff)) + riff)
print("wrote %s  (%.1fs, %d Hz, %d KB)" % (os.path.normpath(out), LENGTH / RATE, RATE, len(pcm) // 1024))
