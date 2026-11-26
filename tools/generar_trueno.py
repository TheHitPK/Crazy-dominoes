"""Genera el sonido del rayo de la entrada (audio/thunder/trueno.ogg) por síntesis.

    python tools/generar_trueno.py

Necesita numpy y ffmpeg en el PATH (para pasar de WAV a OGG).

Es un rayo eléctrico con aire de recreativa, en cuatro capas:
- zap: barrido de onda cuadrada que cae de agudo a grave, con poca resolución
  (bitcrush), como los láseres de las máquinas de los 80;
- zumbido eléctrico: sierra grave que tiembla, con chispazos sueltos;
- golpe: bombo electrónico grave y ruido "pixelado" que retumba;
- arpegio: cuatro notas cuadradas que suben justo cuando sale el nombre
  del estudio (0,55 s después de empezar, ver STRIKE y NAME_AT en intro.gd).
La semilla es fija: siempre sale el mismo sonido.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
DUR = 2.6
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "thunder", "trueno.ogg")
TAU = 2 * np.pi
## Cuándo suena el arpeggio, en segundos desde el principio del sonido.
NAME_AT = 0.55


def lowpass(x, cutoff):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    f *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def crush(x, bits=5, hold=4):
    """Menos resolución y menos muestras: el sonido "de 8 bits"."""
    steps = 2 ** bits
    x = np.round(x * steps) / steps
    return np.repeat(x[::hold], hold)[:len(x)]


def square(phase):
    return np.sign(np.sin(phase))


def main():
    rng = np.random.default_rng(23)
    n = int(RATE * DUR)
    t = np.arange(n) / RATE
    mix = np.zeros(n)

    # Zap: cuadrada de 2600 a 90 Hz en 0,4 s, con bitcrush.
    f = 90 + 2510 * np.exp(-t * 11)
    zap = square(TAU * np.cumsum(f) / RATE) * np.exp(-t * 5.5)
    mix += 0.38 * crush(zap, 4, 3)
    # Segundo zap más agudo y corto, un pelín después (el chasquido doble del rayo).
    t2 = np.clip(t - 0.06, 0, None)
    f2 = 300 + 3600 * np.exp(-t2 * 22)
    zap2 = square(TAU * np.cumsum(f2) / RATE) * np.exp(-t2 * 14) * (t > 0.06)
    mix += 0.22 * crush(zap2, 4, 2)

    # Zumbido eléctrico: sierra de 55 Hz con armónicos y un temblor rápido e irregular.
    buzz = np.zeros(n)
    for k in range(1, 18):
        buzz += np.sin(TAU * 55 * k * t) / k
    wobble = 0.5 + 0.5 * lowpass(rng.normal(0, 1, n), 30) / 0.3
    buzz *= np.clip(wobble, 0, 1.4) * np.exp(-t * 2.6) * np.minimum(t / 0.01, 1)
    mix += 0.16 * buzz

    # Chispazos: clics agudos sueltos, más seguidos al principio.
    sparks = np.zeros(n)
    for _ in range(70):
        at = rng.uniform(0, 1.0) ** 2.2
        i = int(at * RATE)
        m = min(120, n - i)
        sparks[i:i + m] += rng.uniform(0.3, 1.0) * square(TAU * rng.uniform(2500, 6000) * np.arange(m) / RATE) \
            * np.exp(-np.arange(m) / 25)
    mix += 0.22 * sparks

    # Golpe: bombo electrónico (seno que cae de 140 a 38 Hz) y retumbo "pixelado".
    fk = 38 + 102 * np.exp(-t * 14)
    kick = np.sin(TAU * np.cumsum(fk) / RATE) * np.exp(-t * 3.2)
    mix += 0.85 * kick
    rumble = lowpass(rng.normal(0, 1, n), 380) * np.exp(-t * 2.2)
    rumble /= np.abs(rumble).max()
    mix += 0.45 * crush(rumble, 5, 8)

    # Arpegio de recreativa al salir el nombre: Si bemol, Re, Fa, Si bemol agudo.
    for k, midi in enumerate((70, 74, 77, 82)):
        at = NAME_AT + k * 0.06
        i = int(at * RATE)
        m = int(0.22 * RATE) if k == 3 else int(0.07 * RATE)
        tn = np.arange(m) / RATE
        freq = 440 * 2 ** ((midi - 69) / 12)
        note = square(TAU * freq * tn) * 0.5 + 0.5 * square(TAU * freq * 1.005 * tn)
        note *= np.exp(-tn * (6 if k == 3 else 18))
        end = min(n, i + m)
        mix[i:end] += 0.13 * note[:end - i]

    mix *= np.minimum((DUR - t) / 0.4, 1)
    mix = np.tanh(mix * 1.3)
    mix *= 0.89 / np.abs(mix).max()

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "trueno.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((mix * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", OUT],
                       check=True)
    print("rayo generado en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
