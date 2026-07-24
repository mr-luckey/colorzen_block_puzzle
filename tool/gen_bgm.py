"""Generate soft addictive looping BGM for ColorZen."""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
BPM = 78
BEAT = 60.0 / BPM
BARS = 8
DURATION = BARS * 4 * BEAT
N = int(DURATION * SR)

random.seed(42)


def midi_to_hz(m: float) -> float:
    return 440.0 * (2 ** ((m - 69) / 12.0))


def env_adsr(t: float, dur: float, a=0.02, d=0.12, s=0.65, r=0.25) -> float:
    if t < 0 or t > dur:
        return 0.0
    if t < a:
        return t / max(a, 1e-9)
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / max(d, 1e-9))
    sustain_end = max(a + d, dur - r)
    if t < sustain_end:
        return s
    return s * max(0.0, 1.0 - (t - sustain_end) / max(r, 1e-9))


def soft_sin(phase: float) -> float:
    return (
        math.sin(phase)
        + 0.18 * math.sin(2 * phase)
        + 0.06 * math.sin(3 * phase)
    )


def soft_tri(phase: float) -> float:
    x = math.sin(phase)
    return x + 0.12 * math.sin(3 * phase)


# Dreamy progression: Fmaj7 - Dm9 - Bbmaj7 - Cadd9
chords = [
    [53, 57, 60, 64],
    [50, 53, 57, 60, 64],
    [46, 50, 53, 57],
    [48, 52, 55, 62],
]

melody_degrees = [
    [0, 2, 4, 7, 4, 2, 0, 4],
    [0, 4, 7, 9, 7, 4, 2, 0],
    [0, 2, 5, 7, 5, 2, 0, 2],
    [0, 4, 5, 7, 9, 7, 5, 4],
]


def chord_tones(ci: int) -> list[int]:
    base = chords[ci]
    return sorted(set(base + [n + 12 for n in base]))


def pick_melody_note(ci: int, degree_idx: int, degrees: list[int]) -> int:
    tones = chord_tones(ci)
    di = degrees[degree_idx % len(degrees)]
    idx = (di // 2) % len(tones)
    n = tones[idx]
    while n < 60:
        n += 12
    while n > 76:
        n -= 12
    return n


buf = [0.0] * N

# Soft pad
for bar in range(BARS):
    ci = bar % 4
    start = int(bar * 4 * BEAT * SR)
    dur = 4 * BEAT
    for note in chords[ci]:
        freq = midi_to_hz(note)
        for det, amp in ((0.0, 0.11), (0.12, 0.07), (-0.09, 0.06)):
            f = freq * (2 ** (det / 1200.0))
            for i in range(int(dur * SR)):
                t = i / SR
                e = env_adsr(t, dur, a=0.35, d=0.4, s=0.55, r=0.9)
                trem = 0.92 + 0.08 * math.sin(2 * math.pi * 0.35 * t + note)
                phase = 2 * math.pi * f * t
                idx = start + i
                if idx >= N:
                    break
                buf[idx] += soft_sin(phase) * e * amp * trem

# Soft bass
bass_notes = [41, 38, 34, 36]
for bar in range(BARS):
    note = bass_notes[bar % 4]
    start = int(bar * 4 * BEAT * SR)
    for h in range(2):
        hs = start + int(h * 2 * BEAT * SR)
        dur = 2 * BEAT * 0.95
        freq = midi_to_hz(note)
        for i in range(int(dur * SR)):
            t = i / SR
            e = env_adsr(t, dur, a=0.02, d=0.25, s=0.5, r=0.35)
            phase = 2 * math.pi * freq * t
            s = math.sin(phase) + 0.25 * math.sin(2 * phase) * math.exp(-t * 2.5)
            idx = hs + i
            if idx >= N:
                break
            buf[idx] += s * e * 0.16

# Soft addictive pluck melody
for bar in range(BARS):
    ci = bar % 4
    degrees = melody_degrees[ci]
    for step in range(8):
        start = int((bar * 4 + step * 0.5) * BEAT * SR)
        note = pick_melody_note(ci, step, degrees)
        if step in (3, 7) and (bar % 2 == 1):
            continue
        dur = BEAT * 0.55
        freq = midi_to_hz(note)
        for i in range(int(dur * SR)):
            t = i / SR
            e = env_adsr(t, dur, a=0.004, d=0.12, s=0.25, r=0.28)
            phase = 2 * math.pi * freq * t
            s = (
                math.sin(phase)
                + 0.35 * math.sin(2 * phase) * math.exp(-t * 6)
                + 0.12 * math.sin(3 * phase) * math.exp(-t * 10)
            )
            s += 0.05 * math.sin(2 * math.pi * freq * 2.01 * t) * math.exp(-t * 8)
            idx = start + i
            if idx >= N:
                break
            buf[idx] += s * e * 0.13

# Quiet counter motif
counter = [72, 76, 79, 76, 74, 72, 69, 72]
for bar in range(0, BARS, 2):
    for step, note in enumerate(counter):
        if step % 2 == 1 and bar % 4 == 2:
            continue
        start = int((bar * 4 + step * 0.5) * BEAT * SR)
        dur = BEAT * 0.4
        freq = midi_to_hz(note)
        for i in range(int(dur * SR)):
            t = i / SR
            e = env_adsr(t, dur, a=0.01, d=0.08, s=0.2, r=0.2)
            phase = 2 * math.pi * freq * t
            s = soft_tri(phase) * math.exp(-t * 3)
            idx = start + i
            if idx >= N:
                break
            buf[idx] += s * e * 0.045

# Soft percussion
for bar in range(BARS):
    for beat in range(4):
        if beat in (0, 2):
            start = int((bar * 4 + beat) * BEAT * SR)
            for i in range(int(0.18 * SR)):
                t = i / SR
                f = 90 * math.exp(-t * 18) + 42
                e = math.exp(-t * 14)
                s = math.sin(2 * math.pi * f * t) * e
                idx = start + i
                if idx < N:
                    buf[idx] += s * 0.07
        if beat in (1, 3):
            start = int((bar * 4 + beat) * BEAT * SR)
            for i in range(int(0.06 * SR)):
                t = i / SR
                noise = random.random() * 2 - 1
                e = math.exp(-t * 55)
                idx = start + i
                if idx < N:
                    buf[idx] += noise * e * 0.018

# Quiet noise bed
for i in range(N):
    n = (random.random() * 2 - 1) * 0.004
    n *= 0.7 + 0.3 * math.sin(2 * math.pi * i / SR * 0.15)
    buf[i] += n

# Seamless loop crossfade
xfade = int(0.35 * SR)
for i in range(xfade):
    a = i / xfade
    end_i = N - xfade + i
    buf[end_i] = buf[end_i] * (1 - a) + buf[i] * a

peak = max(abs(x) for x in buf) or 1.0
gain = 0.42 / peak
out = [math.tanh(x * gain * 1.15) * 0.95 for x in buf]

path = Path(__file__).resolve().parents[1] / "assets" / "audio" / "bgm_colorzen.wav"
with wave.open(str(path), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in out
    )
    w.writeframes(frames)

print(f"Wrote {path} duration={N / SR:.2f}s peak={peak:.3f} size={path.stat().st_size}")
