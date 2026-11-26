"""Genera la música del juego por síntesis (numpy + ffmpeg en el PATH).

    python tools/generar_musica.py

- audio/menu/menu_lounge.ogg: menú. Bossa lounge tranquila a 116 pulsos, piano
  eléctrico, vibráfono, contrabajo y percusión suave. 64 s.
- audio/event/jazz_activo.ogg: torneo y ranked. Jazz swing rápido a 176
  pulsos sobre un blues en Si bemol: bajo caminando, ride, piano y saxo. 65 s.

Las dos pistas son bucles exactos (la reverberación de la cola cae al
principio), así que se repiten sin corte. Las melodías salen de un generador
con semilla fija: siempre se genera la misma canción. Son nuestras: no tienen
derechos de nadie.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..")
TAU = 2 * np.pi


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tt(dur):
    return np.arange(int(dur * RATE)) / RATE


def release(t, dur, speed):
    return np.where(t < dur, 1.0, np.exp(-(t - dur) * speed))


def lowpass(x, cutoff):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    f *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


# ----------------------------------------------------------------- instrumentos

def epiano(f, dur, vel=1.0):
    t = tt(dur + 0.5)
    index = 2.0 * np.exp(-t * 7) + 0.25
    sig = np.sin(TAU * f * t + index * np.sin(TAU * f * t))
    sig += 0.12 * np.sin(TAU * f * 7.0 * t) * np.exp(-t * 14)
    env = np.minimum(t / 0.004, 1) * np.exp(-t * 1.3) * release(t, dur, 12)
    return sig * env * vel * 0.22


def vibes(f, dur, vel=1.0):
    t = tt(dur + 1.2)
    sig = np.sin(TAU * f * t) + 0.22 * np.sin(TAU * f * 4.0 * t) * np.exp(-t * 5)
    trem = 1 - 0.22 * (0.5 + 0.5 * np.sin(TAU * 5.5 * t))
    env = np.minimum(t / 0.002, 1) * np.exp(-t * 2.0) * release(t, dur + 0.3, 6)
    return sig * env * trem * vel * 0.26


def bass(f, dur, vel=1.0):
    t = tt(dur + 0.15)
    sig = np.sin(TAU * f * t) + 0.45 * np.sin(TAU * 2 * f * t) + 0.18 * np.sin(TAU * 3 * f * t)
    sig += 0.5 * np.sin(TAU * f * t) * np.exp(-t * 40)
    env = np.minimum(t / 0.005, 1) * np.exp(-t * 2.2) * release(t, dur, 30)
    return np.tanh(sig * 0.9) * env * vel * 0.42


def sax(f, dur, vel=1.0, rng=None):
    t = tt(dur + 0.12)
    vib = 1 + 0.006 * np.sin(TAU * 5.2 * t) * np.clip((t - 0.12) / 0.1, 0, 1)
    phase = TAU * np.cumsum(f * vib) / RATE
    sig = np.zeros_like(t)
    for k in range(1, 15):
        amp = k ** -1.25 * (1.0 if k % 2 else 0.75)
        if f * k > 9000:
            break
        sig += amp * np.sin(k * phase)
    if rng is not None:
        sig += 0.04 * lowpass(rng.normal(0, 1, len(t)), 3000)
    env = np.minimum(t / 0.03, 1) * (0.85 + 0.15 * np.exp(-t * 6)) * np.exp(-t * 0.5) * release(t, dur, 22)
    return np.tanh(sig * 0.8) * env * vel * 0.2


def make_drums(rng):
    d = {}
    t = tt(1.2)
    ride = np.zeros_like(t)
    for p in (3150, 4210, 5320, 6890, 8120, 9440):
        ride += np.sin(TAU * p * t + rng.uniform(0, TAU))
    ride = ride / 6 * np.exp(-t * 4.5) + 0.35 * highpass(rng.normal(0, 1, len(t)), 6000) * np.exp(-t * 6)
    ride += 0.6 * highpass(rng.normal(0, 1, len(t)), 3000) * np.exp(-t * 80)
    d["ride"] = ride * 0.16
    t = tt(0.25)
    d["hat"] = highpass(rng.normal(0, 1, len(t)), 7000) * np.exp(-t * 45) * 0.14
    d["foot"] = highpass(rng.normal(0, 1, len(t)), 5000) * np.exp(-t * 28) * 0.1
    d["shaker"] = highpass(rng.normal(0, 1, len(t)), 5500) * np.minimum(t / 0.01, 1) * np.exp(-t * 30) * 0.08
    t = tt(0.4)
    noise = rng.normal(0, 1, len(t))
    d["brush"] = (lowpass(noise, 5000) - lowpass(noise, 900)) * np.minimum(t / 0.012, 1) * np.exp(-t * 13) * 0.12
    d["ghost"] = ((lowpass(noise, 6000) - lowpass(noise, 1200)) * np.exp(-t * 30)
                  + 0.6 * np.sin(TAU * 190 * t) * np.exp(-t * 28)) * 0.08
    f = 45 + 70 * np.exp(-t * 25)
    d["kick"] = np.sin(TAU * np.cumsum(f) / RATE) * np.exp(-t * 9) * 0.5
    t = tt(0.12)
    d["rim"] = (np.sin(TAU * 1700 * t) * np.exp(-t * 90) + 0.6 * np.sin(TAU * 520 * t) * np.exp(-t * 60)
                + 0.3 * rng.normal(0, 1, len(t)) * np.exp(-t * 150)) * 0.12
    return d


# ----------------------------------------------------------------- mezcla

class Track:
    """Pista en bucle: lo que se sale por el final entra por el principio."""

    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * RATE))

    def add(self, at, sig, gain=1.0):
        n = len(self.buf)
        i = int(at * RATE) % n
        end = i + len(sig)
        if end <= n:
            self.buf[i:end] += sig * gain
        else:
            k = n - i
            self.buf[i:] += sig[:k] * gain
            rest = sig[k:]
            while len(rest) > 0:
                m = min(len(rest), n)
                self.buf[:m] += rest[:m] * gain
                rest = rest[m:]

    def finish(self, rng, wet=0.18):
        # Reverberación por convolución circular: la cola también da la vuelta.
        n = len(self.buf)
        t = tt(1.6)
        ir = rng.normal(0, 1, len(t)) * np.exp(-t * 3.2)
        ir = lowpass(ir, 4500)
        ir /= np.sqrt(np.sum(ir ** 2))
        pad = np.zeros(n)
        pad[:len(ir)] = ir
        wet_sig = np.fft.irfft(np.fft.rfft(self.buf) * np.fft.rfft(pad), n)
        mix = self.buf + wet * wet_sig
        mix = np.tanh(mix * 1.2)
        # Pico a -3,7 dB: suena igual de fuerte que jazz_de_la_casa.ogg.
        return mix * 0.65 / np.abs(mix).max()


def save_ogg(samples, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "pista.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((samples * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4", path],
                       check=True)
    print("generada", os.path.abspath(path))


# ----------------------------------------------------------------- armonía

QUALITIES = {
    "maj7": [4, 7, 11, 14], "m7": [3, 7, 10, 14], "7": [4, 10, 14, 19], "m6": [3, 7, 9, 14],
    "7b9": [4, 10, 13, 19], "9": [4, 10, 14, 16],
}
PC = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def parse(chord):
    for q in sorted(QUALITIES, key=len, reverse=True):
        if chord.endswith(q):
            return PC[chord[:-len(q)]], q
    raise ValueError(chord)


def voicing(chord, low=55):
    root, q = parse(chord)
    notes = [root + i for i in QUALITIES[q][:4]]
    base = notes[0]
    shift = 12 * int(np.ceil((low - base) / 12))
    return [n + shift for n in notes]


def chord_tones(chord):
    root, q = parse(chord)
    return {(root + i) % 12 for i in [0] + QUALITIES[q][:3]}


def bass_root(chord, low=36):
    root, _ = parse(chord)
    return low + (root - low) % 12


# ----------------------------------------------------------------- menú

def menu_song():
    rng = np.random.default_rng(116)
    bpm = 116
    beat = 60 / bpm
    bar = beat * 4
    prog = ["Fmaj7", "Dm7", "Gm7", "C7", "Am7", "D7b9", "Gm7", "C7",
            "Bbmaj7", "Bbm6", "Am7", "D7b9", "Gm7", "C9", "Fmaj7", "Fmaj7"]
    bars = len(prog) * 2
    tr = Track(bars * bar)
    dr = make_drums(rng)
    scale = [0, 2, 4, 5, 7, 9, 11]  # Fa mayor, relativo a Fa
    comp_a = [0, 3, 6]
    comp_b = [2, 4, 7]
    last = 72
    rhythms = [[(0, 3), (3, 2), (6, 2), (8, 6)], [(2, 2), (4, 2), (6, 1), (7, 3), (12, 4)],
               [(0, 2), (2, 2), (4, 4), (10, 2), (12, 4)], [(1, 2), (3, 3), (8, 2), (10, 6)]]
    phrase_rhythm = None
    for b in range(bars):
        chord = prog[b % len(prog)]
        t0 = b * bar
        # Bajo de bossa: fundamental y quinta, con la anticipación de la bossa.
        root = bass_root(chord)
        for at, iv in ((0, 0), (1.5, 7), (2, 0), (3.5, 7)):
            tr.add(t0 + at * beat, bass(hz(root + iv), beat * 1.2, 0.95 if at in (0, 2) else 0.75))
        # Piano eléctrico: acordes con el ritmo de la bossa (dos compases distintos).
        for e in (comp_a if b % 2 == 0 else comp_b):
            dur = beat * (1.3 if e in (0, 7) else 0.8)
            for n in voicing(chord):
                tr.add(t0 + e * beat / 2, epiano(hz(n), dur, 0.55 + rng.uniform(-0.05, 0.05)))
        # Percusión: shaker a corcheas, aro con clave de bossa, bombo suave.
        for e in range(8):
            tr.add(t0 + e * beat / 2, dr["shaker"], 1.0 if e % 2 else 0.6)
        for e in ([0, 3, 6] if b % 2 == 0 else [2, 4]):
            tr.add(t0 + e * beat / 2, dr["rim"], 0.9)
        for at in (0, 1.5, 2, 3.5):
            tr.add(t0 + at * beat, dr["kick"], 0.35)
        # Vibráfono: frases de dos compases; en la segunda vuelta, más espaciadas.
        if b % 2 == 0:
            phrase_rhythm = rhythms[(b // 2) % len(rhythms)]
            if b >= len(prog) and rng.random() < 0.3:
                phrase_rhythm = phrase_rhythm[::2]
        for e, length in phrase_rhythm:
            e_abs = e - (b % 2) * 8
            if not 0 <= e_abs < 8:
                continue
            tones = chord_tones(chord)
            strong = e_abs in (0, 4)
            cands = []
            for m in range(65, 86):
                pc = (m - 5) % 12
                if (m % 12) in tones or (not strong and pc in scale):
                    cands.append(m)
            weights = np.array([np.exp(-abs(m - last) / 2.5) for m in cands])
            note = int(rng.choice(cands, p=weights / weights.sum()))
            last = note
            tr.add(t0 + e_abs * beat / 2, vibes(hz(note), length * beat / 2, 0.8))
    return tr.finish(rng, wet=0.22)


# ----------------------------------------------------------------- torneo y ranked

def jazz_song():
    rng = np.random.default_rng(176)
    bpm = 176
    beat = 60 / bpm
    bar = beat * 4
    sw = 0.66  # corchea de swing: la segunda cae a dos tercios del pulso
    blues = [["Bb7"], ["Eb7"], ["Bb7"], ["Bb7"], ["Eb7"], ["Eb7"], ["Bb7"], ["G7"],
             ["Cm7"], ["F7"], ["Bb7", "G7"], ["Cm7", "F7"]]
    choruses = 4
    bars = len(blues) * choruses
    tr = Track(bars * bar)
    dr = make_drums(rng)
    blues_scale = [0, 3, 5, 6, 7, 10]
    # Tema: un riff de dos compases (pulso, semitonos desde Si bemol 4, duración en pulsos).
    riff = [(0, 3, 0.4), (sw, 4, 0.3), (1, 7, 0.9), (2 + sw, 10, 0.3), (3, 7, 0.6),
            (4 + sw, 3, 0.3), (5, 0, 1.6)]
    turn = [(0, 12, 0.4), (sw, 10, 0.3), (1, 7, 0.4), (1 + sw, 6, 0.3), (2, 5, 0.4), (2 + sw, 3, 0.3),
            (3, 0, 0.9), (4 + sw, 7, 0.3), (5, 10, 0.4), (5 + sw, 9, 0.3), (6, 7, 0.4), (6 + sw, 5, 0.3),
            (7, 4, 0.9)]
    head = {0: (riff, 0), 2: (riff, 0), 4: (riff, 5), 6: (riff, 0), 8: (riff, 7), 10: (turn, 0)}
    last = 74
    for b in range(bars):
        chorus, k = divmod(b, len(blues))
        chords = blues[k]
        t0 = b * bar
        nxt = blues[(k + 1) % len(blues)][0]
        # Bajo caminando: fundamental, notas del acorde y aproximación cromática.
        for q in range(4):
            chord = chords[0] if q < 2 or len(chords) == 1 else chords[1]
            root = bass_root(chord, 34)
            ct = sorted(chord_tones(chord))
            if q == 0 or (q == 2 and len(chords) > 1):
                n = root
            elif q == 3:
                n = bass_root(nxt, 34) + int(rng.choice([-1, 1]))
            else:
                pc = int(rng.choice(ct))
                n = root + (pc - root % 12) % 12
            tr.add(t0 + q * beat, bass(hz(n), beat * 0.95, 0.9 + (0.1 if q == 0 else 0)))
        # Batería: ride "ding, ding-a", charles con el pie en 2 y 4, fantasmas.
        for at, v in ((0, 0.9), (1, 1.0), (1 + sw, 0.6), (2, 0.9), (3, 1.0), (3 + sw, 0.6)):
            tr.add(t0 + at * beat, dr["ride"], v)
        for at in (1, 3):
            tr.add(t0 + at * beat, dr["foot"], 1.0)
        for q in range(4):
            tr.add(t0 + q * beat, dr["kick"], 0.15)
            if rng.random() < 0.35:
                tr.add(t0 + (q + sw) * beat, dr["ghost"], rng.uniform(0.6, 1.0))
        if k == len(blues) - 1:
            tr.add(t0 + (3 + sw) * beat, dr["brush"], 1.4)
        # Piano: acordes cortos en contratiempo (ritmo Charleston y variantes).
        pattern = [[0, 1 + sw], [sw, 2 + sw], [1 + sw, 3 + sw], [0, 2], [2 + sw]][int(rng.integers(0, 5))]
        for at in pattern:
            chord = chords[0] if at < 2 or len(chords) == 1 else chords[1]
            for n in voicing(chord, 57):
                tr.add(t0 + at * beat, epiano(hz(n), beat * 0.45, 0.5))
        # Saxo: tema en la primera y la última vuelta; improvisación en medio.
        if chorus in (0, choruses - 1):
            if k in head:
                notes, up = head[k]
                for at, semi, dur in notes:
                    tr.add(t0 + at * beat, sax(hz(70 + semi + up), dur * beat, 0.9, rng))
        else:
            if k % 2 == 0:
                rest_from = int(rng.integers(10, 15))
            for e in range(8):
                pos = (k % 2) * 8 + e
                if pos >= rest_from or (pos == 0 and rng.random() < 0.5):
                    continue
                at = e // 2 + (sw if e % 2 else 0)
                chord = chords[0] if at < 2 or len(chords) == 1 else chords[1]
                tones = chord_tones(chord)
                strong = e % 2 == 0
                cands = [m for m in range(62, 84)
                         if (m % 12) in tones or (not strong and (m - 70) % 12 in blues_scale)]
                weights = np.array([np.exp(-abs(m - last) / 2.0) for m in cands])
                note = int(rng.choice(cands, p=weights / weights.sum()))
                last = note
                long_note = pos == rest_from - 1
                tr.add(t0 + at * beat, sax(hz(note), beat * (1.2 if long_note else 0.4), 0.8 if strong else 0.65, rng))
    return tr.finish(rng, wet=0.16)


def main():
    save_ogg(menu_song(), os.path.join(ROOT, "audio", "menu", "menu_lounge.ogg"))
    save_ogg(jazz_song(), os.path.join(ROOT, "audio", "event", "jazz_activo.ogg"))


if __name__ == "__main__":
    main()
