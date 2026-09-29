#!/usr/bin/env python3
"""Sons de ambiente (loops estéreo sem emenda) e alguns efeitos de cenário.

Síntese com cuidado para não soar "genérico": pássaros com espécies
diferentes (trinado, assobio que sobe, gorjeio com vibrato, chamado de dois
tons), vento com rajadas e assobios ressonantes, chuva com gotas individuais,
caverna com gotas e ECO (reverb Schroeder), sapos, insetos, grilos, coruja,
fogo crepitando, tambores de guerra ao longe, sino distante na cidade.

  assets/audio/ambience/<id>.ogg   loops de ~40 s (id = floresta, vento,
      chuva, caverna, pantano, deserto, noite, guerra, salao, ceu)
  assets/audio/sfx/g_birds_*.ogg, g_thunder_*.ogg, g_rumble_*.ogg

Uso: python3 tools/build_ambience.py [id ...]   Requer: numpy, scipy, soundfile
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 32000
LOOP = 40.0
XF = 4.0
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio", "ambience")
SFX = os.path.join(ROOT, "assets", "audio", "sfx")


def rng_for(name):
    return np.random.default_rng(abs(hash(name)) % (2 ** 32))


def t_axis(d):
    return np.arange(int(SR * d)) / SR


def lp(x, f, order=2):
    b, a = signal.butter(order, min(f / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, min(f / (SR / 2), 0.99), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def pink(n, rng):
    w = rng.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, w) * 4.0


def brown(n, rng):
    w = np.cumsum(rng.standard_normal(n))
    w = hp(w, 20)
    return w / (np.max(np.abs(w)) + 1e-9)


def slow_lfo(n, rng, rate=0.1, depth=1.0):
    k = max(4, int(n / SR * rate * 4))
    pts = rng.random(k + 1)
    x = np.linspace(0, k, n)
    i = np.floor(x).astype(int)
    f = x - i
    f = (1 - np.cos(f * np.pi)) / 2
    i = np.minimum(i, k - 1)
    return (pts[i] * (1 - f) + pts[i + 1] * f) * depth


def env(n, a, d):
    t = np.arange(n) / SR
    return np.clip(t / max(a, 1e-4), 0, 1) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4))


def place(buf, x, at, pan=0.0, gain=1.0):
    """Soma o som mono `x` no buffer estéreo em `at` segundos (com pan)."""
    s = int(at * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(x))
    l = np.cos((pan + 1) * np.pi / 4) * gain
    r = np.sin((pan + 1) * np.pi / 4) * gain
    buf[s:e, 0] += x[: e - s] * l
    buf[s:e, 1] += x[: e - s] * r


def reverb(x, size=1.0, wet=0.35, damp=3000):
    """Reverb de Schroeder (4 pentes em paralelo + 2 passa-tudo), mono."""
    combs = [int(d * size) for d in (1116, 1188, 1277, 1356)]
    out = np.zeros_like(x)
    for dl in combs:
        dl = int(dl * SR / 44100)
        a = np.zeros(dl + 1)
        a[0] = 1
        a[dl] = -0.84
        out += signal.lfilter([1], a, lp(x, damp, 1))
    out /= len(combs)
    for dl, g in ((556, 0.5), (441, 0.5)):
        dl = int(dl * size * SR / 44100)
        b = np.zeros(dl + 1)
        a = np.zeros(dl + 1)
        b[0] = -g
        b[dl] = 1
        a[0] = 1
        a[dl] = -g
        out = signal.lfilter(b, a, out)
    return x * (1 - wet) + out * wet * 2.2


def stereo_reverb(buf, size, wet, damp=3000):
    out = np.zeros_like(buf)
    out[:, 0] = reverb(buf[:, 0], size, wet, damp)
    out[:, 1] = reverb(buf[:, 1], size * 1.07, wet, damp)
    return out


# ---------------------------------------------------------------------------
# Vozes
# ---------------------------------------------------------------------------

def chirp(f0, f1, dur, rng, harm=0.15, vib=0.0):
    t = t_axis(dur)
    f = np.linspace(f0, f1, len(t)) + (np.sin(2 * np.pi * 28 * t) * vib if vib else 0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return (np.sin(ph) + harm * np.sin(2 * ph)) * e


def bird_call(rng, species):
    parts = []
    if species == "trill":
        base = rng.uniform(3200, 4800)
        n = int(rng.integers(6, 14))
        for i in range(n):
            parts.append(chirp(base * 1.08, base * 0.92, 0.035, rng))
            parts.append(np.zeros(int(SR * 0.025)))
    elif species == "whistle":
        f = rng.uniform(1800, 2600)
        parts.append(chirp(f, f * 1.45, rng.uniform(0.25, 0.45), rng, 0.05))
        parts.append(np.zeros(int(SR * 0.08)))
        parts.append(chirp(f * 1.3, f * 0.95, 0.2, rng, 0.05))
    elif species == "warble":
        f = rng.uniform(2400, 3400)
        for i in range(int(rng.integers(3, 6))):
            g = f * rng.uniform(0.85, 1.25)
            parts.append(chirp(g, g * rng.uniform(0.8, 1.3), rng.uniform(0.07, 0.14), rng, 0.2, vib=rng.uniform(60, 180)))
            parts.append(np.zeros(int(SR * rng.uniform(0.02, 0.06))))
    else:  # dois tons (tipo "fi-o")
        f = rng.uniform(2800, 3600)
        parts.append(chirp(f, f, 0.16, rng, 0.08))
        parts.append(np.zeros(int(SR * 0.06)))
        parts.append(chirp(f * 0.78, f * 0.74, 0.22, rng, 0.08))
    x = np.concatenate(parts)
    return hp(x, 1200) * 0.5


def wind(n, rng, lo=180, hi=900, gust=0.6):
    base = pink(n, rng)
    cut = lo + (hi - lo) * slow_lfo(n, rng, 0.15)
    # filtro variável aproximado: mistura de duas bandas conforme o LFO
    a = lp(base, lo)
    b = lp(base, hi)
    k = (cut - lo) / (hi - lo)
    x = a * (1 - k) + b * k
    amp = 0.4 + gust * slow_lfo(n, rng, 0.2)
    return x * amp


def whistle_wind(n, rng):
    t = np.arange(n) / SR
    f = 700 + 500 * slow_lfo(n, rng, 0.25)
    ph = 2 * np.pi * np.cumsum(f) / SR
    amp = np.maximum(slow_lfo(n, rng, 0.3) - 0.55, 0) * 0.5
    return np.sin(ph) * amp * 0.15


def drip(rng):
    f = rng.uniform(1300, 2600)
    d = 0.12
    t = t_axis(d)
    ff = f * (1 + 0.8 * np.exp(-t / 0.01))
    x = np.sin(2 * np.pi * np.cumsum(ff) / SR) * env(len(t), 0.001, 0.035)
    return x * 0.5


def frog(rng):
    n = int(rng.integers(5, 12))
    f = rng.uniform(140, 260)
    pulses = []
    for i in range(n):
        t = t_axis(0.03)
        pulses.append(np.sin(2 * np.pi * f * t) * np.sin(np.pi * t / 0.03) + 0.3 * np.sign(np.sin(2 * np.pi * f * 2 * t)) * np.sin(np.pi * t / 0.03))
        pulses.append(np.zeros(int(SR * 0.018)))
    return lp(np.concatenate(pulses), 900) * 0.5


def cricket(rng):
    f = rng.uniform(4200, 5200)
    out = []
    for i in range(3):
        t = t_axis(0.02)
        out.append(np.sin(2 * np.pi * f * t) * np.sin(np.pi * t / 0.02))
        out.append(np.zeros(int(SR * 0.012)))
    return np.concatenate(out) * 0.25


def owl(rng):
    out = []
    for dur, f in [(0.18, 390), (0.08, 0), (0.5, 370)]:
        t = t_axis(dur)
        if f == 0:
            out.append(np.zeros(len(t)))
            continue
        e = np.sin(np.pi * t / dur) ** 0.7
        out.append((np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)) * e)
    return lp(np.concatenate(out), 1200) * 0.5


def crackle(n, rng, density=18):
    x = np.zeros(n)
    k = int(n / SR * density)
    for i in range(k):
        p = int(rng.integers(0, n - 200))
        ln = int(rng.integers(20, 160))
        x[p:p + ln] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4)) * rng.uniform(0.2, 1.0)
    bed = lp(pink(n, rng), 500) * 0.25
    return hp(x, 900) * 0.5 + bed


def drum(rng, f=60):
    t = t_axis(0.9)
    ff = f * (1 + 1.2 * np.exp(-t / 0.03))
    x = np.sin(2 * np.pi * np.cumsum(ff) / SR) * env(len(t), 0.002, 0.25)
    x += lp(rng.standard_normal(len(t)), 400) * env(len(t), 0.001, 0.04) * 0.4
    return x


def bell(rng, f=220):
    t = t_axis(5.0)
    x = np.zeros(len(t))
    for ratio, a in [(1, 1), (2.0, 0.5), (2.4, 0.35), (3.0, 0.25), (4.2, 0.15)]:
        x += a * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (2.4 / ratio ** 0.5))
    return x * 0.3


def raindrops(n, rng, rate=900):
    x = np.zeros(n)
    k = int(n / SR * rate)
    pos = rng.integers(0, n - 120, k)
    for p in pos:
        ln = 60
        x[p:p + ln] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / 8) * rng.uniform(0.1, 1.0)
    return hp(x, 2500) * 0.35


def thunder(rng, dur=4.0):
    n = int(SR * dur)
    x = brown(n, rng)
    e = np.zeros(n)
    t = np.arange(n) / SR
    for i in range(int(rng.integers(3, 6))):
        at = rng.uniform(0, dur * 0.4)
        e += np.exp(-np.maximum(t - at, 0) / rng.uniform(0.4, 1.2)) * (t >= at) * rng.uniform(0.4, 1.0)
    return lp(x * e, 600) * 1.4


# ---------------------------------------------------------------------------
# Paisagens
# ---------------------------------------------------------------------------

def scene(name):
    rng = rng_for(name)
    total = LOOP + XF
    n = int(SR * total)
    buf = np.zeros((n, 2))
    if name == "floresta":
        w = wind(n, rng, 200, 700, 0.4) * 0.25
        leaves = hp(pink(n, rng), 3000) * (slow_lfo(n, rng, 0.3) ** 3) * 0.08
        buf += np.stack([w + leaves, w * 0.9 + leaves * 1.1], 1)
        species = ["trill", "whistle", "warble", "twotone"]
        t = 0.3
        while t < total - 2:
            sp = species[int(rng.integers(0, 4))]
            place(buf, bird_call(rng, sp), t, rng.uniform(-0.8, 0.8), rng.uniform(0.15, 0.4))
            t += rng.uniform(0.5, 2.4)
        buf = stereo_reverb(buf, 0.8, 0.15, 5000)
    elif name in ("vento", "ceu"):
        w = wind(n, rng, 150, 1100 if name == "ceu" else 800, 0.9)
        w2 = wind(n, rng, 150, 900, 0.9)
        ww = whistle_wind(n, rng) * (2.0 if name == "ceu" else 1.0)
        buf += np.stack([w * 0.5 + ww, w2 * 0.5 + ww * 0.8], 1)
        if name == "ceu":
            t = 2.0
            while t < total - 2:
                place(buf, bird_call(rng, "whistle"), t, rng.uniform(-0.6, 0.6), 0.12)
                t += rng.uniform(4, 9)
    elif name == "chuva":
        bed = lp(pink(n, rng), 3500) * 0.18
        drops_l = raindrops(n, rng)
        drops_r = raindrops(n, rng)
        buf += np.stack([bed + drops_l, bed * 0.95 + drops_r], 1)
        t = 6.0
        while t < total - 5:
            place(buf, thunder(rng), t, rng.uniform(-0.5, 0.5), 0.5)
            t += rng.uniform(12, 20)
        t = 3.0
        while t < total - 5:
            place(buf, bell(rng, rng.choice([196, 220, 247])), t, rng.uniform(-0.3, 0.3), 0.08)
            t += rng.uniform(14, 22)
    elif name == "caverna":
        drone = lp(brown(n, rng), 120) * 0.35 + np.sin(2 * np.pi * 55 * np.arange(n) / SR) * 0.02
        buf += np.stack([drone, drone], 1)
        t = 0.2
        while t < total - 1:
            place(buf, drip(rng), t, rng.uniform(-0.9, 0.9), rng.uniform(0.25, 0.7))
            t += rng.uniform(0.3, 1.8)
        buf = stereo_reverb(buf, 2.2, 0.55, 2500)
    elif name == "pantano":
        water = lp(pink(n, rng), 600) * (0.3 + 0.3 * slow_lfo(n, rng, 0.4)) * 0.4
        insects = np.sin(2 * np.pi * 6800 * np.arange(n) / SR) * (0.5 + 0.5 * np.sin(2 * np.pi * 43 * np.arange(n) / SR)) * slow_lfo(n, rng, 0.2) * 0.02
        buf += np.stack([water + insects, water * 0.9 + insects * 0.6], 1)
        t = 0.5
        while t < total - 2:
            place(buf, frog(rng), t, rng.uniform(-0.8, 0.8), rng.uniform(0.2, 0.5))
            t += rng.uniform(0.6, 2.2)
        t = 3.0
        while t < total - 2:
            place(buf, bird_call(rng, "whistle"), t, rng.uniform(-0.7, 0.7), 0.12)
            t += rng.uniform(5, 10)
        buf = stereo_reverb(buf, 1.0, 0.18, 4000)
    elif name == "deserto":
        w = wind(n, rng, 300, 1400, 0.8) * 0.5
        sand = hp(pink(n, rng), 4000) * (slow_lfo(n, rng, 0.25) ** 2) * 0.12
        buf += np.stack([w + sand, w * 0.9 + sand * 1.2], 1)
    elif name == "noite":
        bed = lp(pink(n, rng), 800) * 0.05
        buf += np.stack([bed, bed], 1)
        for side in (-0.6, 0.5):
            t = rng.uniform(0, 1)
            while t < total - 1:
                place(buf, cricket(rng), t, side, rng.uniform(0.15, 0.3))
                t += rng.uniform(0.35, 0.6)
        t = 5.0
        while t < total - 3:
            place(buf, owl(rng), t, rng.uniform(-0.6, 0.6), 0.35)
            t += rng.uniform(9, 16)
        buf = stereo_reverb(buf, 1.3, 0.2, 4000)
    elif name == "guerra":
        fire = crackle(n, rng) * 0.6
        w = wind(n, rng, 150, 500, 0.5) * 0.25
        buf += np.stack([fire + w, fire * 0.8 + w], 1)
        t = 1.0
        pattern = [0, 0.5, 0.75, 1.5, 2.0]
        while t < total - 3:
            for off in pattern:
                place(buf, drum(rng, 55), t + off, -0.3, 0.35)
            t += rng.uniform(5, 9)
        buf = stereo_reverb(buf, 2.0, 0.35, 2000)
    elif name == "salao":
        tone = lp(brown(n, rng), 90) * 0.25
        buf += np.stack([tone, tone], 1)
        t = 1.0
        while t < total - 2:
            place(buf, drip(rng) * 0.6, t, rng.uniform(-0.8, 0.8), 0.25)
            t += rng.uniform(3, 7)
        buf = stereo_reverb(buf, 2.6, 0.5, 2200)
    return buf


def finish_loop(buf, gain=0.5):
    n_loop = int(SR * LOOP)
    xf = int(SR * XF)
    out = buf[:n_loop].copy()
    fade = np.linspace(0, 1, xf)[:, None]
    out[:xf] = out[:xf] * fade + buf[n_loop:n_loop + xf] * (1 - fade)
    peak = np.max(np.abs(out)) + 1e-9
    return (out / peak * gain).astype(np.float32)


def one_shots():
    rng = rng_for("oneshots")
    for i in range(3):
        buf = np.zeros(int(SR * 2.0))
        t = 0.0
        for k in range(int(rng.integers(2, 4))):
            b = bird_call(rng, ["trill", "warble", "twotone"][k % 3])
            s = int(t * SR)
            buf[s:s + len(b)] += b[: len(buf) - s]
            t += rng.uniform(0.2, 0.5)
        buf = buf / (np.max(np.abs(buf)) + 1e-9) * 0.6
        sf.write(os.path.join(SFX, "g_birds_%d.ogg" % i), buf.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    for i in range(2):
        th = thunder(rng, 4.5)
        th = reverb(th, 1.8, 0.4, 1500)
        th = th / (np.max(np.abs(th)) + 1e-9) * 0.9
        sf.write(os.path.join(SFX, "g_thunder_%d.ogg" % i), th.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    ru = lp(brown(int(SR * 2.5), rng), 200) * env(int(SR * 2.5), 0.2, 0.8)
    ru = ru / (np.max(np.abs(ru)) + 1e-9) * 0.9
    sf.write(os.path.join(SFX, "g_rumble_0.ogg"), ru.astype(np.float32), SR, format="OGG", subtype="VORBIS")


SCENES = ["floresta", "vento", "ceu", "chuva", "caverna", "pantano", "deserto", "noite", "guerra", "salao"]


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or SCENES
    for name in names:
        if name == "oneshots":
            continue
        buf = finish_loop(scene(name))
        sf.write(os.path.join(OUT, name + ".ogg"), buf, SR, format="OGG", subtype="VORBIS")
        print("ok", name)
    one_shots()
    print("ok one-shots")


if __name__ == "__main__":
    main()
