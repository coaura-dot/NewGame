#!/usr/bin/env python3
"""Compositor chiptune procedural: gera as trilhas do jogo (OGG, loop sem emenda).

Cada trilha é definida por um "estilo" (andamento, modo, progressões,
instrumentos, padrões de bateria). A melodia é composta por motivos
(ritmo + contorno) repetidos e variados em frases A A' B cadência, com
notas do acorde nos tempos fortes e graus da escala nos fracos.

Instrumentos: pulso (PolyBLEP, com vibrato), triângulo (baixo), pad de pulsos
desafinados filtrados, arpejo, bumbo/caixa/chimbal de ruído. Efeitos: eco
e um reverb simples. O loop é renderizado duas vezes e a 2ª cópia é usada,
então as caudas do fim entram no começo: emenda perfeita.

Uso:  python3 tools/build_music.py            (todas)
      python3 tools/build_music.py vila chefe (algumas)
Requer: pip install numpy soundfile
Saída: assets/audio/music/<id>.ogg
"""
import math
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio", "music")

MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "phrygdom": [0, 1, 4, 5, 7, 8, 10],
    "wholetone": [0, 2, 4, 6, 8, 10, 12],
}

# Estilos: bpm, tônica (MIDI), modo, progressões (graus 0-6, um por compasso),
# densidade da melodia, instrumentos e bateria. Tudo determinístico por seed.
STYLES = {
    "menu": dict(bpm=84, root=57, mode="aeolian", progA=[0, 5, 3, 4], progB=[5, 3, 0, 4],
                 density=0.35, lead_duty=0.5, pad=True, arp=False, drums="soft", seed=11, bars=16),
    "vila": dict(bpm=96, root=60, mode="ionian", progA=[0, 3, 4, 0], progB=[5, 3, 1, 4],
                 density=0.5, lead_duty=0.25, pad=True, arp=True, drums="light", seed=23, bars=16, swing=0.12),
    "castelo": dict(bpm=112, root=50, mode="dorian", progA=[0, 6, 5, 6], progB=[3, 4, 0, 6],
                    density=0.6, lead_duty=0.25, pad=False, arp=True, drums="rock", seed=37, bars=16),
    "catacumbas": dict(bpm=80, root=52, mode="phrygian", progA=[0, 1, 0, 6], progB=[5, 1, 3, 0],
                       density=0.3, lead_duty=0.5, pad=True, arp=False, drums="sparse", seed=41, bars=16),
    "floresta": dict(bpm=104, root=55, mode="mixolydian", progA=[0, 6, 3, 0], progB=[3, 4, 6, 0],
                     density=0.55, lead_duty=0.125, pad=True, arp=True, drums="light", seed=53, bars=16, swing=0.1),
    "deserto": dict(bpm=100, root=52, mode="phrygdom", progA=[0, 1, 0, 1], progB=[6, 5, 1, 0],
                    density=0.5, lead_duty=0.25, pad=True, arp=False, drums="tribal", seed=67, bars=16),
    "ceu": dict(bpm=96, root=62, mode="lydian", progA=[0, 1, 0, 4], progB=[3, 1, 5, 4],
                density=0.45, lead_duty=0.5, pad=True, arp=True, drums="soft", seed=71, bars=16),
    "guerra": dict(bpm=128, root=50, mode="aeolian", progA=[0, 0, 5, 6], progB=[3, 4, 5, 6],
                   density=0.6, lead_duty=0.25, pad=False, arp=True, drums="war", seed=83, bars=16),
    "chefe": dict(bpm=144, root=52, mode="harmonic", progA=[0, 5, 1, 4], progB=[3, 4, 0, 4],
                  density=0.7, lead_duty=0.25, pad=False, arp=True, drums="boss", seed=97, bars=16),
    "dimensao": dict(bpm=88, root=56, mode="wholetone", progA=[0, 1, 2, 1], progB=[3, 2, 1, 0],
                     density=0.35, lead_duty=0.5, pad=True, arp=True, drums="sparse", seed=101, bars=16),
    "cerco": dict(bpm=120, root=50, mode="aeolian", progA=[0, 5, 6, 4], progB=[3, 0, 4, 4],
                  density=0.55, lead_duty=0.5, pad=True, arp=True, drums="war", seed=113, bars=16),
}


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ---------------------------------------------------------------------------
# Síntese
# ---------------------------------------------------------------------------

def _polyblep(t, dt):
    out = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m2 = t > 1.0 - dt
    x = (t[m2] - 1.0) / dt[m2]
    out[m2] = x * x + x + x + 1.0
    return out


def saw_bl(phase, dt):
    t = phase % 1.0
    return 2.0 * t - 1.0 - _polyblep(t, dt)


def pulse(freq, n, duty=0.5, vib=0.0, vib_rate=5.5, vib_delay=0.12):
    tt = np.arange(n) / SR
    f = np.full(n, freq, dtype=np.float64)
    if vib > 0:
        depth = np.clip((tt - vib_delay) / 0.15, 0.0, 1.0) * vib
        f = f * (1.0 + depth * np.sin(2 * math.pi * vib_rate * tt))
    dt = f / SR
    ph = np.cumsum(dt)
    return 0.5 * (saw_bl(ph, dt) - saw_bl(ph + duty, dt))


def triangle(freq, n):
    ph = (np.arange(n) * freq / SR) % 1.0
    return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0


def adsr(n, a=0.005, d=0.08, s=0.6, r=0.08, gate=None):
    gate = n if gate is None else min(gate, n)
    env = np.zeros(n)
    ai = max(int(a * SR), 1)
    di = max(int(d * SR), 1)
    ri = max(int(r * SR), 1)
    idx = np.arange(n)
    env = np.where(idx < ai, idx / ai, 0.0)
    dec = (idx >= ai) & (idx < ai + di)
    env[dec] = 1.0 - (1.0 - s) * (idx[dec] - ai) / di
    sus = (idx >= ai + di) & (idx < gate)
    env[sus] = s
    level_at_gate = s if gate >= ai + di else (gate / ai if gate < ai else 1.0 - (1.0 - s) * (gate - ai) / di)
    rel = idx >= gate
    env[rel] = level_at_gate * np.clip(1.0 - (idx[rel] - gate) / ri, 0.0, 1.0)
    return env


def lowpass(x, cutoff):
    """Passa-baixa de 1 polo (vetorizado por blocos via lfilter caseiro)."""
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    # blocos grandes em Python puro: aceitável para trechos curtos (notas)
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff):
    """Aproximação de passa-baixa por média móvel exponencial via convolução."""
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    k = int(min(max(4.0 / (1.0 - a), 8), 2000))
    kernel = (1 - a) * a ** np.arange(k)
    return np.convolve(x, kernel)[: len(x)]


def comb_block(x, delay, gain):
    """y[n] = x[n] + g*y[n-D], em blocos de D amostras (vetorizado)."""
    y = x.copy()
    for start in range(delay, len(y), delay):
        end = min(start + delay, len(y))
        y[start:end] += gain * y[start - delay:end - delay]
    return y


def reverb(x, mix=0.18):
    combs = [int(SR * t) for t in (0.0297, 0.0371, 0.0411, 0.0437)]
    wet = np.zeros_like(x)
    for i, d in enumerate(combs):
        wet += comb_block(x, d, 0.72 - i * 0.02)
    wet = lp_fast(wet / len(combs), 3500)
    return x * (1 - mix) + wet * mix


def echo(x, delay_s, fb=0.3, mix=0.2):
    d = int(delay_s * SR)
    wet = comb_block(np.concatenate([np.zeros(d), x])[: len(x)], d, fb)
    return x + wet * mix


# ---------------------------------------------------------------------------
# Instrumentos (renderizam uma nota num buffer)
# ---------------------------------------------------------------------------

def add(buf, start, sig):
    end = min(start + len(sig), len(buf))
    if start < len(buf) and end > start:
        buf[start:end] += sig[: end - start]


def note_lead(freq, dur, duty, vel):
    n = int((dur + 0.12) * SR)
    sig = pulse(freq, n, duty, vib=0.006, vib_rate=5.2)
    env = adsr(n, a=0.006, d=0.12, s=0.55, r=0.1, gate=int(dur * SR))
    return lp_fast(sig * env, 5200) * vel


def note_bass(freq, dur, vel):
    n = int((dur + 0.05) * SR)
    sig = triangle(freq, n) * 0.9 + pulse(freq, n, 0.5) * 0.12
    env = adsr(n, a=0.004, d=0.05, s=0.8, r=0.04, gate=int(dur * SR * 0.92))
    return sig * env * vel


def note_arp(freq, dur, vel):
    n = int((dur + 0.03) * SR)
    sig = pulse(freq, n, 0.125)
    env = adsr(n, a=0.002, d=0.06, s=0.25, r=0.03, gate=int(dur * SR * 0.7))
    return lp_fast(sig * env, 4000) * vel


def note_pad(freqs, dur, vel):
    n = int((dur + 0.6) * SR)
    sig = np.zeros(n)
    for f in freqs:
        for det in (-0.004, 0.004):
            sig += pulse(f * (1 + det), n, 0.3)
    env = adsr(n, a=0.35, d=0.3, s=0.7, r=0.6, gate=int(dur * SR))
    return lp_fast(sig * env / (len(freqs) * 2), 1400) * vel


_rng_noise = np.random.default_rng(7)


def drum(kind, vel):
    if kind == "k":
        n = int(0.22 * SR)
        t = np.arange(n) / SR
        f = 45 + 110 * np.exp(-t * 28)
        ph = np.cumsum(f / SR)
        return np.sin(2 * math.pi * ph) * np.exp(-t * 14) * vel
    if kind == "s":
        n = int(0.2 * SR)
        t = np.arange(n) / SR
        noise = _rng_noise.standard_normal(n)
        noise = noise - lp_fast(noise, 900)
        tone = np.sin(2 * math.pi * 190 * t) * np.exp(-t * 30)
        return (noise * np.exp(-t * 20) * 0.5 + tone * 0.5) * vel
    if kind == "h":
        n = int(0.05 * SR)
        t = np.arange(n) / SR
        noise = _rng_noise.standard_normal(n)
        noise = noise - lp_fast(noise, 6000)
        return noise * np.exp(-t * 90) * vel * 0.6
    if kind == "t":  # tom (bumbo agudo, para estilos tribais/guerra)
        n = int(0.25 * SR)
        t = np.arange(n) / SR
        f = 90 + 90 * np.exp(-t * 18)
        ph = np.cumsum(f / SR)
        return np.sin(2 * math.pi * ph) * np.exp(-t * 11) * vel
    return np.zeros(1)


# padrões de bateria (16 passos por compasso)
DRUMS = {
    "soft": {"k": "x.......x.......", "s": "........", "h": "..x...x...x...x."},
    "light": {"k": "x.......x..x....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."},
    "rock": {"k": "x.....x.x.......", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."},
    "sparse": {"k": "x...............", "s": "................", "h": "......x.......x."},
    "tribal": {"k": "x..x..x.x..x....", "t": "....x.......x.x.", "h": "x...x...x...x..."},
    "war": {"k": "x.x...x.x.x...x.", "s": "....x.......x...", "t": "..............xx", "h": "x.xxx.xxx.xxx.xx"},
    "boss": {"k": "x.x.x.x.x.x.x.x.", "s": "....x.......x..x", "h": "xxxxxxxxxxxxxxxx"},
}

# ritmos de melodia (16 avos): x = ataque, - = sustenta, . = pausa
RHYTHMS = {
    "sparse": ["x-------x---x---", "x-----x-x-------", "x---x---x-------", "x-------x-x-x---"],
    "mid": ["x---x-x-x---x---", "x-x-x---x---x-x-", "x--x--x-x---x---", "x---x---x-x-x---", "x-x---x-x-x-x---"],
    "dense": ["x-xxx-x-x-xxx-x-", "xxx-x-x-xx-xx-x-", "x-x-xxx-x-x-xxx-", "xx-xx-x-xx-xx-x-"],
}


# ---------------------------------------------------------------------------
# Composição
# ---------------------------------------------------------------------------

def scale_notes(root, mode, lo, hi):
    iv = MODES[mode]
    out = []
    for octv in range(-3, 5):
        for s in iv[:7]:
            m = root + octv * 12 + s
            if lo <= m <= hi:
                out.append(m)
    return sorted(set(out))


def chord(root, mode, degree, size=3):
    iv = MODES[mode]
    notes = []
    for k in range(size):
        idx = degree + 2 * k
        notes.append(root + iv[idx % 7] + 12 * (idx // 7))
    return notes


def compose_melody(st, rng, prog, bars, spb):
    """Lista de (passo inicial, duração em passos, nota MIDI)."""
    root, mode = st["root"], st["mode"]
    lo, hi = root + 12, root + 12 + 19
    scale = scale_notes(root, mode, lo, hi)
    dens = st["density"]
    pool = RHYTHMS["sparse" if dens < 0.4 else ("mid" if dens < 0.62 else "dense")]
    motif_a = [pool[rng.integers(len(pool))] for _ in range(2)]
    motif_b = [pool[rng.integers(len(pool))] for _ in range(2)]
    notes = []
    cur = scale[len(scale) // 3]
    contour_a = rng.choice([-1, 1], size=16)
    contour_b = rng.choice([-1, 1], size=16)
    for bar in range(bars):
        phrase_pos = bar % 8
        rhythm = (motif_a if phrase_pos < 4 else motif_b)[bar % 2]
        contour = contour_a if phrase_pos < 4 else contour_b
        ch = chord(root + 12, mode, prog[bar % len(prog)])
        ch_pcs = {c % 12 for c in ch}
        last_bar_of_phrase = phrase_pos in (3, 7)
        steps = list(rhythm)
        onsets = [i for i, c in enumerate(steps) if c == "x"]
        for j, i in enumerate(onsets):
            nxt = onsets[j + 1] if j + 1 < len(onsets) else 16
            dur = nxt - i
            # sustentar: conta os "-" e pausas "."
            k = i + 1
            while k < 16 and steps[k] == "-":
                k += 1
            dur = max(k - i, 1)
            strong = i % 4 == 0
            if last_bar_of_phrase and j == len(onsets) - 1:
                # cadência: termina na tônica/terça do acorde, nota longa
                cands = [m for m in scale if m % 12 in ch_pcs]
                cur = min(cands, key=lambda m: abs(m - cur))
                dur = 16 - i
            elif strong:
                cands = [m for m in scale if m % 12 in ch_pcs]
                cands.sort(key=lambda m: abs(m - cur))
                cur = cands[0] if rng.random() < 0.6 else cands[min(1, len(cands) - 1)]
            else:
                idx = scale.index(min(scale, key=lambda m: abs(m - cur)))
                step = int(contour[i]) * (1 if rng.random() < 0.75 else 2)
                idx = int(np.clip(idx + step, 0, len(scale) - 1))
                cur = scale[idx]
            if rng.random() < 0.08 and not strong:
                continue  # respiro
            notes.append((bar * 16 + i, dur, cur))
    return notes


def render(style_id):
    st = STYLES[style_id]
    rng = np.random.default_rng(st["seed"])
    bpm = st["bpm"]
    step_s = 60.0 / bpm / 4.0
    bars = st["bars"]
    prog = st["progA"] * 2 + st["progB"] * 2
    total_steps = bars * 16
    length = int(total_steps * step_s * SR)
    buf = np.zeros(length * 2 + SR * 3)
    swing = st.get("swing", 0.0)

    def t_of(step):
        base = step * step_s
        if swing and step % 2 == 1:
            base += swing * step_s
        return int(base * SR)

    melody = compose_melody(st, rng, prog, bars, 16)
    # um contracanto uma oitava abaixo na seção B (variação)
    for copy in (0, 1):
        off = copy * length
        # melodia
        for (s, d, m) in melody:
            vel = 0.2 if (s // 16) % 8 < 4 else 0.22
            add(buf, off + t_of(s), note_lead(mtof(m), d * step_s * 0.95, st["lead_duty"], vel))
        # baixo
        for bar in range(bars):
            ch = chord(st["root"] - 12, st["mode"], prog[bar % len(prog)])
            r = ch[0]
            if st["drums"] in ("war", "boss", "rock"):
                pat = [(0, 2, r), (2, 2, r), (4, 2, r + 12), (6, 2, r), (8, 2, r), (10, 2, r), (12, 2, ch[2]), (14, 2, r + 12)]
            elif st["drums"] in ("sparse", "soft"):
                pat = [(0, 8, r), (8, 8, ch[2] - 12 if ch[2] - 12 >= r - 5 else ch[2])]
            else:
                pat = [(0, 3, r), (3, 3, r), (6, 2, ch[2]), (8, 4, r), (12, 2, ch[1]), (14, 2, ch[2])]
            for (s, d, m) in pat:
                add(buf, off + t_of(bar * 16 + s), note_bass(mtof(m), d * step_s, 0.3))
        # pad
        if st["pad"]:
            for bar in range(bars):
                ch = chord(st["root"], st["mode"], prog[bar % len(prog)], 3)
                add(buf, off + t_of(bar * 16), note_pad([mtof(c) for c in ch], 16 * step_s, 0.12))
        # arpejo
        if st["arp"]:
            for bar in range(bars):
                if (bar // 8) == 0 and style_id in ("menu", "dimensao") and bar < 4:
                    continue
                ch = chord(st["root"] + 12, st["mode"], prog[bar % len(prog)], 4)
                seq = ch + ch[-2:0:-1]
                for s in range(16):
                    m = seq[s % len(seq)]
                    add(buf, off + t_of(bar * 16 + s), note_arp(mtof(m + 12), step_s, 0.05))
        # bateria
        pat = DRUMS[st["drums"]]
        for bar in range(bars):
            for kind, p in pat.items():
                for s, c in enumerate(p):
                    if c == "x":
                        vel = {"k": 0.42, "s": 0.2, "h": 0.07, "t": 0.3}[kind]
                        if kind == "h" and s % 4 != 0:
                            vel *= 0.7
                        add(buf, off + t_of(bar * 16 + s), drum(kind, vel))
    # efeitos no buffer inteiro (2 cópias) e recorte da 2ª => loop perfeito
    wet = echo(buf, step_s * 3, fb=0.28, mix=0.14)
    wet = reverb(wet, mix=0.2)
    loop = wet[length:2 * length]
    # masterização: DC, pico e saturação suave
    loop = loop - np.mean(loop)
    peak = np.max(np.abs(loop)) + 1e-9
    loop = np.tanh(loop / peak * 1.1) * 0.78
    return loop


def main():
    os.makedirs(OUT, exist_ok=True)
    ids = sys.argv[1:] or list(STYLES.keys())
    for sid in ids:
        data = render(sid)
        path = os.path.join(OUT, sid + ".ogg")
        sf.write(path, data.astype(np.float32), SR, format="OGG", subtype="VORBIS", compression_level=0.85)
        print("%-11s %5.1fs  %4d KB" % (sid, len(data) / SR, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
