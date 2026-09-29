#!/usr/bin/env python3
"""Trilha sonora do jogo — composta nota a nota e sintetizada aqui mesmo.

    python3 tools/music_gen.py            # gera todas em assets/audio/music/*.ogg
    python3 tools/music_gen.py noite      # só uma faixa
    python3 tools/music_gen.py --wav DIR  # também salva .wav para ouvir/comparar

Precisa de numpy e soundfile (pip install soundfile) para gravar OGG Vorbis.

Cada faixa tem acordes (um por compasso), melodia escrita à mão e um
"arranjo" (quais instrumentos tocam o acompanhamento e a bateria). O loop é
renderizado duas vezes e a segunda volta é recortada: a reverberação e as
notas que atravessam o fim do loop entram no começo — o loop não tem emenda.

Faixas:
  candelaria  mapa-múndi de dia (Fá maior, pastoral)
  noite       mapa-múndi à noite (Ré menor, caixinha de música e pad)
  estrada     fases (Lá menor, aventura)
  frenesi     fases Frenesi / fugas (Mi menor, rápida)
  guardiao    chefes (Dó menor harmônica, dramática)
  lareira     vilas, menu e o final (Sol maior, valsa aconchegante)
"""
import os
import re
import sys

import numpy as np

SR = 32000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "music")
RNG = np.random.default_rng(7)

# ---------------------------------------------------------------------------
# Teoria: notas e acordes
# ---------------------------------------------------------------------------

NOTE_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'C#5' / 'Bb4' -> número MIDI."""
    m = re.fullmatch(r"([A-G])([#b]?)(-?\d)", name)
    if not m:
        raise ValueError(name)
    n = NOTE_BASE[m.group(1)] + (1 if m.group(2) == "#" else (-1 if m.group(2) == "b" else 0))
    return n + 12 * (int(m.group(3)) + 1)


def freq(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


QUALITIES = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
    "sus4": [0, 5, 7], "sus2": [0, 2, 7], "dim": [0, 3, 6], "add9": [0, 4, 7, 14], "m9": [0, 3, 7, 10, 14],
    "7b9": [0, 4, 7, 10, 13], "6": [0, 4, 7, 9],
}


def chord(sym):
    """'Dm7/A' -> (baixo midi (oitava 2), [notas do acorde oitava 4])."""
    main, _, bass = sym.partition("/")
    m = re.fullmatch(r"([A-G][#b]?)(.*)", main)
    root = m.group(1)
    q = m.group(2)
    r = midi(root + "4")
    tones = [r + i for i in QUALITIES[q]]
    b = midi((bass or root) + "2")
    return b, tones


def parse_melody(text):
    """'A4:1 C5:0.5 r:1' -> [(midi ou None, início em tempos, duração)]"""
    out = []
    t = 0.0
    for tok in text.split():
        name, dur = tok.split(":")
        d = float(dur)
        out.append((None if name == "r" else midi(name), t, d))
        t += d
    return out, t


# ---------------------------------------------------------------------------
# Síntese
# ---------------------------------------------------------------------------

def env_adsr(n, a, d, s, r, sr=SR):
    """Envelope com release depois de n amostras 'ligadas'. Retorna n + r amostras."""
    a_n, d_n, r_n = max(1, int(a * sr)), max(1, int(d * sr)), max(1, int(r * sr))
    on = np.ones(n) * s
    on[: min(a_n, n)] = np.linspace(0, 1, a_n)[: min(a_n, n)]
    if n > a_n:
        k = min(d_n, n - a_n)
        on[a_n: a_n + k] = np.linspace(1, s, d_n)[:k]
    last = on[-1] if n else 0.0
    rel = np.linspace(last, 0.0, r_n)
    return np.concatenate([on, rel])


def lp(x, cutoff):
    """Passa-baixa de 1 polo via FFT (rápido e sem laço em Python)."""
    n = len(x)
    if n == 0:
        return x
    f = np.fft.rfftfreq(n * 2, 1.0 / SR)
    X = np.fft.rfft(np.concatenate([x, np.zeros(n)]))
    H = 1.0 / (1.0 + 1j * f / cutoff)
    return np.fft.irfft(X * H)[:n]


def hp(x, cutoff):
    return x - lp(x, cutoff)


def phase(f0, n, vib=0.0, vib_hz=5.5, vib_delay=0.15, glide_from=None, glide_t=0.04):
    t = np.arange(n) / SR
    f = np.full(n, f0, dtype=np.float64)
    if glide_from:
        g = np.clip(t / glide_t, 0, 1)
        f = glide_from + (f0 - glide_from) * g
    if vib > 0:
        depth = np.clip((t - vib_delay) / 0.25, 0, 1) * vib
        f = f * (1.0 + depth * np.sin(2 * np.pi * vib_hz * t))
    return np.cumsum(f) / SR


def osc_square(ph, duty=0.5):
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def osc_tri(ph):
    return 4.0 * np.abs((ph % 1.0) - 0.5) - 1.0


def osc_saw(ph):
    return 2.0 * (ph % 1.0) - 1.0


def inst_flute(f0, n):
    ph = phase(f0, n + int(0.15 * SR), vib=0.006, vib_hz=5.2)
    x = 0.65 * np.sin(2 * np.pi * ph) + 0.25 * osc_tri(ph) + 0.08 * np.sin(4 * np.pi * ph)
    x += RNG.normal(0, 0.005, len(x))  # sopro
    e = env_adsr(n, 0.035, 0.12, 0.82, 0.15)
    return lp(x[: len(e)] * e, 4500)


def inst_pulse(f0, n, duty=0.3):
    ph = phase(f0, n + int(0.1 * SR), vib=0.005, vib_hz=6.0, vib_delay=0.2)
    x = osc_square(ph, duty)
    e = env_adsr(n, 0.008, 0.1, 0.7, 0.1)
    return lp(x[: len(e)] * e, 3200) * 0.8


def inst_pluck(f0, n):
    m = n + int(0.35 * SR)
    ph = phase(f0, m)
    t = np.arange(m) / SR
    x = 0.6 * osc_tri(ph) + 0.4 * osc_square(ph, 0.25)
    x *= np.exp(-t * 7.0)
    # "filtro" que fecha: mistura de brilhante (começo) com abafado
    bright = x * np.exp(-t * 25.0)
    return lp(x, 1800) * 0.9 + bright * 0.25


def inst_bell(f0, n):
    m = n + int(1.2 * SR)
    t = np.arange(m) / SR
    idx = 2.2 * np.exp(-t * 6.0)
    x = np.sin(2 * np.pi * f0 * t + idx * np.sin(2 * np.pi * f0 * 3.5 * t))
    x += 0.3 * np.sin(2 * np.pi * f0 * 2.0 * t) * np.exp(-t * 3.0)
    return x * np.exp(-t * 2.8) * 0.8


def inst_bass(f0, n):
    ph = phase(f0, n + int(0.08 * SR))
    x = 0.75 * osc_tri(ph) + 0.35 * np.sin(2 * np.pi * ph * 0.5 * 2)
    e = env_adsr(n, 0.005, 0.08, 0.75, 0.06)
    return lp(x[: len(e)] * e, 900)


def inst_bass_drive(f0, n):
    ph = phase(f0, n + int(0.05 * SR))
    x = 0.6 * osc_saw(ph) + 0.5 * osc_tri(ph)
    e = env_adsr(n, 0.003, 0.06, 0.6, 0.04)
    return lp(x[: len(e)] * e, 700)


def inst_arp(f0, n):
    ph = phase(f0, n + int(0.05 * SR))
    x = osc_square(ph, 0.125)
    t = np.arange(len(x)) / SR
    return lp(x * np.exp(-t * 14.0), 2600) * 0.6


def inst_pad(f0, n):
    m = n + int(0.8 * SR)
    x = np.zeros(m)
    for cents in (-8, 0, 7):
        ph = phase(f0 * 2 ** (cents / 1200.0), m)
        x += osc_saw(ph)
    e = env_adsr(n, 0.45, 0.3, 0.8, 0.8)
    return lp(x[: len(e)] * e / 3.0, 1000)


def drum(kind, n=None):
    if kind == "kick":
        m = int(0.28 * SR)
        t = np.arange(m) / SR
        f = 45 + 95 * np.exp(-t * 28.0)
        ph = np.cumsum(f) / SR
        return np.sin(2 * np.pi * ph) * np.exp(-t * 9.0) * 1.1
    if kind == "snare":
        m = int(0.22 * SR)
        t = np.arange(m) / SR
        nz = hp(lp(RNG.normal(0, 1, m), 6000), 1200) * np.exp(-t * 18.0)
        tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30.0)
        return nz * 0.55 + tone * 0.5
    if kind == "hat":
        m = int(0.05 * SR)
        t = np.arange(m) / SR
        return hp(RNG.normal(0, 1, m), 7000) * np.exp(-t * 90.0) * 0.25
    if kind == "shaker":
        m = int(0.07 * SR)
        t = np.arange(m) / SR
        return hp(lp(RNG.normal(0, 1, m), 8000), 4000) * np.sin(np.pi * t / t[-1]) * 0.12
    if kind == "crash":
        m = int(1.4 * SR)
        t = np.arange(m) / SR
        return hp(RNG.normal(0, 1, m), 3500) * np.exp(-t * 3.0) * 0.35
    if kind == "tom":
        m = int(0.3 * SR)
        t = np.arange(m) / SR
        f = 90 + 70 * np.exp(-t * 18.0)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 10.0) * 0.8
    if kind == "rim":
        m = int(0.06 * SR)
        t = np.arange(m) / SR
        return (np.sin(2 * np.pi * 820 * t) + 0.5 * hp(RNG.normal(0, 1, m), 2000)) * np.exp(-t * 60.0) * 0.35
    return np.zeros(1)


INSTRUMENTS = {"flute": inst_flute, "pulse": inst_pulse, "pluck": inst_pluck, "bell": inst_bell, "bass": inst_bass,
               "bass_drive": inst_bass_drive, "arp": inst_arp, "pad": inst_pad}


def reverb_ir(t60=1.6, pre=0.012):
    m = int(t60 * SR)
    t = np.arange(m) / SR
    ir = RNG.normal(0, 1, m) * np.exp(-t * 6.9 / t60)
    ir = lp(ir, 5000)
    ir[: int(pre * SR)] = 0.0
    return ir / np.sqrt(np.sum(ir ** 2))


def convolve(x, ir):
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


# ---------------------------------------------------------------------------
# Arranjo
# ---------------------------------------------------------------------------

class Track:
    def __init__(self, name, bpm, beats_per_bar, chords, melodies, arrangement, reverb=0.28, t60=1.6, gain=1.0):
        self.name = name
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.chords = chords
        self.melodies = melodies  # [(instrumento, texto, ganho, oitava_extra)]
        self.arr = arrangement  # dict
        self.reverb = reverb
        self.t60 = t60
        self.gain = gain

    @property
    def beat_s(self):
        return 60.0 / self.bpm

    def loop_beats(self):
        return len(self.chords) * self.bpb


def add(buf, sig, at_s, g=1.0):
    i = int(round(at_s * SR))
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i] * g


def render(tr):
    beat = tr.beat_s
    L = tr.loop_beats() * beat
    total = 2.0 * L + tr.t60 + 1.0
    dry = np.zeros(int(total * SR))
    wet_send = np.zeros_like(dry)
    arr = tr.arr
    for rep in range(2):
        t0 = rep * L
        # melodias
        for inst, text, g, octv in tr.melodies:
            notes, length = parse_melody(text)
            reps = max(1, int(round(tr.loop_beats() / length)))
            for k in range(reps):
                for n, st, du in notes:
                    if n is None:
                        continue
                    at = t0 + (st + k * length) * beat
                    sig = INSTRUMENTS[inst](freq(n + 12 * octv), int(du * beat * SR * 0.95))
                    add(dry, sig, at, g)
                    add(wet_send, sig, at, g)
        # acompanhamento por compasso
        for bi, sym in enumerate(tr.chords):
            bass_n, tones = chord(sym)
            bt = t0 + bi * tr.bpb * beat
            # baixo
            bpat = arr.get("bass_pattern")
            if bpat:
                inst = arr.get("bass_inst", "bass")
                for (b_at, b_du, interval) in bpat:
                    nn = bass_n + interval
                    add(dry, INSTRUMENTS[inst](freq(nn), int(b_du * beat * SR * 0.9)), bt + b_at * beat, arr.get("bass_gain", 0.5))
            # arpejo
            apat = arr.get("arp_pattern")
            if apat:
                inst = arr.get("arp_inst", "arp")
                step = arr.get("arp_step", 0.5)
                ton = sorted(tones + [tones[0] + 12])
                if arr.get("arp_up_oct"):
                    ton = [x + 12 * arr["arp_up_oct"] for x in ton]
                steps = int(round(tr.bpb / step))
                for s in range(steps):
                    idx = apat[s % len(apat)]
                    if idx is None:
                        continue
                    nn = ton[idx % len(ton)]
                    sig = INSTRUMENTS[inst](freq(nn), int(step * beat * SR * 0.9))
                    add(dry, sig, bt + s * step * beat, arr.get("arp_gain", 0.18))
                    add(wet_send, sig, bt + s * step * beat, arr.get("arp_gain", 0.18) * 0.7)
            # pad (acorde sustentado)
            if arr.get("pad_gain"):
                for nn in tones[:3]:
                    sig = inst_pad(freq(nn - 12 + 12 * arr.get("pad_oct", 0)), int(tr.bpb * beat * SR))
                    add(dry, sig, bt, arr["pad_gain"])
                    add(wet_send, sig, bt, arr["pad_gain"])
            # acorde dedilhado (strum) no 1º tempo
            if arr.get("strum_gain"):
                for k, nn in enumerate(tones[:4]):
                    sig = inst_pluck(freq(nn), int(beat * SR))
                    add(dry, sig, bt + k * 0.018, arr["strum_gain"])
                    add(wet_send, sig, bt + k * 0.018, arr["strum_gain"])
            # bateria: padrões em frações de tempo dentro do compasso
            for kind, hits, g in arr.get("drums", []):
                for h in hits:
                    add(dry, drum(kind), bt + h * beat, g)
                    if kind in ("snare", "rim", "crash", "tom"):
                        add(wet_send, drum(kind), bt + h * beat, g * 0.5)
            for kind, every, g in arr.get("accents", []):
                if bi % every == 0:
                    add(dry, drum(kind), bt, g)
                    add(wet_send, drum(kind), bt, g * 0.5)
    wet = convolve(wet_send, reverb_ir(tr.t60))[: len(dry)]
    mix = dry + wet * tr.reverb * 2.2
    # recorta a 2ª volta: loop sem emenda
    a = int(round(L * SR))
    loop = mix[a: 2 * a]
    # master: corte de sub-grave e de chiado, saturação macia, normaliza
    loop = hp(loop, 35)
    loop = lp(loop, 11000)
    peak = np.max(np.abs(loop)) + 1e-9
    loop = np.tanh(loop / peak * 1.25) / np.tanh(1.25)
    return (loop * 0.82 * tr.gain).astype(np.float32)


# ---------------------------------------------------------------------------
# As faixas
# ---------------------------------------------------------------------------

FOUR_BASS = [(0, 1.5, 0), (1.5, 0.5, 7), (2, 1.5, 12), (3.5, 0.5, 7)]

TRACKS = {}

TRACKS["candelaria"] = Track(
    "candelaria", 92, 4,
    ["F", "C/E", "Dm", "Bb", "F", "C", "Bb", "C", "Dm", "Bb", "F", "C", "Dm", "Bb", "Gm7", "C7"],
    [
        ("flute", "A4:1 C5:1 F5:2 E5:1 D5:0.5 C5:0.5 G4:2 F4:1 A4:1 D5:1.5 C5:0.5 Bb4:1 A4:0.5 G4:0.5 F4:2 "
                  "A4:1 C5:1 F5:1 G5:1 E5:1.5 D5:0.5 C5:1 E5:1 D5:1 C5:0.5 Bb4:0.5 A4:1 G4:1 G4:1 A4:0.5 Bb4:0.5 C5:2 "
                  "D5:1.5 E5:0.5 F5:1 E5:1 D5:2 Bb4:1 C5:1 A4:1.5 Bb4:0.5 C5:1 A4:1 G4:3 r:1 "
                  "F5:1 E5:1 D5:1 A4:1 Bb4:1 D5:1 F5:2 E5:1 D5:1 C5:1 Bb4:1 C5:1 D5:0.5 E5:0.5 F5:2", 0.42, 0),
    ],
    {"bass_pattern": [(0, 1.5, 0), (2, 1.5, 7)], "bass_gain": 0.34,
     "arp_inst": "pluck", "arp_pattern": [0, 1, 2, 3, 2, 1, 0, 1], "arp_step": 0.5, "arp_gain": 0.2,
     "pad_gain": 0.05,
     "drums": [("kick", [0, 2.5], 0.35), ("rim", [1, 3], 0.25), ("shaker", [0.5, 1.5, 2.5, 3.5], 0.5)]},
    reverb=0.3, t60=1.8)

TRACKS["noite"] = Track(
    "noite", 70, 4,
    ["Dm", "Bb", "Gm", "A", "Dm", "F", "Bb", "A7", "Dm", "Bb", "Gm", "A", "Dm", "F", "Gm", "A7"],
    [
        ("flute", "A4:2 F4:1 E4:1 D4:3 r:1 G4:2 Bb4:1 A4:1 E4:3 r:1 A4:1 D5:2 C5:1 A4:3 r:1 Bb4:1 A4:1 G4:1 F4:1 E4:2 C#4:1 E4:1 "
                  "D5:2 C5:1 A4:1 Bb4:3 r:1 G4:1 A4:1 Bb4:1 D5:1 C#5:3 r:1 D5:1 F5:2 E5:1 C5:3 r:1 Bb4:1 A4:1 G4:1 E4:1 D4:3 r:1", 0.34, 0),
    ],
    {"arp_inst": "bell", "arp_pattern": [0, None, 2, None, 3, None, 2, None], "arp_step": 0.5, "arp_gain": 0.12, "arp_up_oct": 1,
     "pad_gain": 0.09, "bass_pattern": [(0, 3.5, 0)], "bass_gain": 0.3},
    reverb=0.45, t60=2.6, gain=0.9)

TRACKS["estrada"] = Track(
    "estrada", 118, 4,
    ["Am", "F", "C", "G", "Am", "F", "G", "E7", "F", "G", "Am", "Am/G", "F", "G", "Esus4", "E"],
    [
        ("pulse", "A4:0.5 C5:0.5 E5:1 D5:0.5 C5:0.5 B4:1 A4:0.5 C5:0.5 F5:1 E5:1 C5:1 G4:0.5 C5:0.5 E5:1 G5:1 E5:1 D5:1.5 B4:0.5 G4:2 "
                  "A4:0.5 C5:0.5 E5:1 A5:1 G5:1 F5:1 E5:0.5 D5:0.5 C5:1 A4:1 B4:1 D5:1 G5:1 F5:1 E5:2 G#4:1 B4:1 "
                  "C5:1 F5:1 A5:1.5 G5:0.5 G5:1 F5:1 D5:2 E5:1 A5:1 C6:1 B5:1 A5:3 r:1 "
                  "F5:1 A5:1 C6:1 A5:1 G5:1 B5:1 D6:1 B5:1 A5:2 G5:1 F5:1 E5:2 G#5:1 B5:1", 0.3, 0),
    ],
    {"bass_inst": "bass_drive", "bass_pattern": [(0, 0.5, 0), (0.5, 0.5, 12), (1, 0.5, 0), (1.5, 0.5, 12), (2, 0.5, 0), (2.5, 0.5, 12), (3, 0.5, 7), (3.5, 0.5, 12)],
     "bass_gain": 0.36, "arp_pattern": [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 1, 2, 3], "arp_step": 0.25, "arp_gain": 0.11, "arp_up_oct": 1,
     "pad_gain": 0.04,
     "drums": [("kick", [0, 1.5, 2], 0.5), ("snare", [1, 3], 0.38), ("hat", [0.5, 1.5, 2.5, 3.5], 0.5)],
     "accents": [("crash", 8, 0.5)]},
    reverb=0.2, t60=1.3)

TRACKS["frenesi"] = Track(
    "frenesi", 152, 4,
    ["Em", "C", "D", "B7", "Em", "C", "Am", "B", "Em", "C", "D", "B7", "Em", "C", "Am", "B7"],
    [
        ("pulse", "E5:0.5 G5:0.5 B5:0.5 G5:0.5 E5:0.5 B4:0.5 E5:1 C5:0.5 E5:0.5 G5:0.5 E5:0.5 C6:1 B5:1 "
                  "A5:0.5 F#5:0.5 D5:0.5 F#5:0.5 A5:1 D6:1 B5:1.5 A5:0.5 F#5:1 D#5:1 "
                  "E5:0.5 E5:0.5 G5:0.5 B5:0.5 E6:1 D6:1 C6:1 B5:0.5 A5:0.5 G5:1 E5:1 "
                  "A5:0.5 C6:0.5 E6:0.5 C6:0.5 A5:1 G5:1 F#5:1 D#5:1 B4:2", 0.28, 0),
    ],
    {"bass_inst": "bass_drive", "bass_pattern": [(i * 0.5, 0.5, 0 if i % 4 != 3 else 12) for i in range(8)], "bass_gain": 0.38,
     "arp_pattern": [0, 2, 1, 3, 0, 2, 1, 3, 2, 3, 1, 2, 0, 1, 2, 3], "arp_step": 0.25, "arp_gain": 0.1, "arp_up_oct": 1,
     "drums": [("kick", [0, 1, 2, 3], 0.55), ("snare", [1, 3], 0.4), ("hat", [0.5, 1.5, 2.5, 3.5, 0.25, 1.25, 2.25, 3.25], 0.35)],
     "accents": [("crash", 4, 0.45)]},
    reverb=0.16, t60=1.1)

TRACKS["guardiao"] = Track(
    "guardiao", 140, 4,
    ["Cm", "Ab", "Fm", "G", "Cm", "Ab", "Db", "G7", "Cm", "Bb", "Ab", "G", "Fm", "G", "Ab", "G7b9"],
    [
        ("pulse", "C5:1 Eb5:1 G5:1 C6:1 Ab5:1.5 G5:0.5 Eb5:2 F5:1 Ab5:1 C6:1 Ab5:1 G5:2 B4:1 D5:1 "
                  "Eb5:1 D5:0.5 C5:0.5 G5:2 Ab5:1 C6:1 Eb6:1 C6:1 Db6:1.5 C6:0.5 Ab5:1 F5:1 G5:2 B5:1 D6:1 "
                  "C6:2 G5:2 Bb5:1 D6:1 F6:2 Eb6:1 C6:1 Ab5:2 B5:2 D6:2 "
                  "F5:1 Ab5:1 C6:1 F6:1 D6:1 B5:1 G5:1 F5:1 Eb5:1 F5:1 G5:1 Ab5:1 B5:2 G5:2", 0.3, 0),
        ("flute", "C4:4 Ab3:4 F3:4 G3:4 C4:4 Ab3:4 Db4:4 G3:4 C4:4 Bb3:4 Ab3:4 G3:4 F3:4 G3:4 Ab3:4 G3:4", 0.12, 1),
    ],
    {"bass_inst": "bass_drive", "bass_pattern": [(0, 0.5, 0), (0.5, 0.5, 0), (1, 0.5, 12), (1.5, 0.5, 0), (2, 0.5, 0), (2.5, 0.5, 7), (3, 0.5, 12), (3.5, 0.5, 7)],
     "bass_gain": 0.4, "pad_gain": 0.06,
     "drums": [("kick", [0, 0.75, 2, 2.5], 0.55), ("snare", [1, 3], 0.42), ("hat", [0.5, 1.5, 2.5, 3.5], 0.35), ("tom", [3.5, 3.75], 0.18)],
     "accents": [("crash", 4, 0.5)]},
    reverb=0.22, t60=1.5)

TRACKS["lareira"] = Track(
    "lareira", 104, 3,
    ["G", "D/F#", "Em", "C", "G", "Am", "D", "D7", "C", "G/B", "Am", "D", "G", "Em", "D", "G"],
    [
        ("flute", "B4:1 D5:1 G5:1 F#5:2 E5:1 E5:1 G5:1 B4:1 C5:2 E5:1 D5:1 B4:1 G4:1 A4:1 C5:1 E5:1 D5:2 C5:1 A4:3 "
                  "E5:1 G5:1 C6:1 B5:2 G5:1 A5:1 G5:1 E5:1 F#5:2 D5:1 G5:1 B5:1 D6:1 B5:2 G5:1 A5:1 C6:0.5 B5:0.5 A5:1 G5:3", 0.36, 0),
    ],
    {"bass_pattern": [(0, 1, 0), (1, 1, 7), (2, 1, 12)], "bass_gain": 0.3,
     "arp_inst": "bell", "arp_pattern": [None, None, 2, 3, 2, 3], "arp_step": 0.5, "arp_gain": 0.1, "arp_up_oct": 1,
     "strum_gain": 0.14, "pad_gain": 0.035,
     "drums": [("shaker", [1, 2], 0.45)]},
    reverb=0.34, t60=2.0)


def main():
    import soundfile as sf
    os.makedirs(OUT, exist_ok=True)
    wav_dir = None
    if "--wav" in sys.argv:
        wav_dir = sys.argv[sys.argv.index("--wav") + 1]
        os.makedirs(wav_dir, exist_ok=True)
    names = [a for a in sys.argv[1:] if a in TRACKS] or list(TRACKS.keys())
    for name in names:
        tr = TRACKS[name]
        audio = render(tr)
        path = os.path.join(OUT, name + ".ogg")
        sf.write(path, audio, SR, format="OGG", subtype="VORBIS")
        if wav_dir:
            sf.write(os.path.join(wav_dir, name + ".wav"), audio, SR)
        print("%-11s %5.1f s  %4d KB" % (name, len(audio) / SR, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
