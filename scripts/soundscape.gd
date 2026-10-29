class_name SongaSound
extends Node
## Small, original synthesized feedback cues; no recordings or external assets.

const SAMPLE_RATE := 22050
const VOICES := 6
const TAU_F := PI * 2.0

var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			for player: AudioStreamPlayer in _players:
				player.stop()

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	_prepare_streams()
	for index in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "CueVoice%d" % index
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)


func play_jump() -> void:
	_play(&"jump")


func play_pickup() -> void:
	_play(&"pickup")


func play_hit() -> void:
	_play(&"hit")


func play_start() -> void:
	_play(&"start")


func play_end() -> void:
	_play(&"end")


func _play(cue: StringName) -> void:
	# Calls before entering the tree are harmless, and never create orphan nodes.
	if not enabled or _players.is_empty():
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stop()
	player.stream = _streams[cue]
	player.play()


func _prepare_streams() -> void:
	if not _streams.is_empty():
		return
	# Each note is [frequency, onset, duration, gain, pitch bend in Hz].
	_streams[&"jump"] = _synthesize([
		[260.0, 0.0, 0.19, 0.55, 250.0],
	])
	_streams[&"pickup"] = _synthesize([
		[784.0, 0.0, 0.13, 0.44, 0.0],
		[1046.5, 0.065, 0.18, 0.40, 0.0],
	])
	_streams[&"hit"] = _synthesize([
		[145.0, 0.0, 0.23, 0.64, -65.0],
		[95.0, 0.035, 0.17, 0.23, -25.0],
	])
	_streams[&"start"] = _synthesize([
		[392.0, 0.0, 0.21, 0.40, 0.0],
		[523.25, 0.09, 0.23, 0.40, 0.0],
		[659.25, 0.18, 0.28, 0.38, 0.0],
		[784.0, 0.27, 0.33, 0.34, 0.0],
	])
	_streams[&"end"] = _synthesize([
		[523.25, 0.0, 0.25, 0.40, 0.0],
		[392.0, 0.13, 0.27, 0.38, 0.0],
		[329.63, 0.26, 0.40, 0.34, 0.0],
	])


func _synthesize(notes: Array) -> AudioStreamWAV:
	var duration: float = 0.0
	for note: Array in notes:
		duration = maxf(duration, float(note[1]) + float(note[2]))
	var sample_count := ceili(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var sample_time := float(index) / SAMPLE_RATE
		var sample: float = 0.0
		for note: Array in notes:
			var local_time := sample_time - float(note[1])
			var note_length := float(note[2])
			if local_time < 0.0 or local_time >= note_length:
				continue
			var progress := local_time / note_length
			# Short attack and soft release prevent clicks; the bell-like second
			# partial decays faster than the fundamental.
			var attack := minf(local_time / 0.008, 1.0)
			var release := minf((note_length - local_time) / 0.045, 1.0)
			var envelope := attack * release * exp(-4.0 * progress)
			var phase := TAU_F * (float(note[0]) * local_time
				+ 0.5 * float(note[4]) * local_time * progress)
			var fundamental := sin(phase)
			var overtone := 0.19 * sin(phase * 2.003) * exp(-6.0 * progress)
			sample += float(note[3]) * envelope * (fundamental + overtone)
		# Headroom remains even when six short cues overlap at the mixer.
		var pcm := clampi(roundi(sample * 16000.0), -32768, 32767)
		data.encode_s16(index * 2, pcm)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
