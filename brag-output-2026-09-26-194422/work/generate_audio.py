"""
Generate the brag soundtrack: one 20-second piece where every effect sits in the
same key and space as the pad. Polished: no harsh transients, no sudden dips.

Key: A minor. Pad = A2 + E3 + A3 (fifths); sub = A1. Bell partials use just-
intoned triads over the pad. Whooshes are filtered noise sweeps sitting -18dB
under the mix.

Output: work/audio/track.wav  (stereo, 48kHz, 16-bit)
"""
from __future__ import annotations
import math
import struct
import wave
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parent / "audio" / "track.wav"
OUT.parent.mkdir(parents=True, exist_ok=True)

SR = 48000
DUR = 20.0
N = int(SR * DUR)
t = np.arange(N) / SR


def env_adsr(dur_frames, attack, decay, sustain, release, sustain_level=0.7):
    """Simple ADSR envelope, all in frames. Returns np array of shape (dur_frames,)."""
    e = np.zeros(dur_frames)
    a = int(attack); d = int(decay); s = int(sustain); r = int(release)
    total = a + d + s + r
    if total > dur_frames:
        # scale down
        scale = dur_frames / total
        a = int(a * scale); d = int(d * scale); s = int(s * scale); r = int(r * scale)
    idx = 0
    if a > 0:
        e[idx:idx + a] = np.linspace(0, 1, a)
        idx += a
    if d > 0:
        e[idx:idx + d] = np.linspace(1, sustain_level, d)
        idx += d
    if s > 0:
        e[idx:idx + s] = sustain_level
        idx += s
    if r > 0:
        e[idx:idx + r] = np.linspace(sustain_level, 0, r)
        idx += r
    return e


def sine(f, phase=0.0):
    return np.sin(2 * math.pi * f * t + phase)


def sine_at(f, start_s, dur_s, phase=0.0):
    """Sine that starts at start_s and lasts dur_s. Returns full-length signal."""
    n = int(dur_s * SR)
    s = int(start_s * SR)
    e = min(s + n, N)
    n_actual = e - s
    tt = np.arange(n_actual) / SR
    seg = np.sin(2 * math.pi * f * tt + phase)
    out = np.zeros(N)
    out[s:e] = seg
    return out


def add(base, seg):
    if len(seg) < N:
        base[:len(seg)] += seg
    else:
        base += seg[:N]


# ---------- pad (drone, layered fifths, subtle chorus) ----------
def build_pad():
    A2 = 110.0
    E3 = 164.8138
    A3 = 220.0
    A1 = 55.0
    # slow LFOs to detune slightly for a warm chorus (0.15 Hz, ±3 cents)
    lfo1 = 0.5 * np.sin(2 * math.pi * 0.13 * t)
    lfo2 = 0.5 * np.sin(2 * math.pi * 0.19 * t + 1.1)
    lfo3 = 0.5 * np.sin(2 * math.pi * 0.11 * t + 0.4)
    cents = lambda c: 2 ** (c / 1200.0)

    def drone(f, l, amp):
        f_t = f * cents(l * 4)  # ±4 cents wobble
        # instantaneous frequency -> integrate phase
        phase = 2 * math.pi * np.cumsum(f_t) / SR
        return amp * np.sin(phase)

    pad = (
        drone(A2, lfo1, 0.14)
        + drone(E3, lfo2, 0.10)
        + drone(A3, lfo3, 0.06)
        + 0.05 * np.sin(2 * math.pi * A1 * t)  # sub
    )
    # gentle high-shelf softening: subtract a small amount of the high freqs (rough EQ)
    # simple 1-pole lowpass at ~4kHz
    alpha = 1 - math.exp(-2 * math.pi * 4000 / SR)
    lp = np.zeros(N)
    prev = 0.0
    for i in range(N):
        prev = prev + alpha * (pad[i] - prev)
        lp[i] = prev
    pad = 0.7 * lp + 0.3 * pad
    # long attack, long release master envelope
    env = np.ones(N)
    fade_in = int(0.6 * SR)
    fade_out = int(1.2 * SR)
    env[:fade_in] = np.linspace(0, 1, fade_in)
    env[-fade_out:] = np.linspace(1, 0, fade_out)
    return pad * env


# ---------- bell (soft attack, long decay, additive) ----------
def bell(freq, start_s, dur_s=3.0, amp=0.16):
    """Additive bell: fundamental + minor-third + fifth partials with fast decay each."""
    partials = [
        (1.00, 1.00, 3.0),   # (mult, amp_ratio, decay_s)
        (2.00, 0.38, 2.2),
        (3.00, 0.22, 1.6),
        (4.00, 0.10, 1.0),
    ]
    out = np.zeros(N)
    n = int(dur_s * SR)
    s = int(start_s * SR)
    e = min(s + n, N)
    n_actual = e - s
    tt = np.arange(n_actual) / SR
    for mult, ar, decay in partials:
        env = np.exp(-tt / decay)
        # brief soft attack (10ms) to remove click
        atk = int(0.010 * SR)
        env[:atk] *= np.linspace(0, 1, atk)
        out[s:e] += ar * env * np.sin(2 * math.pi * freq * mult * tt)
    return amp * out


# ---------- whoosh (filtered noise sweep, low, in-key) ----------
def whoosh(center_s, dur_s=1.2, amp=0.08, low=140, high=600):
    """A rising then falling band-passed pink-ish noise around a low band, sitting under the pad."""
    n = int(dur_s * SR)
    s = int((center_s - dur_s / 2) * SR)
    e = min(s + n, N)
    n_actual = max(e - s, 1)
    tt = np.arange(n_actual) / SR
    # Pink-ish noise via cumulative filter
    noise = np.random.default_rng(seed=int(center_s * 1000)).standard_normal(n_actual)
    # 1-pole lowpass at moving cutoff (low → high → low)
    cutoff = low + (high - low) * np.sin(math.pi * tt / dur_s) ** 2
    y = np.zeros(n_actual)
    prev = 0.0
    for i in range(n_actual):
        a = 1 - math.exp(-2 * math.pi * cutoff[i] / SR)
        prev = prev + a * (noise[i] - prev)
        y[i] = prev
    # bandpass rough: subtract a lower LP to remove sub-rumble
    prev2 = 0.0
    y2 = np.zeros(n_actual)
    for i in range(n_actual):
        a = 1 - math.exp(-2 * math.pi * 70 / SR)
        prev2 = prev2 + a * (noise[i] - prev2)
        y2[i] = prev2
    y = y - 0.6 * y2
    # amp envelope: bell curve
    env = np.sin(math.pi * tt / dur_s) ** 2
    seg = amp * y * env
    out = np.zeros(N)
    out[s:e] = seg
    return out


# ---------- pink noise bed ----------
def pink_bed():
    rng = np.random.default_rng(42)
    white = rng.standard_normal(N)
    # simple pinking via 3 cascaded 1-pole filters at spread cutoffs
    def lp(x, fc):
        a = 1 - math.exp(-2 * math.pi * fc / SR)
        y = np.zeros_like(x)
        prev = 0.0
        for i in range(len(x)):
            prev = prev + a * (x[i] - prev)
            y[i] = prev
        return y
    b1 = lp(white, 3000)
    b2 = lp(white, 800)
    b3 = lp(white, 200)
    pink = 0.5 * b1 + 0.3 * b2 + 0.2 * b3
    pink /= (np.max(np.abs(pink)) + 1e-9)
    # sit at -30 dB roughly
    env = np.ones(N)
    fade = int(0.8 * SR)
    env[:fade] = np.linspace(0, 1, fade)
    env[-fade:] = np.linspace(1, 0, fade)
    return 0.030 * pink * env


# ---------- build the mix ----------
def build():
    print("pad...")
    pad = build_pad()
    print("pink...")
    bed = pink_bed()

    mix = pad + bed

    # scene entry bells: (start_s, freq)
    # keys in A minor: A(220,440,880), C(261,523,1046), E(164,329,659)
    print("bells...")
    bell_events = [
        (0.15, 880.0, 0.14),   # S1: A5
        (3.15, 1046.5, 0.11),  # S2: C6 (minor third above)
        (8.15, 659.25, 0.10),  # S3: E5 (fifth of A)
        (12.65, 880.0, 0.10),  # S4: A5 again, a touch brighter
        (17.15, 440.0, 0.14),  # S5: A4, warmer for the outro
    ]
    for start, f, amp in bell_events:
        mix += bell(f, start, dur_s=3.5, amp=amp)

    # whooshes at reveal moments (S1→S2 and S3→S4), quiet
    print("whooshes...")
    mix += whoosh(3.0, dur_s=1.0, amp=0.07)
    mix += whoosh(12.5, dur_s=1.0, amp=0.06)

    # soft high-frequency bloom at the wordmark landing (t=1.9) & outro (t=17.9)
    print("shimmer...")
    for start in [1.9, 17.9]:
        mix += bell(1760.0, start, dur_s=2.5, amp=0.045)
        mix += bell(1318.5, start, dur_s=2.5, amp=0.035)

    # normalize peak to -6 dBFS
    peak = np.max(np.abs(mix))
    if peak > 0:
        target = 10 ** (-6 / 20)
        mix = mix * (target / peak)

    # gentle limiter (soft tanh) to catch any transients
    mix = np.tanh(mix * 1.05) * 0.95

    # tiny stereo width via haas: right channel delayed 6ms and slightly EQ'd
    delay_samps = int(0.006 * SR)
    left = mix.copy()
    right = np.concatenate([np.zeros(delay_samps), mix[:-delay_samps]])
    # blend so overall mono compat is good
    stereo = np.stack([0.85 * left + 0.15 * right,
                       0.15 * left + 0.85 * right], axis=1)

    # master fade
    fade_in = int(0.5 * SR)
    fade_out = int(0.8 * SR)
    stereo[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    stereo[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]

    return np.clip(stereo, -1.0, 1.0)


def write_wav(path: Path, stereo: np.ndarray):
    ints = (stereo * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(ints.tobytes())


if __name__ == "__main__":
    stereo = build()
    write_wav(OUT, stereo)
    print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.1f} KB)")
