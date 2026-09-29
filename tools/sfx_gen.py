#!/usr/bin/env python3
"""Gera os efeitos sonoros do jogo por síntese (estilo chiptune/limpo, coerente
com a pixel art). Sem dependências: só math/random/wave/array.

Uso: python3 tools/sfx_gen.py  -> escreve assets/audio/gen/g_<nome>_<n>.wav

Cada efeito tem 2-3 variações (o Audio sorteia uma e ainda varia o pitch).
"""
import array
import math
import os
import random
import wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "gen")
TAU = math.tau


# ---------------------------------------------------------------------------
# blocos
# ---------------------------------------------------------------------------

def n_samples(dur):
    return max(1, int(dur * SR))


def silence(dur):
    return [0.0] * n_samples(dur)


def osc(kind, f0, f1, dur, duty=0.5, curve=1.0, vib=0.0, vib_hz=0.0, rnd=None):
    """Oscilador com varredura de frequência f0->f1 (curve>1 = cai rápido)."""
    rnd = rnd or random
    n = n_samples(dur)
    out = []
    ph = 0.0
    lfo = 0.0
    noise_v = 0.0
    noise_t = 0.0
    for i in range(n):
        t = i / n
        k = t ** curve
        f = f0 + (f1 - f0) * k
        if vib > 0.0:
            lfo += TAU * vib_hz / SR
            f *= 1.0 + vib * math.sin(lfo)
        ph += f / SR
        p = ph % 1.0
        if kind == "sine":
            v = math.sin(TAU * p)
        elif kind == "square":
            v = 1.0 if p < duty else -1.0
        elif kind == "tri":
            v = 4.0 * abs(p - 0.5) - 1.0
        elif kind == "saw":
            v = 2.0 * p - 1.0
        elif kind == "noise":
            # ruído "sample & hold" na frequência f (ruído de chip)
            noise_t += f / SR
            if noise_t >= 1.0:
                noise_t -= 1.0
                noise_v = rnd.uniform(-1.0, 1.0)
            v = noise_v
        else:
            v = 0.0
        out.append(v)
    return out


def white(dur, rnd=None):
    rnd = rnd or random
    return [rnd.uniform(-1.0, 1.0) for _ in range(n_samples(dur))]


def env(sig, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    """ADSR simples (em segundos). s = nível de sustentação."""
    n = len(sig)
    out = []
    a_n = max(1, int(a * SR))
    d_n = max(1, int(d * SR))
    h_n = int(hold * SR)
    r_n = max(1, int(r * SR))
    for i, v in enumerate(sig):
        if i < a_n:
            g = i / a_n
        elif i < a_n + d_n:
            g = 1.0 - (1.0 - s) * (i - a_n) / d_n
        elif i < a_n + d_n + h_n:
            g = s
        else:
            g = s
        left = n - i
        if left < r_n:
            g *= left / r_n
        out.append(v * g)
    return out


def exp_decay(sig, tau):
    return [v * math.exp(-i / (tau * SR)) for i, v in enumerate(sig)]


def lowpass(sig, cutoff0, cutoff1=None):
    cutoff1 = cutoff0 if cutoff1 is None else cutoff1
    out = []
    y = 0.0
    n = len(sig)
    for i, v in enumerate(sig):
        c = cutoff0 + (cutoff1 - cutoff0) * i / max(1, n - 1)
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (v - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [v - l for v, l in zip(sig, lp)]


def bandpass(sig, lo, hi):
    return highpass(lowpass(sig, hi), lo)


def mix(*parts):
    """mix((sinal, ganho, atraso_s), ...)"""
    length = 0
    for sig, _g, delay in parts:
        length = max(length, int(delay * SR) + len(sig))
    out = [0.0] * length
    for sig, g, delay in parts:
        off = int(delay * SR)
        for i, v in enumerate(sig):
            out[off + i] += v * g
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def crush(sig, bits=7):
    q = 2 ** (bits - 1)
    return [round(v * q) / q for v in sig]


def fm(fc, fm_ratio, index, dur, decay=0.3, index_decay=None):
    """FM simples (sinos, metais)."""
    n = n_samples(dur)
    out = []
    idx_tau = index_decay or decay
    for i in range(n):
        t = i / SR
        idx = index * math.exp(-t / idx_tau)
        v = math.sin(TAU * fc * t + idx * math.sin(TAU * fc * fm_ratio * t))
        out.append(v * math.exp(-t / decay))
    return out


def echo(sig, delay=0.07, fb=0.35, taps=3):
    out = list(sig) + [0.0] * int(delay * SR * taps)
    d = int(delay * SR)
    g = fb
    for k in range(1, taps + 1):
        for i, v in enumerate(sig):
            out[i + d * k] += v * g
        g *= fb
    return out


def normalize(sig, peak=0.85):
    m = max(1e-6, max(abs(v) for v in sig))
    return [v / m * peak for v in sig]


def fade_tail(sig, dur=0.01):
    n = min(len(sig), int(dur * SR))
    out = list(sig)
    for i in range(n):
        out[-1 - i] *= i / n
    return out


def save(name, sig, peak=0.85):
    sig = fade_tail(normalize(sig, peak))
    data = array.array("h", [int(max(-1.0, min(1.0, v)) * 32767) for v in sig])
    path = os.path.join(OUT, "g_%s.wav" % name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
# efeitos
# ---------------------------------------------------------------------------

def note(n):
    """nota MIDI -> Hz"""
    return 440.0 * 2 ** ((n - 69) / 12.0)


def make_all():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("g_") and f.endswith(".wav"):
            os.remove(os.path.join(OUT, f))
    R = random.Random(7)

    for v in range(3):
        r = random.Random(100 + v)
        # pulo: blip quadrado subindo
        base = 360 + v * 30
        s = env(osc("square", base, base * 2.1, 0.09, duty=0.25, curve=0.6), 0.002, 0.08, 0.0, 0.02)
        s = mix((s, 0.55, 0), (env(white(0.03, r), 0.001, 0.03), 0.12, 0))
        save("jump_%d" % v, lowpass(s, 6000))
        # pulo no ar / pulo extra: dois degraus + brilho
        a = env(osc("square", 520 + v * 40, 780 + v * 40, 0.05, duty=0.25), 0.002, 0.05)
        b = env(osc("tri", 900 + v * 50, 1500 + v * 60, 0.08), 0.002, 0.08)
        save("djump_%d" % v, mix((a, 0.5, 0), (b, 0.6, 0.045), (env(osc("sine", 2600, 3100, 0.1), 0.002, 0.1), 0.15, 0.06)))
        # dash: sopro de ruído com filtro varrendo + batida grave
        w = white(0.2, r)
        w = lowpass(w, 900 + v * 200, 5200)
        w = highpass(w, 400)
        w = env(w, 0.004, 0.19, 0.0, 0.03)
        thump = exp_decay(osc("sine", 150, 60, 0.08), 0.03)
        save("dash_%d" % v, mix((w, 0.9, 0), (thump, 0.5, 0)))
        # chute de parede: pancada + ruído + chirp subindo
        th = exp_decay(osc("sine", 190, 55, 0.1), 0.035)
        nz = env(bandpass(white(0.08, r), 500, 3500), 0.001, 0.07)
        ch = env(osc("square", 280 + v * 20, 980 + v * 40, 0.11, duty=0.3, curve=0.7), 0.002, 0.1)
        save("wallkick_%d" % v, mix((th, 0.9, 0), (nz, 0.5, 0), (ch, 0.35, 0.015)))
        # salto de parede comum: toque leve
        save("walljump_%d" % v, mix((exp_decay(osc("sine", 170, 70, 0.06), 0.025), 0.8, 0), (env(osc("square", 420 + v * 25, 820, 0.07, duty=0.25), 0.002, 0.07), 0.35, 0)))
        # recarga na parede: ping de vidro
        f = note(84 + v * 2)
        g = mix((exp_decay(osc("sine", f, f, 0.22), 0.07), 0.8, 0), (exp_decay(osc("sine", f * 1.5, f * 1.5, 0.18), 0.05), 0.35, 0))
        save("wallrefill_%d" % v, g, 0.6)
        # orbe: "boing" com brilho
        bo = env(osc("sine", 240 + v * 20, 700 + v * 30, 0.16, vib=0.05, vib_hz=28), 0.002, 0.16)
        ch2 = exp_decay(osc("tri", note(81 + v), note(81 + v), 0.25), 0.08)
        save("orb_%d" % v, mix((bo, 0.8, 0), (ch2, 0.45, 0.02)))
        # sino: FM com parciais inarmônicas
        fb = note(79 + v * 3)
        bell = mix((fm(fb, 2.76, 3.0, 1.0, decay=0.35, index_decay=0.12), 0.8, 0), (fm(fb * 2, 1.41, 1.5, 0.6, decay=0.15), 0.3, 0))
        save("bell_%d" % v, echo(bell, 0.09, 0.3, 2), 0.7)
        # pena: arpejo leve subindo
        notes = [84, 88, 91, 96] if v == 0 else ([83, 86, 90, 95] if v == 1 else [86, 89, 93, 98])
        arp = []
        for i, nn in enumerate(notes):
            arp.append((exp_decay(osc("tri", note(nn), note(nn), 0.12), 0.05), 0.5, i * 0.03))
        arp.append((env(highpass(white(0.14, r), 5000), 0.01, 0.13), 0.08, 0))
        save("feather_%d" % v, mix(*arp), 0.7)
        # cristal: ping FM agudo com vibrato
        fc = note(88 + v)
        save("crystal_%d" % v, echo(mix((fm(fc, 3.5, 1.2, 0.35, decay=0.12), 0.8, 0), (exp_decay(osc("sine", fc * 2, fc * 2, 0.2), 0.05), 0.25, 0.01)), 0.06, 0.25, 2), 0.7)
        # pogo: mola + tique metálico
        sp = env(osc("square", 180 + v * 15, 520 + v * 30, 0.1, duty=0.2, curve=0.5), 0.002, 0.1)
        tk = exp_decay(osc("square", 2400, 2200, 0.03, duty=0.5), 0.008)
        save("pogo_%d" % v, mix((sp, 0.6, 0), (tk, 0.25, 0)))
        # corte leve: "shff" curto
        sl = env(bandpass(white(0.09, r), 1200 + v * 300, 7000), 0.003, 0.085)
        save("slash_%d" % v, mix((sl, 1.0, 0), (env(osc("saw", 900 + v * 80, 300, 0.06), 0.002, 0.06), 0.08, 0)), 0.7)
        # corte pesado: mais longo e grave
        sh = env(lowpass(white(0.17, r), 3000, 900), 0.006, 0.16)
        save("slashheavy_%d" % v, mix((sh, 1.0, 0), (exp_decay(osc("sine", 120, 70, 0.14), 0.06), 0.4, 0.02)), 0.75)
        # acerto: clique + soco grave + estalo
        ht = mix((exp_decay(osc("sine", 140 + v * 10, 60, 0.09), 0.03), 0.9, 0),
                 (env(bandpass(white(0.05, r), 800, 5000), 0.001, 0.045), 0.6, 0),
                 (exp_decay(osc("square", 900 + v * 60, 500, 0.04, duty=0.4), 0.012), 0.2, 0))
        save("hit_%d" % v, crush(ht, 9))
        # acerto pesado
        hh = mix((exp_decay(osc("sine", 110, 40, 0.18), 0.06), 1.0, 0),
                 (env(lowpass(white(0.12, r), 2500), 0.001, 0.11), 0.7, 0),
                 (exp_decay(osc("square", 600, 200, 0.08, duty=0.4), 0.03), 0.25, 0))
        save("hitheavy_%d" % v, crush(hh, 8))
        # abate: estouro + chirp descendo
        kl = mix((env(osc("square", 900 + v * 70, 180, 0.2, duty=0.3, curve=0.5), 0.002, 0.2), 0.4, 0),
                 (env(lowpass(white(0.18, r), 4000, 600), 0.001, 0.17), 0.7, 0),
                 (exp_decay(osc("sine", 130, 45, 0.15), 0.05), 0.6, 0))
        save("kill_%d" % v, crush(kl, 8))
        # rebater: "ting" metálico que sobe
        rf = mix((fm(note(93 + v), 1.5, 2.0, 0.3, decay=0.1), 0.6, 0), (env(osc("square", 900, 2200, 0.08, duty=0.25), 0.002, 0.08), 0.3, 0))
        save("reflect_%d" % v, rf, 0.75)
        # tiro da torreta: "pew"
        pw = env(osc("square", 1300 + v * 90, 260, 0.12, duty=0.35, curve=0.5), 0.001, 0.12)
        save("turretshot_%d" % v, lowpass(pw, 5000), 0.6)
        # pouso: baque macio
        ld = mix((exp_decay(osc("sine", 95 + v * 8, 50, 0.07), 0.025), 0.9, 0), (env(lowpass(white(0.05, r), 1500), 0.001, 0.045), 0.5, 0))
        save("land_%d" % v, ld, 0.6)
        # passo
        save("step_%d" % v, env(bandpass(white(0.03, r), 300 + v * 100, 2500), 0.001, 0.028), 0.4)
        # dano no herói: zumbido áspero
        hu = mix((env(osc("square", 260 + v * 15, 110, 0.2, duty=0.5), 0.002, 0.2), 0.5, 0), (env(lowpass(white(0.15, r), 3000), 0.001, 0.13), 0.5, 0))
        save("hurt_%d" % v, crush(hu, 7))
        # nota da cadeia aérea (o pitch sobe no jogo)
        save("chain_%d" % v, exp_decay(osc("tri", note(79 + v * 0), note(79), 0.14), 0.05), 0.55)
        # passo de corrida da muralha / estalo de tábua
        cr = mix((env(bandpass(white(0.12, r), 200, 1800), 0.001, 0.11), 0.8, 0), (exp_decay(osc("sine", 90, 50, 0.1), 0.04), 0.5, 0.02))
        save("crumble_%d" % v, cr, 0.6)
        # mola
        save("spring_%d" % v, env(osc("sine", 160, 900, 0.22, vib=0.08, vib_hz=35, curve=0.6), 0.002, 0.22), 0.7)

    # únicos (1 variação)
    r = random.Random(900)
    # fim da cadeia: arpejo maior subindo com eco
    parts = []
    for i, nn in enumerate([72, 76, 79, 84, 88]):
        parts.append((exp_decay(osc("square", note(nn), note(nn), 0.16, duty=0.25), 0.07), 0.35, i * 0.045))
    save("chainend_0", echo(mix(*parts), 0.08, 0.3, 2), 0.7)
    # morte
    de = mix((env(osc("square", 620, 70, 0.9, duty=0.5, curve=0.7, vib=0.06, vib_hz=9), 0.002, 0.85), 0.45, 0),
             (env(lowpass(white(0.6, r), 2000, 200), 0.002, 0.55), 0.5, 0))
    save("death_0", crush(de, 7))
    # renascer: sopro ao contrário + brilho
    rs = env(lowpass(white(0.3, r), 400, 5000), 0.25, 0.04)
    save("respawn_0", mix((rs, 0.6, 0), (exp_decay(osc("tri", note(84), note(84), 0.3), 0.1), 0.4, 0.26)), 0.6)
    # torreta quebrando
    tb = mix((env(lowpass(white(0.35, r), 5000, 300), 0.001, 0.33), 0.8, 0), (exp_decay(osc("sine", 120, 35, 0.3), 0.1), 0.8, 0),
             (env(osc("square", 700, 120, 0.2, duty=0.3), 0.001, 0.2), 0.2, 0))
    save("turretbreak_0", crush(tb, 7))
    # ronco da muralha (início da fuga)
    ru = mix((env(lowpass(white(1.1, r), 180), 0.08, 1.0), 1.0, 0), (env(osc("saw", 55, 40, 1.1), 0.1, 1.0), 0.25, 0))
    save("rumble_0", ru, 0.8)
    # portão fechando / sala limpa
    save("gate_0", mix((exp_decay(osc("sine", 90, 45, 0.3), 0.1), 1.0, 0), (env(bandpass(white(0.2, r), 200, 2000), 0.001, 0.18), 0.6, 0)), 0.8)
    parts = []
    for i, nn in enumerate([67, 72, 76, 79]):
        parts.append((exp_decay(osc("square", note(nn), note(nn), 0.3, duty=0.25), 0.12), 0.3, i * 0.07))
    save("clear_0", echo(mix(*parts), 0.1, 0.25, 2), 0.7)
    # aparo perfeito
    save("parry_0", echo(mix((fm(note(96), 1.4, 3.0, 0.5, decay=0.18), 0.7, 0), (exp_decay(osc("sine", note(108), note(108), 0.3), 0.08), 0.2, 0)), 0.07, 0.35, 3), 0.75)

    # magias por elemento (2 variações)
    for v in range(2):
        r = random.Random(500 + v)
        # fogo: whoosh grave + crepitar
        fw = env(lowpass(white(0.35, r), 600, 2500), 0.02, 0.3)
        crack = []
        for k in range(10):
            crack.append((exp_decay(bandpass(white(0.02, r), 2000, 8000), 0.004), r.uniform(0.2, 0.5), r.uniform(0.0, 0.3)))
        save("fire_%d" % v, mix((fw, 0.9, 0), (exp_decay(osc("sine", 110, 55, 0.3), 0.1), 0.5, 0), *crack), 0.75)
        # gelo: brilho vítreo
        ice = []
        for k, nn in enumerate([96, 100, 103, 98, 105][v:v + 4]):
            ice.append((fm(note(nn), 3.1, 1.0, 0.3, decay=0.1), 0.35, k * 0.035))
        ice.append((env(highpass(white(0.25, r), 6000), 0.01, 0.24), 0.12, 0))
        save("ice_%d" % v, echo(mix(*ice), 0.07, 0.3, 2), 0.7)
        # raio: zap chiado
        zp = []
        n = n_samples(0.28)
        for i in range(n):
            t = i / SR
            f = 70 + 40 * math.sin(TAU * 13 * t)
            zp.append((1.0 if (t * f) % 1.0 < 0.5 else -1.0) * r.uniform(0.5, 1.0))
        zp = env(zp, 0.001, 0.27)
        save("bolt_%d" % v, crush(mix((zp, 0.6, 0), (env(highpass(white(0.12, r), 3000), 0.001, 0.11), 0.5, 0)), 6), 0.75)
        # sombra/vazio: drone FM descendo
        vd = mix((fm(180 - v * 20, 0.5, 4.0, 0.6, decay=0.3, index_decay=0.4), 0.8, 0), (env(osc("sine", 90, 45, 0.6), 0.05, 0.55), 0.4, 0))
        save("void_%d" % v, vd, 0.75)
        # cura: acorde suave subindo
        hl = []
        for k, nn in enumerate([72, 76, 79, 84]):
            hl.append((env(osc("sine", note(nn + v), note(nn + v), 0.45), 0.05, 0.4), 0.3, k * 0.06))
        save("heal_%d" % v, mix(*hl), 0.65)
        # vento: sopro filtrado ondulando
        wd = env(bandpass(white(0.45, r), 300, 2200), 0.08, 0.36)
        save("wind_%d" % v, wd, 0.7)
        # arcano: brilho FM + subida
        ar = mix((fm(note(84 + v * 2), 2.0, 2.5, 0.35, decay=0.15), 0.6, 0), (env(osc("tri", 400, 1600, 0.25), 0.01, 0.24), 0.35, 0))
        save("arcane_%d" % v, echo(ar, 0.06, 0.3, 2), 0.7)
        # terra/impacto pesado de magia
        ea = mix((exp_decay(osc("sine", 80, 35, 0.4), 0.15), 1.0, 0), (env(lowpass(white(0.35, r), 900, 200), 0.001, 0.3), 0.8, 0))
        save("earth_%d" % v, crush(ea, 8), 0.8)


if __name__ == "__main__":
    make_all()
    print("SFX gerados em", os.path.abspath(OUT))
