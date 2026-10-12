"""Genera los efectos de sonido del juego (assets/audio/sfx/*.ogg)."""
import os
import subprocess
import tempfile
import wave
import numpy as np
from synth import SR, lp, hp, bp, hz, bell, brass, choir, pluck, reverb_ir, fftconvolve

OUT = os.path.join(os.path.dirname(__file__), "../../assets/audio/sfx")
rng = np.random.default_rng(21)


def t_(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.standard_normal(int(d * SR))


def sweep_bp(x, f0, f1, width=0.6):
    """Ruido filtrado con un pasabanda que se mueve (por bloques)."""
    out = np.zeros_like(x)
    blocks = 24
    n = len(x) // blocks + 1
    for i in range(blocks):
        a, b = i * n, min((i + 1) * n + 256, len(x))
        if a >= len(x):
            break
        f = f0 * (f1 / f0) ** (i / (blocks - 1))
        seg = bp(x[max(0, a - 256):b], f * (1 - width / 2), f * (1 + width / 2))
        seg = seg[a - max(0, a - 256):]
        w = np.ones(len(seg))
        out[a:a + len(seg)] += seg * w
    return out


def env(d, a, decay):
    t = t_(d)
    return np.minimum(t / max(a, 1e-4), 1) * np.exp(-np.maximum(t - a, 0) * decay)


def bump(d, peak=0.4):
    t = t_(d)
    x = t / d
    return np.sin(np.pi * np.clip(x / peak, 0, 1) * 0.5) ** 2 * np.where(x < peak, 1, np.cos(np.pi * 0.5 * (x - peak) / (1 - peak)) ** 2)


def verb(x, amount=0.2, room=1.2):
    ir = reverb_ir(room, 4000)[0]
    w = fftconvolve(x, ir)[: len(x) + int(room * SR * 0.5)]
    y = np.zeros(len(w))
    y[: len(x)] += x
    return y + w * amount * 3


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(OUT, name + ".ogg")], check=True)


def mix(*xs):
    out = np.zeros(max(len(x) for x in xs))
    for x in xs:
        out[: len(x)] += x
    return out


def at(x, sec):
    return np.concatenate([np.zeros(int(sec * SR)), x])


def tone(f, d, decay=8.0, a=0.002):
    t = t_(d)
    return np.sin(2 * np.pi * f * t) * env(d, a, decay)


def clang(f0, d=1.2, decay=3.5):
    t = t_(d)
    out = np.zeros_like(t)
    for r, g in [(1, 1), (2.32, 0.6), (3.87, 0.45), (5.21, 0.3), (6.7, 0.2), (8.9, 0.12)]:
        out += g * np.sin(2 * np.pi * f0 * r * t + rng.random() * 6) * np.exp(-t * decay * (0.6 + r * 0.25))
    return out * np.minimum(t / 0.001, 1)


def make_all():
    os.makedirs(OUT, exist_ok=True)
    # Espada cortando el aire.
    for i, (f0, f1, d) in enumerate([(500, 2600, 0.24), (700, 3000, 0.2), (400, 2200, 0.28)]):
        save("swing_%d" % i, sweep_bp(noise(d), f0, f1, 0.5) * bump(d, 0.45), 0.7)
    save("swing_heavy", sweep_bp(noise(0.42), 250, 1500, 0.6) * bump(0.42, 0.5), 0.8)
    # Golpe a un esqueleto: impacto sordo + crujido de hueso.
    for i in range(3):
        d = 0.35
        thump = np.sin(2 * np.pi * np.cumsum(90 + 120 * np.exp(-t_(d) * 40)) / SR) * env(d, 0.001, 18)
        crack = hp(noise(d), 1800) * env(d, 0.0005, 45 + i * 10)
        clicks = np.zeros(int(d * SR))
        for _ in range(4 + i):
            p = rng.integers(0, int(0.06 * SR))
            clicks[p:p + 200] += hp(rng.standard_normal(200), 2500) * np.exp(-np.arange(200) / 40)
        save("hit_%d" % i, thump * 1.0 + crack * 0.6 + clicks * 0.5, 0.9)
    save("hit_heavy", verb(np.sin(2 * np.pi * np.cumsum(60 + 140 * np.exp(-t_(0.6) * 25)) / SR) * env(0.6, 0.001, 8)
                           + hp(noise(0.6), 1200) * env(0.6, 0.0005, 25) * 0.7, 0.15), 0.95)
    # Bloqueo con escudo: metal.
    save("block", verb(clang(420, 0.9) + hp(noise(0.9), 3000) * env(0.9, 0.0005, 40) * 0.5, 0.15), 0.85)
    # Pasos.
    for i in range(4):
        d = 0.14
        save("step_grass_%d" % i, bp(noise(d), 900 + i * 150, 5000) * env(d, 0.005, 35) + lp(noise(d), 300) * env(d, 0.002, 50) * 0.6, 0.5)
    for i in range(3):
        d = 0.12
        save("step_stone_%d" % i, lp(noise(d), 2500) * env(d, 0.001, 60) + tone(160 + i * 25, d, 50) * 0.5, 0.5)
    for i in range(2):
        d = 0.2
        save("hoof_%d" % i, verb(tone(300 + i * 60, d, 35) + bp(noise(d), 700, 3000) * env(d, 0.001, 50) * 0.5, 0.1, 0.6), 0.6)
    save("jump", sweep_bp(noise(0.22), 300, 900, 0.8) * bump(0.22, 0.3), 0.45)
    save("land", lp(noise(0.25), 400) * env(0.25, 0.002, 20) + tone(70, 0.25, 18), 0.6)
    save("dodge", sweep_bp(noise(0.3), 1500, 500, 0.7) * bump(0.3, 0.3), 0.6)
    # Magia.
    d = 0.7
    t = t_(d)
    shimmer = sum(np.sin(2 * np.pi * f * (1 + 0.6 * t / d) * t) for f in (880, 1320, 1760, 2640)) * bump(d, 0.3)
    save("cast", verb(mix(shimmer * 0.4, sweep_bp(noise(d), 400, 3000) * bump(d, 0.4)), 0.3), 0.6)
    save("fireball", sweep_bp(noise(0.6), 300, 1200, 1.0) * bump(0.6, 0.2) + lp(noise(0.6), 200) * bump(0.6, 0.2) * 0.5, 0.7)
    boom_d = 1.6
    boom = lp(noise(boom_d), 300) * env(boom_d, 0.003, 3.5) + np.sin(2 * np.pi * np.cumsum(45 + 60 * np.exp(-t_(boom_d) * 8)) / SR) * env(boom_d, 0.002, 4)
    crackle = hp(noise(boom_d), 2000) * env(boom_d, 0.001, 6) * (rng.random(int(boom_d * SR)) > 0.97)
    save("explosion", verb(boom + crackle * 2.0, 0.2, 1.8), 0.95)
    save("heal", verb(mix(bell("C6", 1.6, 0.8), at(bell("E6", 1.5, 0.8), 0.12), at(bell("G6", 1.4, 0.8), 0.24)), 0.3), 0.6)
    save("orb", sweep_bp(noise(0.5), 200, 600, 1.0) * bump(0.5, 0.3) + np.sin(2 * np.pi * 220 * t_(0.5) + 3 * np.sin(2 * np.pi * 7 * t_(0.5))) * bump(0.5, 0.3) * 0.3, 0.55)
    # Poder especial y Despertar.
    d = 1.4
    rise = sweep_bp(noise(d), 200, 4000, 0.5) * bump(d, 0.7)
    save("special", verb(mix(rise, at(boom[: int(0.5 * SR)], 0.9) * 0.8), 0.3, 2.0), 0.9)
    aw = mix(*[choir(n, 1.6, "a") for n in ["D4", "A4", "D5", "F#5"]], verb(boom, 0.3, 2.5) * 0.6)
    save("awaken", verb(aw, 0.25, 2.5), 0.95)
    # Recompensas.
    fan = np.zeros(int(2.2 * SR))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        s = brass(n, 0.18 if i < 3 else 0.9)
        p = int(i * 0.14 * SR)
        fan[p:p + len(s)] += s
        b = bell(n, 1.2, 1.0)
        fan[p:p + len(b)] += b * 0.5
    save("level_up", verb(fan, 0.25, 2.0), 0.85)
    q = np.zeros(int(1.6 * SR))
    for i, n in enumerate(["G4", "C5", "E5"]):
        s = brass(n, 0.12 if i < 2 else 0.6)
        p = int(i * 0.12 * SR)
        q[p:p + len(s)] += s
    save("quest", verb(q, 0.2, 1.5), 0.8)
    coin = np.zeros(int(0.7 * SR))
    for i, n in enumerate(["B5", "E6"]):
        b = bell(n, 0.6, 1.5)
        p = int(i * 0.07 * SR)
        coin[p:p + len(b)] += b
    save("coin", coin, 0.55)
    save("pickup", verb(mix(*[at(bell(n, 0.5, 0.6), i * 0.05) for i, n in enumerate(["E6", "G6", "B6"])]), 0.2), 0.5)
    gulp = np.concatenate([np.sin(2 * np.pi * (180 + 60 * np.sin(2 * np.pi * 9 * t_(0.12))) * t_(0.12)) * bump(0.12) for _ in range(3)])
    save("potion", np.concatenate([gulp, np.zeros(int(0.05 * SR))]) * 0.8, 0.6)
    # Interfaz.
    save("ui_click", tone(1400, 0.06, 60) + tone(2100, 0.06, 80) * 0.4, 0.35)
    save("ui_open", sweep_bp(noise(0.25), 1500, 4000, 0.8) * bump(0.25, 0.2) * 0.6 + tone(700, 0.25, 20) * 0.2, 0.4)
    save("ui_close", sweep_bp(noise(0.2), 3500, 1200, 0.8) * bump(0.2, 0.2) * 0.6, 0.35)
    save("blip", tone(900, 0.03, 120), 0.2)
    # Enemigos.
    d = 0.9
    rattle = np.zeros(int(d * SR))
    for _ in range(40):
        p = rng.integers(0, int(0.6 * SR))
        n = rng.integers(150, 400)
        rattle[p:p + n] += hp(rng.standard_normal(n), 1500 + rng.random() * 2000) * np.exp(-np.arange(n) / (n / 4)) * rng.uniform(0.3, 1.0)
    save("enemy_death", verb(rattle + lp(noise(d), 300) * env(d, 0.01, 8) * 0.5, 0.15), 0.75)
    d = 1.6
    t = t_(d)
    growl_f = 70 + 15 * np.sin(2 * np.pi * 5 * t)
    growl = np.sign(np.sin(2 * np.pi * np.cumsum(growl_f) / SR)) * 0.4 + bp(noise(d), 150, 900)
    save("roar", verb(lp(growl, 1200) * bump(d, 0.25), 0.3, 2.0), 0.9)
    save("hurt", lp(noise(0.3), 800) * env(0.3, 0.002, 18) + tone(110, 0.3, 14), 0.7)
    # Mundo.
    d = 1.1
    t = t_(d)
    creak_f = 180 + 60 * np.sin(2 * np.pi * 1.3 * t) + rng.standard_normal(len(t)).cumsum() * 0.02
    creak = bp(np.sign(np.sin(2 * np.pi * np.cumsum(creak_f) / SR)), 400, 2500) * bump(d, 0.3)
    save("door", creak * 0.6 + lp(noise(d), 200) * env(d, 0.6, 12) * 0.4, 0.55)
    d = 3.0
    save("gate", verb(lp(noise(d), 160) * bump(d, 0.3) + clang(90, d, 1.0) * 0.3, 0.2, 2.0), 0.8)
    d = 1.5
    t = t_(d)
    save("portal", verb(sum(np.sin(2 * np.pi * f * (1 + 0.3 * np.sin(2 * np.pi * 0.7 * t)) * t) for f in (330, 495, 660)) * bump(d, 0.4) * 0.3
                        + sweep_bp(noise(d), 300, 2500, 0.6) * bump(d, 0.5), 0.35, 2.0), 0.7)
    save("chapter", verb(clang(110, 4.0, 0.8) * 0.8 + bell("D4", 4.0, 1.2), 0.4, 3.0), 0.8)
    d = 2.5
    save("death", verb(mix(*[choir(n, 1.8, "o") for n in ["D3", "F3", "A3"]], lp(noise(d), 200) * 0.2), 0.3, 2.5), 0.8)
    print("sfx ok")


if __name__ == "__main__":
    make_all()
