extends Node
## Efectos de sonido. Casi todos se sintetizan por código; además, los audios
## grabados que haya en res://audio/<id>/ sustituyen al efecto de ese nombre
## (por ahora solo "pass": al pasar suena uno al azar de esa carpeta).

const RATE := 22050
const CLIP_DIR := "res://audio/"

var _streams := {}
## Audios grabados por id de efecto.
var _clips := {}
var _last_clip := {}
var _voice: AudioStreamPlayer
var _players: Array = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	_streams["clack"] = _wav(_mix([_noise(0.09, 70.0, 0.8), _tone(1800.0, 0.09, 90.0, 0.4), _tone(320.0, 0.09, 40.0, 0.6)]))
	_streams["tick"] = _wav(_mix([_noise(0.035, 160.0, 0.5), _tone(2400.0, 0.035, 160.0, 0.3)]))
	_streams["click"] = _wav(_tone(900.0, 0.06, 60.0, 0.5))
	_streams["bad"] = _wav(_tone(150.0, 0.14, 18.0, 0.6))
	_streams["pass"] = _wav(_seq([420.0, 300.0], 0.11, 22.0))
	_streams["shuffle"] = _wav(_shuffle())
	_streams["win"] = _wav(_seq([523.0, 659.0, 784.0, 1047.0], 0.13, 9.0))
	_streams["lose"] = _wav(_seq([392.0, 311.0, 262.0], 0.2, 7.0))
	_streams["point"] = _wav(_seq([880.0, 1320.0], 0.07, 25.0))
	_streams["gulp"] = _wav(_seq([210.0, 150.0, 200.0, 140.0], 0.11, 16.0))
	_streams["chalk"] = _wav(_mix([_noise(0.35, 5.0, 0.35), _tone(2900.0, 0.35, 9.0, 0.05)]))
	_clips["pass"] = _load_folder(CLIP_DIR + "pass")


func play(id: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(id)
	var clips: Array = _clips.get(id, [])
	if not clips.is_empty():
		# Audio grabado: uno al azar, sin repetir el anterior, y a su tono real.
		var pick := _rng.randi_range(0, clips.size() - 1)
		if clips.size() > 1 and pick == _last_clip.get(id, -1):
			pick = (pick + 1) % clips.size()
		_last_clip[id] = pick
		# Los audios grabados duran varios segundos: van por un canal propio y
		# el nuevo corta al anterior, para que dos pases seguidos no se pisen.
		_voice.stream = clips[pick]
		_voice.play()
		return
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


## Carga todos los audios (.wav, .ogg, .mp3) de una carpeta del proyecto.
func _load_folder(dir_path: String) -> Array:
	var out: Array = []
	var seen := {}
	for file in DirAccess.get_files_at(dir_path):
		# En el juego exportado solo quedan los ".import"; el audio se carga por su nombre original.
		var fname := file.trim_suffix(".import")
		if seen.has(fname) or not fname.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
			continue
		seen[fname] = true
		var path := dir_path.path_join(fname)
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path)
		else:
			# Archivo recién copiado que el editor aún no ha importado.
			match fname.get_extension().to_lower():
				"wav": stream = AudioStreamWAV.load_from_file(path)
				"ogg": stream = AudioStreamOggVorbis.load_from_file(path)
				"mp3": stream = AudioStreamMP3.load_from_file(path)
		if stream != null:
			out.append(stream)
	return out


func _tone(freq: float, dur: float, decay: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * exp(-t * decay) * vol
	return out


func _noise(dur: float, decay: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / RATE
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), 0.55)
		out[i] = last * exp(-t * decay) * vol
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = parts[0].duplicate()
	for k in range(1, parts.size()):
		var part: PackedFloat32Array = parts[k]
		for i in mini(out.size(), part.size()):
			out[i] += part[i]
	return out


func _seq(freqs: Array, note: float, decay: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_mix([_tone(f, note, decay, 0.45), _tone(f * 2.0, note, decay * 1.5, 0.15)]))
	return out


func _shuffle() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.3 * RATE))
	out.fill(0.0)
	for c in 9:
		var burst := _noise(0.03, 150.0, _rng.randf_range(0.25, 0.55))
		var at := _rng.randi_range(0, out.size() - burst.size() - 1)
		for i in burst.size():
			out[at + i] += burst[i]
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
