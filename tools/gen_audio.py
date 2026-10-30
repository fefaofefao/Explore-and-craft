# -*- coding: utf-8 -*-
"""Sintetiza efeitos sonoros e músicas em loop (WAV 22 kHz mono) — sem assets de terceiros.
Uso: python3 tools/gen_audio.py
"""
import os
import wave
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
rng = np.random.default_rng(7)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, total=None):
    total = total or n
    e = np.zeros(total)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    e[:ai] = np.linspace(0, 1, ai, endpoint=False) if ai else 1
    e[ai:ai + di] = np.linspace(1, s, max(1, di))[: len(e[ai:ai + di])]
    e[ai + di:] = s
    if ri and s > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def tone(freq, d, wave_="sine", vib=0.0):
    t = t_(d)
    f = freq if np.isscalar(freq) else freq
    ph = 2 * np.pi * np.cumsum(np.full(len(t), f) if np.isscalar(f) else f) / SR
    if vib:
        ph += vib * np.sin(2 * np.pi * 5 * t)
    if wave_ == "sine":
        return np.sin(ph)
    if wave_ == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if wave_ == "square":
        return np.sign(np.sin(ph)) * 0.6
    if wave_ == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    return np.sin(ph)


def noise(d, color=0.0):
    n = rng.standard_normal(int(SR * d))
    if color > 0:  # passa-baixa simples
        out = np.zeros_like(n)
        acc = 0.0
        for i, v in enumerate(n):
            acc += (v - acc) * (1 - color)
            out[i] = acc
        n = out / (np.abs(out).max() + 1e-9)
    return n


def sweep(f0, f1, d):
    return np.linspace(f0, f1, int(SR * d))


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.abs(x).max() + 1e-9
    x = x / m * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(notes, d, wave_="tri", dec=0.18):
    out = []
    for f in notes:
        x = tone(f, d, wave_) * env(int(SR * d), 0.004, dec, 0.0)
        out.append(x)
    return np.concatenate(out)


def sfx():
    s = {}
    s["click"] = tone(sweep(900, 600, 0.05), 0.05) * env(int(SR * 0.05), 0.001, 0.04)
    s["step"] = noise(0.06, 0.8) * env(int(SR * 0.06), 0.002, 0.05) * 0.5
    s["jump"] = tone(sweep(300, 700, 0.15), 0.15, "tri") * env(int(SR * 0.15), 0.005, 0.14)
    s["hurt"] = mix(tone(sweep(400, 150, 0.2), 0.2, "square") * env(int(SR * 0.2), 0.002, 0.18), noise(0.12, 0.5) * 0.3 * env(int(SR * 0.12), 0.001, 0.1))
    s["swing"] = noise(0.18, 0.6) * np.sin(np.linspace(0, np.pi, int(SR * 0.18))) * 0.7
    s["hit_soft"] = mix(noise(0.08, 0.7) * env(int(SR * 0.08), 0.001, 0.07), tone(sweep(220, 120, 0.1), 0.1) * env(int(SR * 0.1), 0.001, 0.09))
    s["hit_hard"] = mix(noise(0.18, 0.5) * env(int(SR * 0.18), 0.001, 0.16), tone(sweep(160, 50, 0.22), 0.22) * env(int(SR * 0.22), 0.001, 0.2))
    s["chop"] = mix(noise(0.1, 0.85) * env(int(SR * 0.1), 0.001, 0.08), tone(sweep(260, 180, 0.08), 0.08, "tri") * env(int(SR * 0.08), 0.001, 0.07) * 0.6)
    s["mine"] = mix(tone(1800, 0.25, "sine") * env(int(SR * 0.25), 0.001, 0.24) * 0.5, tone(2600, 0.2) * env(int(SR * 0.2), 0.001, 0.15) * 0.3, noise(0.05, 0.3) * 0.4)
    s["gather"] = mix(noise(0.12, 0.9) * env(int(SR * 0.12), 0.01, 0.1), seq([880, 1320], 0.06, "sine", 0.05) * 0.3)
    s["throw"] = noise(0.25, 0.7) * np.sin(np.linspace(0, np.pi, int(SR * 0.25))) * 0.6
    s["shake"] = mix(tone(sweep(500, 300, 0.12), 0.12, "tri") * env(int(SR * 0.12), 0.002, 0.11), noise(0.05, 0.6) * 0.3)
    s["capture_in"] = tone(sweep(200, 1400, 0.4), 0.4, "sine") * env(int(SR * 0.4), 0.01, 0.38)
    s["capture_ok"] = np.concatenate([seq([523, 659, 784], 0.09, "tri", 0.08), tone(1047, 0.5, "tri", 0.2) * env(int(SR * 0.5), 0.005, 0.5)])
    s["capture_fail"] = seq([400, 300, 220], 0.12, "square", 0.1)
    s["level_up"] = np.concatenate([seq([523, 659, 784, 1047], 0.08, "square", 0.07), tone(1319, 0.6, "tri", 0.3) * env(int(SR * 0.6), 0.005, 0.6)])
    s["quest"] = np.concatenate([seq([392, 523, 659], 0.11, "tri", 0.1), mix(tone(784, 0.7, "tri"), tone(988, 0.7, "sine") * 0.5) * env(int(SR * 0.7), 0.01, 0.7)])
    s["craft"] = mix(seq([660, 990, 1320], 0.07, "sine", 0.06), noise(0.08, 0.5) * 0.2)
    s["build"] = mix(noise(0.2, 0.75) * env(int(SR * 0.2), 0.001, 0.18), tone(sweep(150, 90, 0.2), 0.2) * env(int(SR * 0.2), 0.001, 0.18))
    s["coin"] = seq([1319, 1760], 0.08, "square", 0.07) * 0.5
    s["eat"] = np.concatenate([noise(0.06, 0.8) * env(int(SR * 0.06), 0.001, 0.05)] * 3)
    s["heal"] = mix(*[tone(f, 0.6, "sine") * env(int(SR * 0.6), 0.05 + i * 0.05, 0.5) * 0.4 for i, f in enumerate([523, 659, 784, 1047])])
    s["buff"] = tone(sweep(300, 900, 0.35), 0.35, "tri") * env(int(SR * 0.35), 0.01, 0.33)
    s["skill_shot"] = mix(tone(sweep(900, 300, 0.22), 0.22, "saw") * env(int(SR * 0.22), 0.002, 0.2) * 0.4, noise(0.15, 0.6) * 0.3)
    s["skill_aoe"] = mix(noise(0.6, 0.85) * env(int(SR * 0.6), 0.01, 0.55), tone(sweep(120, 40, 0.6), 0.6) * env(int(SR * 0.6), 0.005, 0.55))
    s["summon"] = tone(sweep(400, 1200, 0.3), 0.3, "tri") * env(int(SR * 0.3), 0.01, 0.28)
    s["faint"] = tone(sweep(600, 120, 0.6), 0.6, "tri") * env(int(SR * 0.6), 0.01, 0.58)
    s["fragment"] = mix(*[tone(f, 1.2, "sine") * env(int(SR * 1.2), 0.02 + i * 0.12, 1.0) * 0.4 for i, f in enumerate([659, 880, 1109, 1319, 1760])])
    s["relic"] = mix(*[tone(f, 1.6, "tri") * env(int(SR * 1.6), 0.03 + i * 0.1, 1.5) * 0.4 for i, f in enumerate([262, 392, 523, 659, 784])])
    s["portal"] = mix(tone(sweep(200, 800, 0.8), 0.8, "sine", 3) * env(int(SR * 0.8), 0.05, 0.75), noise(0.8, 0.9) * 0.3 * env(int(SR * 0.8), 0.2, 0.6))
    s["dialog"] = tone(sweep(700, 760, 0.04), 0.04, "square") * env(int(SR * 0.04), 0.001, 0.035) * 0.4
    s["error"] = seq([220, 180], 0.09, "square", 0.08) * 0.6
    s["happy"] = seq([784, 988, 1175, 988, 1319], 0.07, "sine", 0.06)
    for k, v in s.items():
        save(k, v, 0.7)
    return len(s)


# ------------------------------------------------------------------ música
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def chord(root, kind):
    iv = {"maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10]}[kind]
    return [root + i for i in iv]


def pad(midis, d, wave_="tri"):
    n = int(SR * d)
    x = np.zeros(n)
    for m in midis:
        x += tone(hz(m), d, wave_) * 0.3 + tone(hz(m) * 1.003, d, "sine") * 0.2
    e = np.minimum(1, np.minimum(np.arange(n) / (0.3 * SR), (n - np.arange(n)) / (0.4 * SR)))
    return x * e


def pluck(m, d, wave_="tri", dec=0.35):
    return tone(hz(m), d, wave_) * env(int(SR * d), 0.003, dec, 0.0)


def kick(d):
    n = int(SR * d)
    return tone(sweep(120, 40, d), d) * env(n, 0.001, 0.25)


def hat(d):
    return noise(d, 0.0) * env(int(SR * d), 0.001, 0.03) * 0.25


def song(name, key, prog, bpm, bars, wave_pad="tri", wave_lead="tri", scale="maj", perc=True, lead_density=0.6, seed=1):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = int(SR * bar * bars)
    out = np.zeros(total)
    sc = [0, 2, 4, 5, 7, 9, 11] if scale == "maj" else ([0, 2, 3, 5, 7, 8, 10] if scale == "min" else [0, 2, 4, 7, 9])
    for b in range(bars):
        root, kind = prog[b % len(prog)]
        start = int(SR * bar * b)
        p = pad(chord(key + root, kind), bar, wave_pad) * 0.5
        bass = np.concatenate([pluck(key + root - 24, beat * 2, "sine", 0.9)] * 2) * 0.6
        bass = np.pad(bass, (0, max(0, len(p) - len(bass))))[: len(p)]
        seg = p + bass
        # melodia: notas da escala, com tendência às notas do acorde
        for st in range(8):
            if r.random() < lead_density:
                deg = r.integers(0, len(sc))
                m = key + 12 + sc[deg] + (12 if r.random() < 0.2 else 0)
                note = pluck(m, beat / 2, wave_lead, 0.25) * 0.35
                i0 = int(SR * beat / 2 * st)
                seg[i0:i0 + len(note)] += note[: len(seg) - i0]
        if perc:
            for bt in range(4):
                i0 = int(SR * beat * bt)
                k = kick(0.25) * (0.5 if bt % 2 == 0 else 0.0)
                seg[i0:i0 + len(k)] += k[: len(seg) - i0]
                h = hat(0.05)
                i1 = i0 + int(SR * beat / 2)
                seg[i1:i1 + len(h)] += h[: max(0, len(seg) - i1)]
        out[start:start + len(seg)] += seg[: total - start]
    # suaviza as pontas para loop sem clique
    f = int(SR * 0.05)
    out[:f] *= np.linspace(0, 1, f)
    out[-f:] *= np.linspace(1, 0, f)
    save("music_" + name, out, 0.55)


def music():
    C, D, E, F, G, A = 60, 62, 64, 65, 67, 57
    song("title", D - 12 + 12, [(0, "maj7"), (5, "maj"), (9, "min7"), (7, "sus")], 72, 8, "tri", "sine", "maj", False, 0.45, 1)
    song("forest", G - 12, [(0, "maj"), (5, "maj"), (9, "min"), (7, "maj")], 92, 8, "tri", "tri", "maj", True, 0.55, 2)
    song("desert", D - 12, [(0, "min"), (1, "maj"), (0, "min"), (10, "maj")], 84, 8, "saw", "sine", "min", True, 0.5, 3)
    song("snow", E - 12, [(0, "min7"), (8, "maj7"), (3, "maj"), (10, "sus")], 66, 8, "sine", "sine", "min", False, 0.35, 4)
    song("city", C - 12, [(0, "min"), (8, "maj"), (3, "maj"), (10, "maj")], 100, 8, "saw", "square", "min", True, 0.5, 5)
    song("swamp", A - 12, [(0, "min"), (3, "min"), (5, "maj"), (0, "min")], 70, 8, "tri", "tri", "min", False, 0.35, 6)
    song("volcano", D - 12, [(0, "min"), (1, "maj"), (5, "min"), (3, "maj")], 110, 8, "saw", "saw", "min", True, 0.55, 7)
    song("storm", F - 12, [(0, "min"), (10, "maj"), (8, "maj"), (7, "maj")], 104, 8, "saw", "tri", "min", True, 0.6, 8)
    song("battle", E - 12, [(0, "min"), (8, "maj"), (10, "maj"), (7, "maj")], 132, 8, "saw", "square", "min", True, 0.75, 9)
    return 9


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    n = sfx()
    m = music()
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"{n} efeitos + {m} músicas ({total / 1e6:.1f} MB)")
