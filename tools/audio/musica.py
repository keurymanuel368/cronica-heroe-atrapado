"""Compone las pistas de música del juego (assets/audio/musica/*.ogg).

    python3 tools/audio/musica.py [nombre ...]
"""
import os
import sys
import numpy as np
from synth import *

OUT = os.path.join(os.path.dirname(__file__), "../../assets/audio/musica")


def play(tr, inst, spec, start, vol=1.0, pan=0.0, shift=0, wet=1.0, **kw):
    b = start
    for n, d in melody(spec):
        if n is not None:
            note = midi(n) + shift
            tr.add(inst(note, d * tr.spb * 0.95, **kw), b, vol, pan, wet)
        b += d
    return b


def pads(tr, inst, chords, start_bar, bpb, octave=3, vol=1.0, pan=0.0, **kw):
    for i, c in enumerate(chords):
        for j, n in enumerate(chord_notes(c, octave)):
            tr.add(inst(n, bpb * tr.spb * 0.98, **kw), (start_bar + i) * bpb, vol, pan + (j - 1) * 0.3)


def basses(tr, chords, start_bar, bpb, pattern=(0,), octave=2, vol=1.0, dur=None):
    for i, c in enumerate(chords):
        root = chord_notes(c, octave)[0]
        for p in pattern:
            tr.add(bass(root, (dur or bpb / len(pattern)) * tr.spb * 0.9), (start_bar + i) * bpb + p, vol)


def arps(tr, inst, chords, start_bar, bpb, step=0.5, octave=3, order=(0, 1, 2, 1), vol=1.0, pan=0.0, **kw):
    for i, c in enumerate(chords):
        notes = chord_notes(c, octave) + [chord_notes(c, octave + 1)[0]]
        k = 0
        b = 0.0
        while b < bpb - 1e-6:
            n = notes[order[k % len(order)]]
            tr.add(inst(n, step * tr.spb, **kw), (start_bar + i) * bpb + b, vol, pan)
            k += 1
            b += step


def drums(tr, start_bar, bars, bpb, pattern, vol=1.0):
    """pattern: lista de (pulso, sonido_fn, volumen, paneo)."""
    for bar in range(bars):
        for p, fn, v, pan in pattern:
            tr.add(fn(), (start_bar + bar) * bpb + p, vol * v, pan, wet=0.5)


# --- Pistas --------------------------------------------------------------------

def titulo():
    tr = Track(76, 24 * 4, reverb=0.4, room=3.2)
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"]
    for s in range(3):
        pads(tr, strings, prog, s * 8, 4, 3, 1.0)
        pads(tr, choir, prog, s * 8, 4, 4, 0.55 if s else 0.35)
        basses(tr, prog, s * 8, 4, (0,), 2, 0.8, dur=4)
    horn = ("D4:2 F4:1 A4:1 G4:1.5 F4:0.5 D4:2 C4:1 F4:1 A4:2 G4:3 r:1 "
            "D5:2 C5:1 A4:1 Bb4:1.5 A4:0.5 G4:2 G4:1 Bb4:1 D5:2 C#5:2 E5:2")
    play(tr, brass, horn, 32, 1.1, -0.1)
    play(tr, brass, horn, 64, 1.1, -0.1)
    play(tr, flute, horn, 64, 0.6, 0.3, shift=12)
    for bar in range(8, 24):
        tr.add(taiko(1.2), bar * 4, 0.9, -0.2, wet=0.6)
        tr.add(taiko(1.0), bar * 4 + 2.5, 0.6, 0.2, wet=0.6)
        tr.add(taiko(0.8), bar * 4 + 3, 0.5, 0.0, wet=0.6)
    for b in (0, 32, 64):
        tr.add(cymbal(3), b, 0.8)
    arps(tr, pluck, prog * 2, 8, 4, 0.5, 4, (0, 1, 2, 3, 2, 1), 0.35, 0.4)
    return tr


def aldea():
    tr = Track(126, 48 * 3, reverb=0.22, room=1.6)
    prog = ["G", "C", "D", "G", "Em", "C", "D", "G", "C", "G", "Am", "D", "G", "Em", "D", "G"]
    mel = ("B4:1 D5:1 G5:1 E5:2 D5:1 C5:1 B4:1 A4:1 B4:3 "
           "G4:1 B4:1 E5:1 E5:1 G5:1 E5:1 D5:1.5 C5:0.5 A4:1 G4:3 "
           "E5:1 G5:1 E5:1 D5:1 B4:1 G4:1 A4:1 C5:1 E5:1 D5:3 "
           "B4:1 D5:1 G5:1 G5:1 F#5:1 E5:1 D5:1 E5:0.5 D5:0.5 C5:1 B4:3")
    for s in range(3):
        arps(tr, pluck, prog, s * 16, 3, 0.5, 3, (0, 1, 2, 3, 2, 1), 0.7, -0.25, bright=0.55, decay=1.0)
        basses(tr, prog, s * 16, 3, (0,), 2, 0.6, dur=2.5)
        drums(tr, s * 16, 16, 3, [(0, frame_drum, 0.7, 0.1), (1.5, shaker, 0.6, 0.4), (2, frame_drum, 0.35, 0.1), (2.5, shaker, 0.5, 0.4)])
    play(tr, flute, mel, 0, 0.9, 0.2)
    play(tr, bell, mel, 48, 0.45, 0.3)
    play(tr, pluck, mel, 48, 0.4, -0.3, shift=12, bright=0.7, decay=0.8)
    pads(tr, strings, prog, 16, 3, 3, 0.5)
    play(tr, flute, mel, 96, 0.9, 0.2)
    play(tr, flute, mel, 96, 0.35, -0.2, shift=-5)
    return tr


def pradera():
    tr = Track(84, 32 * 4, reverb=0.35, room=2.8)
    prog = ["D", "A", "Bm", "G", "D", "A", "G", "A"]
    m1 = ("F#4:2 A4:1 D5:1 E5:3 C#5:1 D5:2 B4:1 F#4:1 G4:3 r:1 "
          "A4:1 D5:1 F#5:2 E5:1.5 D5:0.5 C#5:2 B4:1 D5:1 G5:1 F#5:1 E5:4")
    m2 = ("F#5:2 E5:1 D5:1 C#5:3 A4:1 B4:2 D5:1 B4:1 G4:3 r:1 "
          "A4:1 B4:1 D5:2 E5:1.5 F#5:0.5 E5:2 D5:1 B4:1 G4:1 E5:1 D5:4")
    for s in range(4):
        arps(tr, pluck, prog, s * 8, 4, 0.5, 3, (0, 1, 2, 3, 2, 1, 2, 1), 0.55, -0.3, bright=0.5, decay=2.2)
        pads(tr, strings, prog, s * 8, 4, 3, 0.6 if s else 0.4, bright=1800)
        basses(tr, prog, s * 8, 4, (0, 2.5), 2, 0.45)
    play(tr, flute, m1, 32, 0.85, 0.25)
    play(tr, flute, m2, 64, 0.85, 0.25)
    play(tr, strings, m1, 96, 0.9, 0.0, shift=-12, bright=2400, attack=0.15)
    for bar in range(8, 32):
        tr.add(frame_drum(), bar * 4, 0.35, 0.2, wet=0.5)
        tr.add(shaker(), bar * 4 + 2, 0.4, 0.5)
    return tr


def combate():
    tr = Track(140, 32 * 4, reverb=0.2, room=1.8)
    prog = ["Em", "C", "D", "B", "Em", "C", "Am", "B"]
    mel = ("E5:1 B4:0.5 E5:0.5 G5:1 F#5:1 E5:2 D5:1 C5:1 D5:1 A4:0.5 D5:0.5 F#5:1 E5:1 D#5:3 B4:1 "
           "E5:1 G5:1 B5:1 A5:0.5 G5:0.5 G5:2 E5:2 A5:1 G5:1 F#5:1 E5:1 D#5:4")
    for s in range(4):
        for i, c in enumerate(prog):
            root = chord_notes(c, 3)
            for k in range(8):
                n = root[0] if k % 4 != 3 else root[2]
                tr.add(stacc(n + (12 if k == 6 else 0)), (s * 8 + i) * 4 + k * 0.5, 0.9, -0.3 + 0.6 * (k % 2), wet=0.4)
        basses(tr, prog, s * 8, 4, (0, 1.5, 2, 3.5), 1, 0.7)
        drums(tr, s * 8, 8, 4, [(0, lambda: taiko(1.1), 1.0, 0), (1.5, taiko, 0.5, -0.3), (2, snare, 0.7, 0.1),
                                (2.5, lambda: taiko(1.1), 0.7, 0.3), (3, taiko, 0.6, -0.2), (3.5, snare, 0.4, 0.1)])
        if s >= 1:
            pads(tr, choir, prog, s * 8, 4, 4, 0.45)
    play(tr, brass, mel, 32, 1.0, 0.0)
    play(tr, brass, mel, 96, 1.0, 0.0)
    play(tr, brass, mel, 96, 0.6, 0.2, shift=-12)
    for b in (0, 32, 64, 96):
        tr.add(cymbal(), b, 0.9)
    return tr


def jefe():
    tr = Track(150, 32 * 4, reverb=0.25, room=2.6)
    prog = ["Cm", "Ab", "Bb", "G", "Cm", "Ab", "Fm", "G"]
    mel = ("C5:2 Eb5:1 G5:1 Ab5:2 G5:1 Eb5:1 F5:1 D5:1 Bb4:1 D5:1 B4:3 G4:1 "
           "C5:1 D5:1 Eb5:1 G5:1 C6:2 Ab5:2 Ab5:1 G5:1 F5:1 Eb5:1 D5:2 B4:2")
    for s in range(4):
        for i, c in enumerate(prog):
            notes = chord_notes(c, 3)
            for k in range(8):
                n = [notes[0], notes[0], notes[1], notes[0], notes[2], notes[0], notes[1], notes[2]][k]
                tr.add(stacc(n, 0.14), (s * 8 + i) * 4 + k * 0.5, 0.9, -0.4 + 0.8 * (k % 2), wet=0.4)
        pads(tr, choir, prog, s * 8, 4, 4, 0.7, vowel="o")
        pads(tr, strings, prog, s * 8, 4, 2, 0.6, bright=1200)
        basses(tr, prog, s * 8, 4, (0, 0.5, 2, 2.5), 1, 0.8)
        drums(tr, s * 8, 8, 4, [(0, lambda: taiko(1.3), 1.0, 0), (0.75, taiko, 0.5, -0.3), (1, lambda: taiko(1.3), 0.8, 0.2),
                                (2, snare, 0.8, 0), (2.5, taiko, 0.6, -0.2), (3, lambda: taiko(1.3), 0.8, 0.3), (3.5, snare, 0.5, 0)])
    play(tr, brass, mel, 32, 1.1, 0.0)
    play(tr, brass, mel, 32, 0.7, 0.0, shift=-12)
    play(tr, brass, mel, 96, 1.1, 0.0)
    play(tr, bell, mel, 96, 0.4, 0.4, shift=12)
    for b in range(0, 128, 16):
        tr.add(cymbal(), b, 0.8)
    return tr


def mazmorra():
    tr = Track(60, 24 * 4, reverb=0.5, room=4.0)
    tr.add(wind(24 * 4 + 1), 0, 0.9, 0.0, wet=0.3)
    prog = ["Am", "Am", "F", "E", "Am", "Dm", "F", "E"]
    for s in range(3):
        pads(tr, strings, prog, s * 8, 4, 2, 0.7, bright=700, attack=1.5)
        if s:
            pads(tr, choir, prog, s * 8, 4, 3, 0.25, vowel="o")
    rng = np.random.default_rng(11)
    pent = ["A4", "C5", "D5", "E5", "G5", "A5", "E4"]
    for b in range(2, 96, 3):
        if rng.random() < 0.6:
            tr.add(bell(pent[rng.integers(len(pent))], 3.5, 1.5), b + rng.choice([0, 0.5, 1.5]), 0.5, rng.uniform(-0.7, 0.7))
    for b in range(0, 96, 8):
        tr.add(taiko(1.6), b, 0.45, 0.0)
    return tr


def noche():
    tr = Track(66, 24 * 4, reverb=0.45, room=3.4)
    prog = ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C"]
    mel = ("A4:2 C5:1 F5:1 E5:3 C5:1 D5:2 A4:2 Bb4:4 "
           "A4:1 Bb4:1 C5:2 G5:2 E5:2 D5:1 C5:1 Bb4:2 C5:4")
    for s in range(3):
        arps(tr, pluck, prog, s * 8, 4, 1.0, 3, (0, 1, 2, 3), 0.5, -0.2, bright=0.4, decay=3.0)
        pads(tr, strings, prog, s * 8, 4, 3, 0.45, bright=1400, attack=1.0)
        basses(tr, prog, s * 8, 4, (0,), 2, 0.35, dur=4)
    play(tr, bell, mel, 32, 0.55, 0.3)
    play(tr, flute, mel, 64, 0.6, 0.2)
    return tr


def final():
    tr = Track(160, 32 * 4, reverb=0.3, room=3.0)
    prog = ["Dm", "Bb", "C", "A", "Dm", "Gm", "Bb", "A"]
    mel = ("D5:1 F5:1 A5:2 Bb5:1 A5:1 G5:1 F5:1 E5:1 G5:1 C6:2 C#6:3 A5:1 "
           "D6:2 C6:1 A5:1 Bb5:2 G5:1 D5:1 F5:1 G5:1 A5:1 Bb5:1 A5:4")
    for s in range(4):
        for i, c in enumerate(prog):
            notes = chord_notes(c, 3)
            for k in range(8):
                n = notes[[0, 0, 1, 0, 2, 0, 1, 2][k]]
                tr.add(stacc(n, 0.13), (s * 8 + i) * 4 + k * 0.5, 0.9, -0.4 + 0.8 * (k % 2), wet=0.4)
        pads(tr, choir, prog, s * 8, 4, 4, 0.9, vowel="a")
        pads(tr, choir, prog, s * 8, 4, 3, 0.5, vowel="o")
        basses(tr, prog, s * 8, 4, (0, 0.5, 1.5, 2, 2.5, 3.5), 1, 0.8)
        drums(tr, s * 8, 8, 4, [(0, lambda: taiko(1.3), 1.0, 0), (0.5, taiko, 0.5, -0.3), (1, snare, 0.7, 0),
                                (1.5, taiko, 0.5, 0.3), (2, lambda: taiko(1.3), 0.9, 0), (2.5, taiko, 0.5, -0.3),
                                (3, snare, 0.8, 0), (3.5, snare, 0.4, 0.2)])
    play(tr, brass, mel, 32, 1.1)
    play(tr, brass, mel, 32, 0.6, shift=-12)
    play(tr, brass, mel, 96, 1.1)
    play(tr, strings, mel, 96, 0.9, 0.3, shift=12, bright=3500, attack=0.05)
    for b in range(0, 128, 16):
        tr.add(cymbal(), b, 0.9)
    return tr


def fin():
    tr = Track(72, 24 * 4, reverb=0.4, room=3.0)
    prog = ["C", "G", "Am", "F", "C", "G", "F", "C"]
    mel = ("E5:2 D5:1 C5:1 D5:3 G4:1 C5:2 B4:1 A4:1 A4:3 r:1 "
           "E5:1 F5:1 G5:2 D5:1 G5:2 F5:1 E5:1.5 D5:0.5 C5:2 C5:4")
    for s in range(3):
        arps(tr, piano, prog, s * 8, 4, 0.5, 3, (0, 1, 2, 3, 2, 1, 2, 1), 0.55, -0.2)
        pads(tr, strings, prog, s * 8, 4, 3, 0.3 + 0.25 * s, bright=2000, attack=0.8)
        basses(tr, prog, s * 8, 4, (0,), 2, 0.4, dur=4)
    play(tr, piano, mel, 0, 0.7, 0.1, shift=12)
    play(tr, flute, mel, 32, 0.8, 0.2)
    play(tr, strings, mel, 64, 1.0, 0.0, bright=3000, attack=0.2)
    play(tr, flute, mel, 64, 0.4, 0.3, shift=12)
    return tr


TRACKS = {f.__name__: f for f in [titulo, aldea, pradera, combate, jefe, mazmorra, noche, final, fin]}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or TRACKS:
        tr = TRACKS[name]()
        write(os.path.join(OUT, name + ".ogg"), tr.render())
        print(name, "ok", round(tr.length / SR, 1), "s")
