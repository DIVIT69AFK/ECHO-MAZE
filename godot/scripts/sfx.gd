extends Node
## Sound. Every sound has a name (for example "clap"). If a file with that name exists in
## res://audio (clap.ogg, clap.wav or clap.mp3) it is used. Otherwise a simple stand-in
## sound is made in code, so the game is never silent while real audio is being recorded.
##
## Sounds given a world position are played in space: quieter with distance, panned left
## or right, and muffled when a wall is between the sound and the player.

const RATE := 22050
var muted := false
var cache := {}
var hum: AudioStreamPlayer2D
var drone: AudioStreamPlayer

## Stand-in sounds. Each is a list of layers:
## t = "noise" or "tone", f = pitch (Hz), d = length (s), k = how fast it dies away,
## v = loudness, s = pitch slide over its length (Hz), lp = muffling for noise (0 none … near 0 very dull)
const RECIPES := {
	"clap": [{ "t": "noise", "d": 0.2, "k": 26.0, "v": 0.9 }, { "t": "tone", "f": 170.0, "d": 0.09, "k": 30.0, "v": 0.5 }],
	"whisper": [{ "t": "noise", "d": 0.4, "k": 8.0, "v": 0.22, "lp": 0.3 }],
	"step_0": [{ "t": "noise", "d": 0.07, "k": 55.0, "v": 0.35, "lp": 0.3 }],
	"step_1": [{ "t": "tone", "f": 520.0, "d": 0.09, "k": 38.0, "v": 0.22 }, { "t": "noise", "d": 0.04, "k": 70.0, "v": 0.2 }],
	"step_2": [{ "t": "noise", "d": 0.14, "k": 22.0, "v": 0.35, "lp": 0.12 }],
	"step_3": [{ "t": "noise", "d": 0.06, "k": 60.0, "v": 0.2, "lp": 0.07 }],
	"pebble": [{ "t": "tone", "f": 950.0, "d": 0.07, "k": 45.0, "v": 0.5, "s": -300.0 }, { "t": "noise", "d": 0.05, "k": 60.0, "v": 0.4 }],
	"toss": [{ "t": "noise", "d": 0.14, "k": 18.0, "v": 0.18, "lp": 0.5 }],
	"chime": [{ "t": "tone", "f": 660.0, "d": 2.4, "k": 2.0, "v": 0.45 }, { "t": "tone", "f": 990.0, "d": 2.0, "k": 2.6, "v": 0.3 }, { "t": "tone", "f": 1321.0, "d": 1.6, "k": 3.2, "v": 0.2 }],
	"door": [{ "t": "noise", "d": 0.7, "k": 5.0, "v": 0.5, "lp": 0.08 }, { "t": "tone", "f": 70.0, "d": 0.7, "k": 4.0, "v": 0.5 }],
	"hurt": [{ "t": "tone", "f": 240.0, "d": 0.16, "k": 18.0, "v": 0.4, "s": -110.0 }],
	"kill": [{ "t": "noise", "d": 0.5, "k": 8.0, "v": 0.5, "lp": 0.2 }, { "t": "tone", "f": 120.0, "d": 0.5, "k": 7.0, "v": 0.5, "s": -70.0 }],
	"death": [{ "t": "tone", "f": 150.0, "d": 1.3, "k": 3.0, "v": 0.6, "s": -110.0 }, { "t": "noise", "d": 0.8, "k": 5.0, "v": 0.35, "lp": 0.15 }],
	"descend": [{ "t": "tone", "f": 340.0, "d": 1.1, "k": 3.0, "v": 0.4, "s": -210.0 }],
	"note": [{ "t": "tone", "f": 880.0, "d": 0.5, "k": 7.0, "v": 0.3 }, { "t": "tone", "f": 1320.0, "d": 0.5, "k": 8.0, "v": 0.2 }],
	"secret": [{ "t": "tone", "f": 523.0, "d": 0.8, "k": 4.0, "v": 0.25 }, { "t": "tone", "f": 659.0, "d": 0.8, "k": 4.0, "v": 0.25 }, { "t": "tone", "f": 784.0, "d": 0.8, "k": 4.0, "v": 0.25 }],
	"achievement": [{ "t": "tone", "f": 784.0, "d": 0.6, "k": 6.0, "v": 0.25 }, { "t": "tone", "f": 1047.0, "d": 0.6, "k": 5.0, "v": 0.25 }],
	"growl": [{ "t": "tone", "f": 68.0, "d": 0.55, "k": 5.0, "v": 0.6 }, { "t": "noise", "d": 0.5, "k": 6.0, "v": 0.25, "lp": 0.06 }],
	"shriek": [{ "t": "tone", "f": 1350.0, "d": 0.75, "k": 4.0, "v": 0.45, "s": 650.0 }, { "t": "noise", "d": 0.6, "k": 5.0, "v": 0.3 }],
	"sleeper_wake": [{ "t": "tone", "f": 58.0, "d": 1.1, "k": 2.5, "v": 0.7, "s": 40.0 }, { "t": "noise", "d": 1.0, "k": 3.0, "v": 0.35, "lp": 0.08 }],
	"sleeper_breathe": [{ "t": "noise", "d": 1.3, "k": 2.5, "v": 0.3, "lp": 0.04 }],
	"heartbeat": [{ "t": "tone", "f": 56.0, "d": 0.16, "k": 24.0, "v": 0.9 }],
	"compass": [{ "t": "tone", "f": 1200.0, "d": 0.28, "k": 10.0, "v": 0.25 }],
	"ambient_0": [{ "t": "tone", "f": 300.0, "d": 0.7, "k": 5.0, "v": 0.15, "s": -40.0 }],
	"ambient_1": [{ "t": "tone", "f": 700.0, "d": 0.35, "k": 10.0, "v": 0.2 }, { "t": "tone", "f": 1130.0, "d": 0.3, "k": 12.0, "v": 0.12 }],
	"ambient_2": [{ "t": "tone", "f": 1100.0, "d": 0.12, "k": 30.0, "v": 0.3, "s": 420.0 }],
	"ambient_3": [{ "t": "tone", "f": 180.0, "d": 0.5, "k": 6.0, "v": 0.2, "s": 60.0 }],
}


func _ready() -> void:
	_add_bus("SFX", "Master")
	var rev = AudioEffectReverb.new()
	rev.room_size = 0.85
	rev.damping = 0.4
	rev.wet = 0.32
	rev.dry = 0.9
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), rev)
	# sounds heard through a wall lose their high notes
	_add_bus("Muffled", "SFX")
	var lp = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 750.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Muffled"), lp)
	_add_bus("Ambience", "Master")

	hum = AudioStreamPlayer2D.new()
	hum.stream = _file_or("hum", func(): return _loop([196.0, 293.7], 2.0, 0.22, true))
	hum.bus = "SFX"
	hum.max_distance = 980.0
	hum.attenuation = 2.0
	add_child(hum)
	drone = AudioStreamPlayer.new()
	drone.bus = "Ambience"
	drone.volume_db = -14.0
	add_child(drone)


func _add_bus(bus_name: String, send: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, send)


func apply_volumes(s: Dictionary) -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, s.masterVol)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, s.sfxVol)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(0.0001, s.ambVol)))


## Play a sound. Give `pos` (a place in the world) to hear it from that direction and distance.
func play(sound: String, pos = null, vol := 1.0) -> void:
	var stream = _stream(sound)
	if stream == null:
		return
	var game = get_parent()
	if pos != null and game.has_level:
		var p = AudioStreamPlayer2D.new()
		p.stream = stream
		p.position = pos
		p.max_distance = 1000.0
		p.attenuation = 1.5
		p.volume_db = linear_to_db(maxf(0.001, vol))
		var blocked: bool = pos.distance_to(game.player) > 40.0 and not game.clear_line(game.player, pos)
		p.bus = "Muffled" if blocked else "SFX"
		p.finished.connect(p.queue_free)
		add_child(p)
		p.play()
	else:
		var q = AudioStreamPlayer.new()
		q.stream = stream
		q.bus = "SFX"
		q.volume_db = linear_to_db(maxf(0.001, vol))
		q.finished.connect(q.queue_free)
		add_child(q)
		q.play()


func start_level_audio(surf: int, exit_pos: Vector2) -> void:
	hum.position = exit_pos
	if not hum.playing:
		hum.play()
	var base: Array = [[55.0, 55.6, 82.4], [60.0, 60.5, 90.0], [48.0, 52.0, 74.0], [55.0, 55.6, 82.4]][surf]
	drone.stream = _file_or("drone_%d" % surf, func(): return _loop(base, 4.0, 0.3, false))
	drone.play()


func stop_level_audio() -> void:
	hum.stop()
	drone.stop()


## The hum that leads to the way down is muffled when a wall is in the way
func update_listener(_player: Vector2, exit_pos: Vector2, blocked: bool) -> void:
	hum.position = exit_pos
	hum.bus = "Muffled" if blocked else "SFX"


# ---------------------------------------------------------------- where sounds come from
func _file_or(sound: String, make: Callable) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path = "res://audio/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return make.call()


func _stream(sound: String) -> AudioStream:
	if not cache.has(sound):
		cache[sound] = _file_or(sound, func(): return _synth(RECIPES[sound]) if RECIPES.has(sound) else null)
	return cache[sound]


func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _synth(layers: Array) -> AudioStreamWAV:
	var length = 0.0
	for l in layers:
		length = maxf(length, l.d)
	var out = PackedFloat32Array()
	out.resize(int(length * RATE))
	for l in layers:
		var n = int(l.d * RATE)
		var phase = 0.0
		var low = 0.0
		var lp: float = l.get("lp", 0.0)
		for i in n:
			var t = float(i) / RATE
			var v = 0.0
			if l.t == "tone":
				phase += TAU * (l.f + l.get("s", 0.0) * t / l.d) / RATE
				v = sin(phase)
			else:
				v = randf() * 2.0 - 1.0
				if lp > 0.0:
					low += (v - low) * lp
					v = low * 2.5
			out[i] += v * l.v * exp(-t * l.k) * minf(1.0, t * 400.0)
	return _wav(out)


## A steady tone made of a few pitches, cut to a length that loops without a click
func _loop(freqs: Array, seconds: float, vol: float, tremolo: bool) -> AudioStreamWAV:
	var n = int(seconds * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	for f in freqs:
		var cycles = roundf(f * seconds)   # whole number of cycles, so the end meets the start
		for i in n:
			out[i] += sin(TAU * cycles * i / n) * vol / freqs.size()
	if tremolo:
		for i in n:
			out[i] *= 0.65 + 0.35 * sin(TAU * i / n)
	return _wav(out, true)
