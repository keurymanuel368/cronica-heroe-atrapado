"""Graba las voces de las escenas con Piper (texto a voz, sin conexión).

    godot --headless --path . --script res://tools/dump_lines.gd   # crea lineas.json
    python3 tools/audio/voces.py

Cada personaje usa una de las voces en español de Piper con su propio tono y
efectos (eco del salón del trono, voz fantasmal de Kaito...).
"""
import hashlib
import json
import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "../../assets/audio/voz")
PIPER = os.environ.get("PIPER", "/home/claude/tools/piper/piper/piper")
VOICES = os.environ.get("PIPER_VOICES", "/home/claude/tools/piper/v")

MALE = "es-carlfm-x-low"
# personaje: (voz, length_scale, filtros de ffmpeg)
CAST = {
    "Narrador": (MALE, 1.08, "rubberband=pitch=0.94:formant=preserved,aecho=0.8:0.5:70:0.12"),
    "Abuelo Ered": (MALE, 1.18, "rubberband=pitch=0.88:formant=preserved,vibrato=f=5.5:d=0.04"),
    "Rey Aurelio": (MALE, 1.1, "rubberband=pitch=0.82,aecho=0.8:0.7:90|170:0.22|0.14"),
    "Kaito": (MALE, 1.0, "rubberband=pitch=1.07:formant=preserved,chorus=0.6:0.9:50|60:0.3|0.25:0.25|0.4:2|2.3,aecho=0.8:0.8:220|400:0.28|0.16"),
    "Rey Esqueleto": (MALE, 1.15, "rubberband=pitch=0.66,lowpass=f=3200,aecho=0.8:0.8:120|260:0.35|0.2,volume=1.6,alimiter=limit=0.9"),
    # Las voces femeninas de Piper en español hacen pausas entre palabras:
    # se usa la masculina con el tono y el timbre subidos.
    "Hermana Elia": (MALE, 1.05, "rubberband=pitch=1.5,aecho=0.8:0.6:70|140:0.16|0.1"),
    "Sira": (MALE, 0.97, "rubberband=pitch=1.58"),
}


def file_id(voice, text):
    return hashlib.md5(f"{voice}|{text}".encode("utf-8")).hexdigest()[:12]


def main():
    os.makedirs(OUT, exist_ok=True)
    lines = json.load(open(os.path.join(HERE, "lineas.json"), encoding="utf-8"))
    keep = set()
    for voice, text in lines:
        model, length, filters = CAST[voice]
        name = file_id(voice, text) + ".ogg"
        keep.add(name)
        dest = os.path.join(OUT, name)
        if os.path.exists(dest):
            continue
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            raw = f.name
        onnx = os.path.join(VOICES, model, model + ".onnx")
        subprocess.run([PIPER, "-m", onnx, "--length_scale", str(length), "--noise_scale", "0.6",
                        "--sentence_silence", "0.25", "-f", raw], input=text.encode("utf-8"),
                       check=True, capture_output=True)
        af = f"highpass=f=70,{filters},apad=pad_dur=0.3,loudnorm=I=-17:TP=-1.5"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", af, "-ar", "24000", "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "4", dest], check=True)
        os.unlink(raw)
        print(voice, "·", text[:50])
    for f in os.listdir(OUT):
        if f.endswith(".ogg") and f not in keep:
            os.unlink(os.path.join(OUT, f))


if __name__ == "__main__":
    main()
