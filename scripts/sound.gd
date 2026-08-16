extends Node

# Odd harmonics (multiplier, relative amplitude) approximate a steel tongue's
# bright, bell-like timbre; weights sum to ~1.0 so mixed output stays in range.
const HARMONICS := [
	[1.0, 0.61],
	[3.0, 0.21],
	[5.0, 0.11],
	[7.0, 0.06],
]

const BUS_NAMES := ["Tones", "UI"]

# Real bar/plate resonators (like a steel tongue) aren't a perfect harmonic
# series - higher partials run slightly sharp of the ideal integer ratio.
# Stretched partial n -> n * sqrt(1 + B*n^2); kept very small so it adds a
# touch of realism without reading as tinny/out-of-tune.
const INHARMONICITY_B := 0.00012

# A short filtered-noise burst under the attack, like the transient thump of
# a mallet striking metal before the sustained tone takes over. Heavily
# lowpassed (low smoothing factor -> ~800Hz corner) so it reads as a soft
# thud, not hiss/static.
const STRIKE_NOISE_DURATION := 0.015
const STRIKE_NOISE_VOLUME := 0.16
const STRIKE_NOISE_SMOOTHING := 0.12

# A single shared AudioStreamPlayer meant every new tone hard-cut the
# previous one mid-decay (_start_playback() stops it before playing again) -
# no note ever got to ring out, which read as unnaturally clipped/dry for
# anything meant to overlap, like the glissando sweep. A small round-robin
# voice pool lets up to VOICE_POOL_SIZE notes ring concurrently while still
# bounding total voices (the oldest slot gets stolen on the Nth+1 note).
const VOICE_POOL_SIZE := 4

# Stealing a still-ringing voice (5th+ concurrent note) used to hard-cut it
# via stop()+play(), producing an audible click since the buffer was mid-
# decay. A very short volume fade before the cut smooths that transition
# without adding perceptible latency to the new note.
const VOICE_STEAL_FADE_SEC := 0.008

# Sample generation was previously one uninterrupted loop per note (up to
# ~70,560 samples for a full-duration pad tone) - fast in absolute terms,
# but still real synchronous CPU cost dumped into a single frame, worse on
# Web export/low-end hardware (see the stutter this was already linked to).
# Chunking spreads that cost across frames instead. 4096 samples (~93ms of
# audio) per chunk generates roughly 5-6x faster than it's consumed at
# 60fps, so the buffer stays comfortably ahead of playback (no audible
# gaps) down to very low frame rates - this is a CPU-cost fix, not a
# real-time-synthesis one; generation still finishes far ahead of the note
# actually finishing playback.
const SYNTH_CHUNK_SAMPLES := 4096
var _voice_players: Array[AudioStreamPlayer] = []
var _voice_generators: Array[AudioStreamGenerator] = []
var _next_voice := 0
var _ui_player: AudioStreamPlayer
var _ui_generator: AudioStreamGenerator

func _ready() -> void:
	_setup_buses()
	for i in VOICE_POOL_SIZE:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 44100.0
		gen.buffer_length = 2.0
		var player := AudioStreamPlayer.new()
		player.stream = gen
		player.bus = "Tones"
		add_child(player)
		_voice_players.append(player)
		_voice_generators.append(gen)
	_ui_generator = AudioStreamGenerator.new()
	_ui_generator.mix_rate = 44100.0
	_ui_generator.buffer_length = 1.0
	_ui_player = AudioStreamPlayer.new()
	_ui_player.stream = _ui_generator
	_ui_player.bus = "UI"
	add_child(_ui_player)

func _setup_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	# Up to VOICE_POOL_SIZE voices can ring concurrently by design (see the
	# pool comment below); Godot sums bus inputs linearly, so several
	# overlapping full-volume notes can sum past +-1.0 and hard-clip without
	# this.
	var tones_idx := AudioServer.get_bus_index("Tones")
	if tones_idx != -1 and AudioServer.get_bus_effect_count(tones_idx) == 0:
		AudioServer.add_bus_effect(tones_idx, AudioEffectLimiter.new())

func set_bus_volume_linear(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(volume, 0.0, 1.0)))

func play_tone(freq: float, duration := 1.6, volume := 0.5, decay_rate := 3.2) -> void:
	_generate_harmonic(freq, duration, volume, decay_rate)

func play_fail() -> void:
	# A low, soft tongue note rather than a harsh buzzer - stays "chill".
	_generate_harmonic(98.0, 1.1, 0.3, 2.2)

func play_ui_tick(freq := 660.0, volume := 0.22) -> void:
	# Soft, bell-like click for routine UI interactions - same harmonic
	# synthesis as pad tones, but short and quiet so it never distracts.
	var playback := _start_ui_playback()
	if playback == null:
		return
	var mix_rate := _ui_generator.mix_rate
	var duration := 0.18
	var sample_count := int(mix_rate * duration)
	var i := 0
	while i < sample_count:
		var chunk_end: int = mini(i + SYNTH_CHUNK_SAMPLES, sample_count)
		while i < chunk_end:
			var t := float(i) / mix_rate
			var envelope := exp(-14.0 * t)
			var sample := 0.0
			for h in HARMONICS:
				sample += sin(TAU * freq * h[0] * t) * h[1]
			sample *= volume * envelope
			if not playback.push_frame(Vector2(sample, sample)):
				push_warning("play_ui_tick: generator buffer full, dropping remaining samples")
				return
			i += 1
		if i < sample_count:
			if _ui_player.get_stream_playback() != playback:
				return
			await get_tree().process_frame

func _start_ui_playback() -> AudioStreamGeneratorPlayback:
	_ui_player.stop()
	_ui_player.play()
	return _ui_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _generate_harmonic(freq: float, duration: float, volume: float, decay_rate: float) -> void:
	var voice := await _start_playback()
	var playback: AudioStreamGeneratorPlayback = voice["playback"]
	if playback == null:
		return
	var mix_rate := 44100.0
	var sample_count := int(mix_rate * duration)
	var noise_samples := int(mix_rate * STRIKE_NOISE_DURATION)
	var filtered_noise := 0.0
	var i := 0
	while i < sample_count:
		var chunk_end: int = mini(i + SYNTH_CHUNK_SAMPLES, sample_count)
		while i < chunk_end:
			var t := float(i) / mix_rate
			var envelope := exp(-decay_rate * t)
			var sample := 0.0
			for h in HARMONICS:
				var n: float = h[0]
				var stretched_n := n * sqrt(1.0 + INHARMONICITY_B * n * n)
				sample += sin(TAU * freq * stretched_n * t) * h[1]
			if i < noise_samples:
				var raw_noise := randf_range(-1.0, 1.0)
				filtered_noise += (raw_noise - filtered_noise) * STRIKE_NOISE_SMOOTHING
				var noise_envelope := exp(-t / (STRIKE_NOISE_DURATION * 0.3))
				sample += filtered_noise * noise_envelope * STRIKE_NOISE_VOLUME
			sample *= volume * envelope
			if not playback.push_frame(Vector2(sample, sample)):
				push_warning("_generate_harmonic: generator buffer full, dropping remaining samples")
				return
			i += 1
		if i < sample_count:
			if not _voice_is_current(voice):
				return
			await get_tree().process_frame

# Returns {"player":.., "playback":..} rather than just the playback so a
# chunked generator (above) can later check _voice_is_current() and bail
# out if this voice gets stolen by a new note mid-generation, instead of
# wastefully finishing a buffer nobody will hear.
func _start_playback() -> Dictionary:
	var player := _voice_players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_POOL_SIZE
	if player.playing:
		await _fade_out_voice(player)
	else:
		player.stop()
	player.play()
	return {"player": player, "playback": player.get_stream_playback() as AudioStreamGeneratorPlayback}

func _voice_is_current(voice: Dictionary) -> bool:
	return voice["player"].get_stream_playback() == voice["playback"]

func _fade_out_voice(player: AudioStreamPlayer) -> void:
	var original_db := player.volume_db
	var tween := create_tween()
	tween.tween_property(player, "volume_db", original_db - 24.0, VOICE_STEAL_FADE_SEC)
	await tween.finished
	player.stop()
	player.volume_db = original_db
