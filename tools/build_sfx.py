#!/usr/bin/env python3
"""Efeitos sonoros de combate gerados por código (curtos, secos e "gordos").

Tudo é síntese simples (seno com queda de afinação, ruído filtrado, parciais
metálicos inarmônicos) com envelopes rápidos — o objetivo é impacto claro e
legível, estilo Katana Zero / Hollow Knight, sem soar genérico:

  g_slash_*      corte no ar (ruído que desce de agudo p/ médio)
  g_hit_*        acerto: estalo + "thump" grave + brilho metálico curto
  g_hitheavy_*   acerto pesado: thump maior, sub-grave, estalo longo
  g_kill_*       golpe de morte: "shing" agudo + boom grave + cauda
  g_dashstrike_* Corte-Relâmpago: zing ascendente
  g_dash_*       dash: sopro rápido
  g_frenzy_*     subiu o Frenesi: arpejo curto
  g_rank_{s,a,b,c} carimbo da nota do encontro
  g_parry_*      aparo perfeito: sino metálico brilhante

Uso:  python3 tools/build_sfx.py      Requer: pip install numpy soundfile
Saída: assets/audio/sfx/g_*.ogg (rode `godot --headless --path . --import`)
"""
import os

import numpy as np
import soundfile as sf

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.002, decay=0.1, curve=4.0):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4) * (curve / 4.0) * 4.0)
    return a * d


def sweep_sine(dur, f0, f1, curve=3.0):
    t = t_axis(dur)
    k = (t / dur) ** (1.0 / curve)
    f = f0 * (f1 / f0) ** k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def onepole_lp(x, cutoff):
    """Passa-baixa de 1 polo com corte variável (array ou escalar)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * c / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def hp(x, cutoff):
    return x - onepole_lp(x, cutoff)


def metal(dur, base, decay):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp in [(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.93, 0.2)]:
        out += amp * np.sin(2 * np.pi * base * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t / (decay / ratio ** 0.5))
    return out


def pad(x, dur):
    n = int(SR * dur)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(dur, *parts):
    out = np.zeros(int(SR * dur))
    for p in parts:
        p = pad(p, dur)
        out += p
    return out


def finish(x, gain=0.9):
    x = np.tanh(x * 1.4)  # saturação leve = mais "gordo"
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * gain
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x.astype(np.float32)


def save(name, x):
    path = os.path.join(OUT, name + ".ogg")
    sf.write(path, x, SR, format="OGG", subtype="VORBIS")
    print("ok", path)


def slash(v):
    d = 0.11
    n = noise(d)
    cut = np.linspace(9000 - v * 800, 1800, len(n))
    body = hp(onepole_lp(n, cut), 500) * env(d, 0.012, 0.05)
    return finish(body, 0.7)


def hit(v):
    d = 0.2
    crack = hp(noise(0.02), 2500) * env(0.02, 0.0005, 0.006) * 1.2
    thump = sweep_sine(0.12, 180 + v * 20, 48) * env(0.12, 0.001, 0.05) * 1.3
    ring = metal(0.16, 1400 + v * 170, 0.05) * 0.25
    return finish(mix(d, crack, thump, ring), 0.85)


def hit_heavy(v):
    d = 0.35
    crack = hp(noise(0.04), 1800) * env(0.04, 0.0005, 0.012) * 1.3
    thump = sweep_sine(0.25, 140 + v * 10, 34) * env(0.25, 0.001, 0.1) * 1.6
    sub = np.sin(2 * np.pi * 45 * t_axis(0.3)) * env(0.3, 0.005, 0.12) * 0.8
    ring = metal(0.3, 900 + v * 90, 0.09) * 0.3
    return finish(mix(d, crack, thump, sub, ring), 0.95)


def kill(v):
    d = 0.55
    shing = (np.sin(2 * np.pi * (2600 + v * 150) * t_axis(0.4)) + 0.5 * np.sin(2 * np.pi * (3900 + v * 200) * t_axis(0.4))) * env(0.4, 0.001, 0.09) * 0.45
    crack = hp(noise(0.05), 2000) * env(0.05, 0.0005, 0.015) * 1.2
    boom = sweep_sine(0.45, 120, 30) * env(0.45, 0.002, 0.16) * 1.7
    tail = onepole_lp(noise(0.5), 700) * env(0.5, 0.01, 0.2) * 0.5
    return finish(mix(d, shing, crack, boom, tail), 0.95)


def dash_strike(v):
    d = 0.24
    zing = sweep_sine(d, 700 + v * 60, 3400, 1.5) * env(d, 0.004, 0.09) * 0.55
    air = hp(onepole_lp(noise(d), np.linspace(2000, 9000, int(SR * d))), 800) * env(d, 0.02, 0.08) * 0.8
    return finish(mix(d, zing, air), 0.8)


def dash(v):
    d = 0.16
    n = noise(d)
    body = onepole_lp(n, np.linspace(1200, 5200 + v * 400, len(n))) * env(d, 0.01, 0.06)
    return finish(hp(body, 300), 0.6)


def frenzy(v):
    d = 0.42
    out = np.zeros(int(SR * d))
    notes = [0, 4, 7, 12] if v == 0 else [0, 5, 9, 12]
    for i, n in enumerate(notes):
        f = 523.25 * 2 ** (n / 12)
        seg_t = t_axis(0.16)
        sq = np.sign(np.sin(2 * np.pi * f * seg_t)) * 0.3 * np.exp(-seg_t / 0.06)
        s = int(SR * 0.05 * i)
        out[s:s + len(sq)] += sq[: len(out) - s]
    return finish(onepole_lp(out, 6000), 0.6)


def rank(letter):
    d = 0.9
    chords = {"s": [0, 4, 7, 11, 14], "a": [0, 4, 7, 12], "b": [0, 5, 7], "c": [0, 3, 7]}
    boom = sweep_sine(0.5, 110, 40) * env(0.5, 0.002, 0.18) * 1.5
    crack = hp(noise(0.03), 2000) * env(0.03, 0.0005, 0.01)
    chord = np.zeros(int(SR * d))
    t = t_axis(d)
    for n in chords[letter]:
        f = 392.0 * 2 ** (n / 12)
        chord += (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)) * np.exp(-t / 0.35) * 0.25
    return finish(mix(d, boom, crack, chord), 0.9)


def parry(v):
    d = 0.6
    bell = metal(d, 1800 + v * 120, 0.22) * 0.8
    crack = hp(noise(0.03), 3000) * env(0.03, 0.0005, 0.008)
    return finish(mix(d, bell, crack), 0.85)


def aim(v):
    d = 0.35
    t = t_axis(d)
    tone = np.sin(2 * np.pi * (1500 + 400 * t / d) * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 18 * t))) * 0.25
    return finish(tone * env(d, 0.01, 0.3), 0.45)


def shot(v):
    d = 0.3
    crack = hp(noise(0.03), 2500) * env(0.03, 0.0003, 0.008) * 1.4
    zap = sweep_sine(0.18, 2200 + v * 100, 300, 2.0) * env(0.18, 0.001, 0.05) * 0.8
    boom = sweep_sine(0.2, 160, 50) * env(0.2, 0.001, 0.06) * 0.9
    return finish(mix(d, crack, zap, boom), 0.8)


def orb(v):
    d = 0.5
    t = t_axis(d)
    ding = (np.sin(2 * np.pi * 1318.5 * t) + 0.6 * np.sin(2 * np.pi * 1975.5 * t)) * np.exp(-t / 0.14) * 0.5
    air = hp(onepole_lp(noise(0.12), 5000), 800) * env(0.12, 0.002, 0.03) * 0.6
    return finish(mix(d, ding, air), 0.7)


def wave(v):
    d = 0.9
    t = t_axis(d)
    low = sweep_sine(d, 70, 140, 1.0) * env(d, 0.05, 0.4) * 1.0
    shimmer = np.sin(2 * np.pi * 880 * t + 3 * np.sin(2 * np.pi * 7 * t)) * env(d, 0.1, 0.35) * 0.25
    return finish(mix(d, low, shimmer), 0.75)


def main():
    os.makedirs(OUT, exist_ok=True)
    for v in range(3):
        save("g_slash_%d" % v, slash(v))
        save("g_hit_%d" % v, hit(v))
        save("g_hitheavy_%d" % v, hit_heavy(v))
        save("g_kill_%d" % v, kill(v))
        save("g_dashstrike_%d" % v, dash_strike(v))
        save("g_dash_%d" % v, dash(v))
    for v in range(2):
        save("g_frenzy_%d" % v, frenzy(v))
        save("g_parry_%d" % v, parry(v))
    for v in range(2):
        save("g_shot_%d" % v, shot(v))
    save("g_aim_0", aim(0))
    save("g_orb_0", orb(0))
    save("g_wave_0", wave(0))
    for letter in "sabc":
        save("g_rank_" + letter, rank(letter))


if __name__ == "__main__":
    main()
