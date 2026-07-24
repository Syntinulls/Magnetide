class_name ThrusterAudio
extends Node

## Continuous ship-thruster engine loop whose pitch tracks the thrusters' mode.
##
## pitch_scale drives both pitch and playback speed, so each mode is heard as a
## different tone *and* tempo: a deep, slow hum when the ship is stopped or
## coming to a stop, the normal tone in transit, and a faster high-pitched whine
## while the thrusters boost (the loop_2 boost sprite — departure lift-off and
## the threat-advance turbo). The pitch eases between modes so the engine audibly
## spins up as it speeds up and winds down as it slows.

enum Mode { SLOW, NORMAL, BOOST }

const THRUSTER_LOOP_PATH := "res://_project/audio/sfx/ship/thrusters_medium.ogg"

## Target pitch_scale per mode. Higher = higher-pitched and faster playback.
const MODE_PITCH := {
	Mode.SLOW: 0.7,
	Mode.NORMAL: 1.0,
	Mode.BOOST: 1.4,
}

@export var volume_db: float = -12.0
## Fraction of the remaining pitch gap closed per second while easing to a mode.
@export var pitch_lerp_speed: float = 3.0

var _target_pitch: float = MODE_PITCH[Mode.NORMAL]
var _player: AudioStreamPlayer = null


func _ready() -> void:
	var stream := _load_looping_stream()
	if stream == null:
		return

	_player = AudioStreamPlayer.new()
	_player.bus = SfxPlayer.SFX_BUS_NAME
	_player.volume_db = volume_db
	_player.stream = stream
	_player.pitch_scale = _target_pitch
	add_child(_player)
	_player.play()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var weight := clampf(pitch_lerp_speed * delta, 0.0, 1.0)
	_player.pitch_scale = lerpf(_player.pitch_scale, _target_pitch, weight)


func set_mode(mode: Mode) -> void:
	_target_pitch = MODE_PITCH[mode]


## Drives the pitch straight from the ship's normalised speed (1.0 = full transit
## speed, 0.0 = stopped), interpolating between the SLOW and NORMAL tones. This
## keeps the engine winding down in lockstep with the plume slowdown animation
## (which also tracks speed_ratio) rather than easing on its own clock. The boost
## cutscenes override this with set_mode(BOOST).
func follow_speed_ratio(speed_ratio: float) -> void:
	_target_pitch = lerpf(MODE_PITCH[Mode.SLOW], MODE_PITCH[Mode.NORMAL], clampf(speed_ratio, 0.0, 1.0))


func _load_looping_stream() -> AudioStream:
	if not ResourceLoader.exists(THRUSTER_LOOP_PATH, "AudioStream"):
		push_warning("ThrusterAudio could not find engine loop: %s" % THRUSTER_LOOP_PATH)
		return null

	var stream := ResourceLoader.load(THRUSTER_LOOP_PATH, "AudioStream") as AudioStream
	if stream == null:
		push_warning("ThrusterAudio could not load engine loop: %s" % THRUSTER_LOOP_PATH)
		return null

	# OGG imports default to loop=false; duplicate so we never mutate the shared
	# cached resource, then force gapless native looping.
	if "loop" in stream and not stream.loop:
		stream = stream.duplicate() as AudioStream
		stream.loop = true
	return stream
