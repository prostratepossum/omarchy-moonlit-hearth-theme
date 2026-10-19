#!/usr/bin/python3
"""Synthesise the Moonlit Hearth login chime: a faint winter wind with falling
snow hiss, a small glassy sleigh-bell shimmer, then one warm low wooden tone
like a cabin door closing softly. ~4.5 s, stereo WAV, numpy only.
usage: make-hearth-chime.py [out.wav]  (default: ../extras/login.wav)"""

import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
DUR = 4.5
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(11)


def band(x, lo=None, hi=None):
    """Zero-phase FFT band-pass with soft skirts."""
    n = x.shape[-1]
    spec = np.fft.rfft(x, axis=-1)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        g *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(spec * g, n, axis=-1)


def pan(mono, p):
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)])


def norm(x):
    return x / (np.max(np.abs(x)) + 1e-9)


out = np.zeros((2, N))

# --- Wind: low brownish noise, one slow swell, wide stereo.
for ch in range(2):
    w = np.cumsum(rng.standard_normal(N))
    w -= np.convolve(w, np.ones(4410) / 4410, mode="same")
    w = norm(band(w, 150, 700))
    swell = 0.5 + 0.5 * np.sin(np.pi * np.clip(t / DUR, 0, 1)) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.4 * t + ch))
    out[ch] += 0.10 * w * swell

# --- Snow hiss: very faint high noise, like flakes on the window.
for ch in range(2):
    s = norm(band(rng.standard_normal(N), 4000, 9000))
    out[ch] += 0.006 * s * (0.5 + 0.5 * np.sin(2 * np.pi * 0.23 * t + ch * 1.7) ** 2)

# --- Glassy shimmer: a little cluster of tiny bell strikes (inharmonic
# partials, quick decay), drifting left to right, like a distant sleigh bell.
shimmer = np.zeros((2, N))
strikes = [(0.45, 2637.0), (0.62, 3136.0), (0.78, 2793.8), (0.97, 3520.0),
           (1.18, 2349.3), (1.42, 3136.0), (1.70, 2637.0), (2.05, 3951.1)]
for i, (start, f) in enumerate(strikes):
    m = t >= start
    tt = t[m] - start
    env = (1 - np.exp(-tt / 0.003)) * np.exp(-tt / 0.35)
    tone = (np.sin(2 * np.pi * f * tt)
            + 0.5 * np.sin(2 * np.pi * 2.76 * f * tt) * np.exp(-tt / 0.12)
            + 0.25 * np.sin(2 * np.pi * 5.40 * f * tt) * np.exp(-tt / 0.06))
    s = np.zeros(N)
    s[m] = tone * env * (0.6 + 0.4 * rng.random())
    shimmer += pan(s, -0.6 + 1.2 * i / (len(strikes) - 1))
# Soft echo taps for air.
wet = np.zeros_like(shimmer)
for i, (delay, gain) in enumerate([(0.19, 0.4), (0.37, 0.25), (0.61, 0.14)]):
    d = int(delay * SR)
    wet[(i + 1) % 2, d:] += shimmer[i % 2][:-d] * gain
out += 0.030 * (shimmer + band(wet, None, 6000))

# --- Warm wooden tone: a low marimba-like note (fundamental + 4th partial),
# then a fifth above, both soft, landing as the wind settles.
def wood(start, f, level, p):
    m = t >= start
    tt = t[m] - start
    env = (1 - np.exp(-tt / 0.008)) * np.exp(-tt / 0.9)
    tone = np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 3.9 * f * tt) * np.exp(-tt / 0.15)
    s = np.zeros(N)
    s[m] = tone * env * level
    return pan(band(s, 80, 2500), p)

out += 0.11 * wood(2.35, 196.0, 1.0, -0.1)
out += 0.08 * wood(2.75, 293.66, 1.0, 0.15)

# --- Master: fades, quiet peak.
fade = np.clip(t / 0.6, 0, 1) ** 2 * np.clip((DUR - t) / 1.4, 0, 1) ** 1.5
out *= fade
out *= 0.26 / np.max(np.abs(out))

pcm = (np.clip(out.T, -1, 1) * 32767).astype("<i2")
dest = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "extras" / "login.wav"
with wave.open(str(dest), "wb") as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(SR)
    wf.writeframes(pcm.tobytes())
print(dest)
