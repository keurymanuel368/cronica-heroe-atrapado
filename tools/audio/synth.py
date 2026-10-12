"""Sintetizador sencillo para la música y los efectos del juego.

Todo se genera con numpy/scipy: instrumentos aditivos (laúd, arpa, flauta,
cuerdas, coro, metales, campanas), percusión (taiko, caja, pandero, platillo)
y una reverb por convolución. Sin muestras externas: todo es original.
"""
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
RNG = np.random.default_rng(7)


def hz(note):
    """'A4' -> 440.0. Admite sostenidos (#) y bemoles (b)."""
    if isinstance(note, (int, float)):
        return 440.0 * 2 ** ((note - 69) / 12)
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]]
    i = 1
    while i < len(note) and note[i] in "#b":
        n += 1 if note[i] == "#" else -1
        i += 1
    octave = int(note[i:])
    return 440.0 * 2 ** ((n + 12 * (octave + 1) - 69) / 12)


def midi(note):
    return int(round(69 + 12 * np.log2(hz(note) / 440.0)))


def _t(dur):
    return np.arange(int(dur * SR)) / SR


def lp(x, cutoff, order=2):
    cutoff = min(cutoff, SR * 0.45)
    return sosfilt(butter(order, cutoff, "low", fs=SR, output="sos"), x)


def hp(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos"), x)


def adsr(n, a, d, s, r, hold=None):
    """Envolvente de n muestras; hold = segundos hasta soltar la nota."""
    t = np.arange(n) / SR
    hold = n / SR - r if hold is None else hold
    env = np.where(t < a, t / max(a, 1e-4), 1.0)
    dec = (t >= a) & (t < a + d)
    env = np.where(dec, 1.0 - (1.0 - s) * (t - a) / max(d, 1e-4), env)
    env = np.where(t >= a + d, s, env)
    rel = t >= hold
    level = np.interp(hold, t, env) if n else 0
    env = np.where(rel, level * np.exp(-(t - hold) / max(r / 4, 1e-4)), env)
    return env


def _additive(f, t, amps, phase_mod=0.0, detune=0.0):
    out = np.zeros_like(t)
    for k, a in enumerate(amps, start=1):
        if a == 0 or f * k > SR * 0.45:
            continue
        out += a * np.sin(2 * np.pi * f * k * (1 + detune) * t + phase_mod * k + RNG.random() * 6.28)
    return out


# --- Instrumentos melódicos ----------------------------------------------------

def pluck(note, dur, bright=0.6, decay=1.6):
    """Laúd / arpa: armónicos que se apagan antes cuanto más agudos."""
    f = hz(note)
    t = _t(dur + decay)
    out = np.zeros_like(t)
    for k in range(1, 16):
        if f * k > SR * 0.45:
            break
        a = (bright ** (k - 1)) / k ** 0.6
        out += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (1.0 / decay) * (1 + 0.5 * k))
    out *= np.minimum(t / 0.003, 1.0)
    return out * 0.5


def piano(note, dur):
    f = hz(note)
    t = _t(dur + 2.0)
    out = np.zeros_like(t)
    for k in range(1, 12):
        if f * k > SR * 0.45:
            break
        inh = 1 + 0.0004 * k * k
        out += (0.8 ** k) * np.sin(2 * np.pi * f * k * inh * t) * np.exp(-t * (0.6 + 0.35 * k))
    out *= np.minimum(t / 0.004, 1.0)
    rel = np.where(t > dur, np.exp(-(t - dur) * 6), 1.0)
    return out * rel * 0.5


def flute(note, dur, breath=0.04):
    f = hz(note)
    t = _t(dur + 0.25)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    phase = 2 * np.pi * f * np.cumsum(vib) / SR
    out = np.sin(phase) + 0.32 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase) + 0.05 * np.sin(4 * phase)
    noise = bp(RNG.standard_normal(len(t)), f * 0.8, f * 3.0) * breath * 6
    out = (out + noise) * adsr(len(t), 0.07, 0.1, 0.85, 0.22, hold=dur)
    return out * 0.35


def strings(note, dur, bright=2600, attack=0.35):
    f = hz(note)
    t = _t(dur + 0.9)
    amps = [1 / k for k in range(1, 28)]
    out = np.zeros_like(t)
    for d in (-0.004, -0.0015, 0.0015, 0.004):
        vib = 1 + 0.003 * np.sin(2 * np.pi * (4.8 + d * 100) * t)
        ph = 2 * np.pi * f * (1 + d) * np.cumsum(vib) / SR
        for k, a in enumerate(amps, start=1):
            if f * k > SR * 0.4:
                break
            out += a * np.sin(k * ph + RNG.random() * 6.28)
    out = lp(out, bright)
    return out * adsr(len(t), attack, 0.3, 0.9, 0.8, hold=dur) * 0.09


def stacc(note, dur=0.18):
    """Cuerdas cortas (ostinato de batalla)."""
    f = hz(note)
    t = _t(dur + 0.15)
    out = np.zeros_like(t)
    for d in (-0.003, 0.003):
        out += _additive(f, t, [1 / k for k in range(1, 20)], detune=d)
    out = lp(out, 3200)
    return out * adsr(len(t), 0.008, 0.08, 0.5, 0.12, hold=dur) * 0.16


def choir(note, dur, vowel="a"):
    f = hz(note)
    t = _t(dur + 1.0)
    src = np.zeros_like(t)
    for d in (-0.005, 0.0, 0.005):
        vib = 1 + 0.005 * np.sin(2 * np.pi * (5.0 + d * 60) * t + RNG.random() * 6)
        ph = 2 * np.pi * f * (1 + d) * np.cumsum(vib) / SR
        for k in range(1, 40):
            if f * k > SR * 0.4:
                break
            src += np.sin(k * ph + RNG.random() * 6.28) / k
    forms = {"a": [(700, 1.0), (1220, 0.5), (2600, 0.25)], "o": [(450, 1.0), (800, 0.5), (2830, 0.15)]}[vowel]
    out = np.zeros_like(t)
    for fc, g in forms:
        out += g * bp(src, fc * 0.85, fc * 1.15)
    return out * adsr(len(t), 0.5, 0.3, 0.9, 1.0, hold=dur) * 0.22


def brass(note, dur):
    f = hz(note)
    t = _t(dur + 0.3)
    bright = 1 + 7 * adsr(len(t), 0.06, 0.25, 0.45, 0.2, hold=dur)
    out = np.zeros_like(t)
    for d in (-0.002, 0.002):
        for k in range(1, 26):
            if f * k > SR * 0.4:
                break
            out += np.exp(-k / bright) / k ** 0.3 * np.sin(2 * np.pi * f * k * (1 + d) * t + RNG.random() * 6.28)
    out = lp(out, 4500)
    return out * adsr(len(t), 0.05, 0.2, 0.8, 0.25, hold=dur) * 0.12


def bass(note, dur):
    f = hz(note)
    t = _t(dur + 0.3)
    out = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    return out * adsr(len(t), 0.01, 0.3, 0.6, 0.25, hold=dur) * 0.45


def bell(note, dur=2.5, index=2.5):
    f = hz(note)
    t = _t(dur)
    env = np.exp(-t * 1.8)
    out = np.sin(2 * np.pi * f * t + index * env * np.sin(2 * np.pi * f * 3.5 * t))
    out += 0.3 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 3)
    return out * env * np.minimum(t / 0.002, 1) * 0.25


# --- Percusión -----------------------------------------------------------------

def taiko(size=1.0):
    t = _t(1.4)
    f = (55 + 70 * np.exp(-t * 25)) / size
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4.5)
    hit = lp(RNG.standard_normal(len(t)), 900) * np.exp(-t * 30) * 0.6
    return (body + hit) * 0.9


def kick():
    t = _t(0.5)
    f = 48 + 90 * np.exp(-t * 35)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.9


def snare(tight=1.0):
    t = _t(0.35)
    n = bp(RNG.standard_normal(len(t)), 1200, 7000) * np.exp(-t * 18 * tight)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 25)
    return (n * 0.6 + tone * 0.4) * 0.6


def frame_drum():
    t = _t(0.5)
    body = np.sin(2 * np.pi * (110 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 10)
    jingle = lp(hp(RNG.standard_normal(len(t)), 6000), 11000) * np.exp(-t * 14) * 0.1
    return (body * 0.6 + jingle) * 0.5


def shaker():
    t = _t(0.12)
    return lp(hp(RNG.standard_normal(len(t)), 5000), 10000) * np.sin(np.pi * t / 0.12) * 0.07


def cymbal(dur=2.5):
    t = _t(dur)
    return lp(hp(RNG.standard_normal(len(t)), 5500), 12000) * np.exp(-t * 2.2) * np.minimum(t / 0.004, 1) * 0.13


def wind(dur):
    t = _t(dur)
    n = RNG.standard_normal(len(t))
    out = np.zeros_like(t)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t)
    out = lp(n, 500) * (0.4 + 0.6 * lfo) + bp(n, 600, 1400) * 0.3 * lfo
    return out * 0.25


# --- Mezcla --------------------------------------------------------------------

def reverb_ir(seconds=2.4, damp=3500, seed=3):
    rng = np.random.default_rng(seed)
    t = _t(seconds)
    irs = []
    for _ in range(2):
        n = rng.standard_normal(len(t)) * np.exp(-t * 6.9 / seconds)
        n = lp(n, damp)
        n[: int(0.012 * SR)] = 0
        irs.append(n / np.sqrt(np.sum(n ** 2)))
    return irs


class Track:
    """Pista: se colocan notas en pulsos y se renderiza en estéreo con reverb."""

    def __init__(self, bpm, beats, reverb=0.28, room=2.4):
        self.spb = 60.0 / bpm
        self.beats = beats
        self.length = int(beats * self.spb * SR)
        self.tail = int(4.0 * SR)
        self.dry = np.zeros((2, self.length + self.tail))
        self.send = np.zeros((2, self.length + self.tail))
        self.reverb = reverb
        self.room = room

    def add(self, sound, beat, vol=1.0, pan=0.0, wet=1.0, human=0.008):
        start = int((beat * self.spb + RNG.uniform(-human, human) * (beat > 0)) * SR)
        start = max(start, 0)
        end = min(start + len(sound), self.dry.shape[1])
        s = sound[: end - start] * vol
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.dry[0, start:end] += s * l
        self.dry[1, start:end] += s * r
        self.send[0, start:end] += s * l * wet
        self.send[1, start:end] += s * r * wet

    def render(self, gain=1.0):
        irs = reverb_ir(self.room)
        wet = np.stack([fftconvolve(self.send[i], irs[i])[: self.dry.shape[1]] for i in range(2)])
        mix = self.dry + wet * self.reverb * 3.0
        # Cola al principio: el bucle suena continuo.
        body = mix[:, : self.length].copy()
        tail = mix[:, self.length:]
        body[:, : tail.shape[1]] += tail
        body *= gain
        peak = np.max(np.abs(body)) + 1e-9
        body = body / peak * 0.95
        return np.tanh(body * 1.3) / np.tanh(1.3)


def melody(spec):
    """'D5:1 F5:0.5 r:0.5' -> [(nota|None, pulsos)]"""
    out = []
    for tok in spec.split():
        n, d = tok.split(":")
        out.append((None if n == "r" else n, float(d)))
    return out


def chord_notes(name, octave=3):
    """'Dm' -> ['D3','F3','A3']; 'Bb', 'F#m', 'G7', 'Csus'."""
    root = name[0]
    i = 1
    if len(name) > 1 and name[1] in "#b":
        root += name[1]
        i = 2
    q = name[i:]
    base = midi(root + str(octave))
    ints = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10],
            "maj7": [0, 4, 7, 11], "sus": [0, 5, 7], "dim": [0, 3, 6]}[q]
    return [base + x for x in ints]


def write(path, stereo):
    import subprocess, tempfile, wave
    data = (np.clip(stereo, -1, 1) * 32767).astype(np.int16).T.copy()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
