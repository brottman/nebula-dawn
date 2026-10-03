#!/usr/bin/env python3
"""Chiptune loop generator for Nebula Dawn.

Renders a seamless 16-bar / 125 BPM chiptune loop (~30.7s, matching the length of
the existing stage tracks) to WAV, using only the Python standard library.

    python3 tools/compose_chiptune.py docs/previews/chiptune_demo.wav

Then encode for the game:
    ffmpeg -y -i chiptune_demo.wav -codec:a libmp3lame -b:a 192k chiptune_demo.mp3
"""

import array
import math
import random
import sys
import wave

SR = 44100
BPM = 125.0
BEAT = 60.0 / BPM
STEP = BEAT / 4.0          # 16th note
BARS = 16
STEPS = BARS * 16
LENGTH = STEPS * STEP      # 30.72s


def midi(n):
    return 440.0 * (2.0 ** ((n - 69) / 12.0))


def env(i, n, atk, dec, sus, rel):
    """Simple linear ADSR in samples."""
    if i < atk:
        return i / max(1, atk)
    if i < atk + dec:
        return 1.0 - (1.0 - sus) * ((i - atk) / max(1, dec))
    if i < n - rel:
        return sus
    return sus * max(0.0, (n - i) / max(1, rel))


def _osc(phase, kind, duty):
    p = phase - math.floor(phase)
    if kind == 0:                      # square / pulse
        return 1.0 if p < duty else -1.0
    if kind == 1:                      # triangle
        return 4.0 * abs(p - 0.5) - 1.0
    if kind == 2:                      # saw
        return 2.0 * p - 1.0
    return 0.0


class Track:
    """Mono float buffer of LENGTH seconds."""

    def __init__(self):
        self.buf = [0.0] * int(LENGTH * SR)

    def note(self, start_step, dur_steps, freq, amp, kind, duty=0.5,
             atk=0.004, dec=0.03, sus=0.7, rel=0.04, vibrato=0.0, seed=0):
        s0 = int(start_step * STEP * SR)
        n = int(dur_steps * STEP * SR)
        if n <= 0 or s0 >= len(self.buf):
            return
        a = max(1, int(atk * SR))
        d = max(1, int(dec * SR))
        r = max(1, int(rel * SR))
        rng = random.Random(seed)
        phase = 0.0
        buf = self.buf
        end = min(len(buf), s0 + n)
        for i in range(end - s0):
            e = env(i, n, a, d, sus, r)
            f = freq
            if vibrato > 0.0:
                f *= 1.0 + vibrato * math.sin(2.0 * math.pi * 5.5 * (i / SR))
            phase += f / SR
            buf[s0 + i] += _osc(phase, kind, duty) * amp * e

    def noise(self, start_step, dur_steps, amp, decay, bright=1.0, seed=1):
        s0 = int(start_step * STEP * SR)
        n = int(dur_steps * STEP * SR)
        if n <= 0 or s0 >= len(self.buf):
            return
        rng = random.Random(seed)
        buf = self.buf
        prev = 0.0
        for i in range(min(n, len(buf) - s0)):
            t = i / SR
            e = math.exp(-t / max(0.001, decay))
            w = rng.uniform(-1.0, 1.0)
            # cheap high-pass: difference of noise against a slow follower
            prev = prev * 0.72 + w * 0.28
            sample = (w - prev * (1.0 - bright))
            buf[s0 + i] += sample * amp * e

    def kick(self, start_step, amp=0.9):
        s0 = int(start_step * STEP * SR)
        n = int(0.14 * SR)
        buf = self.buf
        phase = 0.0
        for i in range(min(n, len(buf) - s0)):
            t = i / SR
            f = 48.0 + 120.0 * math.exp(-t / 0.03)
            phase += f / SR
            e = math.exp(-t / 0.045)
            buf[s0 + i] += math.sin(2.0 * math.pi * phase) * amp * e


# ---------------------------------------------------------------------------
# Arrangement
# ---------------------------------------------------------------------------
# 2 bars per chord: Am F C G Am F C G
CHORDS = [
    ("Am", 45, [69, 72, 76, 81]),
    ("F", 41, [65, 69, 72, 77]),
    ("C", 48, [72, 76, 79, 84]),
    ("G", 43, [67, 71, 74, 79]),
]
# 8 chords, 2 bars each
PROGRESSION = CHORDS * 2

bass = Track()
arp = Track()
lead = Track()
pad = Track()
drums = Track()

for bar in range(BARS):
    name, root, tones = PROGRESSION[bar // 2]
    base_step = bar * 16
    bass_root = root - 12

    # --- bass: driving 8ths with an octave lift on the off-beat ---
    for s in range(0, 16, 2):
        note = bass_root + (12 if s in (6, 14) else 0)
        bass.note(base_step + s, 1.7, midi(note), 0.34, 0, duty=0.5,
                  atk=0.002, dec=0.02, sus=0.55, rel=0.02)

    # --- arp: chord tones with rests, so it grooves instead of walling ---
    pattern = [0, 1, 2, 3, 2, 1, -1, 2, 0, 1, 2, 3, -1, 2, 1, 0]
    for s in range(16):
        idx = pattern[s]
        if idx < 0:
            continue
        n = tones[idx]
        arp.note(base_step + s, 0.9, midi(n), 0.11, 0, duty=0.25,
                 atk=0.001, dec=0.012, sus=0.4, rel=0.012, seed=bar * 16 + s)

    # --- pad: soft chord swell on the downbeat ---
    for n in tones[:3]:
        pad.note(base_step, 15.0, midi(n), 0.045, 1, atk=0.06, dec=0.2,
                 sus=0.8, rel=0.25)

    # --- chord stab on the "and" of 2 and 4 ---
    for s in (2, 10):
        for n in tones[:3]:
            arp.note(base_step + s, 0.9, midi(n - 12), 0.07, 0, duty=0.5,
                     atk=0.001, dec=0.02, sus=0.3, rel=0.02)

    # --- drums ---
    drums.kick(base_step + 0, 0.95)
    drums.kick(base_step + 8, 0.85)
    if bar % 4 == 3:
        drums.kick(base_step + 14, 0.6)
    for s in (4, 12):
        drums.noise(base_step + s, 0.7, 0.5, 0.09, bright=0.6, seed=bar * 32 + s)
    for s in range(0, 16, 2):
        drums.noise(base_step + s, 0.3, 0.16, 0.025, bright=1.0, seed=bar * 40 + s)
    # open hat / crash at the top of each 8-bar phrase
    if bar % 8 == 0:
        drums.noise(base_step, 2.0, 0.22, 0.28, bright=1.0, seed=bar + 900)

# --- lead melody: 8-bar phrase, repeated an octave up for the back half ---
LEAD = [
    (0, 4, 69), (4, 2, 72), (6, 2, 76), (8, 4, 74), (12, 4, 72),
    (16, 6, 69), (22, 2, 67), (24, 8, 69),
    (32, 4, 69), (36, 4, 72), (40, 4, 69), (44, 4, 65),
    (48, 8, 67), (56, 4, 71), (60, 4, 74),
    (64, 4, 69), (68, 2, 72), (70, 2, 76), (72, 4, 74), (76, 4, 72),
    (80, 6, 69), (86, 2, 67), (88, 8, 69),
    (96, 4, 72), (100, 4, 76), (104, 4, 79), (108, 4, 76),
    (112, 8, 74), (120, 8, 71),
]
for (s, d, n) in LEAD:
    lead.note(s, d, midi(n), 0.28, 0, duty=0.125,
              atk=0.006, dec=0.05, sus=0.62, rel=0.06, vibrato=0.006, seed=s)
for (s, d, n) in LEAD:
    lead.note(s + 128, d, midi(n + 12), 0.22, 0, duty=0.125,
              atk=0.006, dec=0.05, sus=0.62, rel=0.06, vibrato=0.006, seed=s + 1)

# ---------------------------------------------------------------------------
# Mix -> stereo -> soft clip -> 16-bit WAV
# ---------------------------------------------------------------------------
tracks = [(bass, 0.0), (arp, 0.28), (lead, 0.0), (pad, -0.2), (drums, 0.0)]
n = int(LENGTH * SR)
left = [0.0] * n
right = [0.0] * n
for tr, pan in tracks:
    gl = math.sqrt(0.5 * (1.0 - pan))
    gr = math.sqrt(0.5 * (1.0 + pan))
    for i in range(n):
        v = tr.buf[i]
        left[i] += v * gl
        right[i] += v * gr

# normalize + gentle soft clip for a warm, "tape" chip sound
peak = 0.0
for i in range(n):
    peak = max(peak, abs(left[i]), abs(right[i]))
gain = (0.89 / peak) if peak > 0.0 else 1.0
out = array.array("h", [0]) * (n * 2)
for i in range(n):
    l = math.tanh(left[i] * gain * 1.1)
    r = math.tanh(right[i] * gain * 1.1)
    out[i * 2] = int(max(-1.0, min(1.0, l)) * 32767)
    out[i * 2 + 1] = int(max(-1.0, min(1.0, r)) * 32767)

path = sys.argv[1] if len(sys.argv) > 1 else "chiptune_demo.wav"
with wave.open(path, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(out.tobytes())
print("wrote %s (%.2fs, %d Hz stereo)" % (path, LENGTH, SR))
