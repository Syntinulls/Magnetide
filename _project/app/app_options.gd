extends RefCounted
class_name AppOptions

## Player-facing settings, persisted separately from game saves as an ini file
## under user:// (sections mirror the options screen tabs). Loaded and applied
## at startup by the Magnetide autoload; edited by OptionsScreen.

const PATH := "user://options.ini"
const AUDIO_SECTION := "audio"
const DEFAULT_VOLUME_PERCENT := 100.0
## Bus level at a 100% music slider. Kept below full scale so the placeholder
## tracks (mastered hot) sit under gameplay SFX; raise toward 0 dB once real
## masters land. SFX at 100% stays at full scale (0 dB).
const MUSIC_FULL_VOLUME_DB := -6.0
const SFX_FULL_VOLUME_DB := 0.0
## dB span the slider covers below full volume. Percents map linearly in dB
## (perceived loudness) across it, so the slider's travel feels even; 0% is a
## hard bus mute instead of the bottom of the span.
const VOLUME_RANGE_DB := 40.0

var music_volume: float = DEFAULT_VOLUME_PERCENT
var sfx_volume: float = DEFAULT_VOLUME_PERCENT


## Push the current values onto the audio buses.
func apply() -> void:
	if Magnetide.bgm:
		Magnetide.bgm.set_music_volume(_percent_to_linear(music_volume, MUSIC_FULL_VOLUME_DB))
	if Magnetide.sfx:
		Magnetide.sfx.set_sfx_volume(_percent_to_linear(sfx_volume, SFX_FULL_VOLUME_DB))


func save_to_disk() -> void:
	var file := ConfigFile.new()
	# Load-then-set so sections this class doesn't own survive a save; a missing
	# file just leaves the ConfigFile empty, which is fine.
	file.load(PATH)
	file.set_value(AUDIO_SECTION, "music_volume", music_volume)
	file.set_value(AUDIO_SECTION, "sfx_volume", sfx_volume)
	file.save(PATH)


func equals(other: AppOptions) -> bool:
	return other != null \
		and is_equal_approx(music_volume, other.music_volume) \
		and is_equal_approx(sfx_volume, other.sfx_volume)


## 0% -> 0.0 gain (the player services hard-mute the bus); otherwise the
## percent interpolates linearly in dB from (full - VOLUME_RANGE_DB) up to
## full_db at 100%, returned as the linear gain the player services expect.
static func _percent_to_linear(percent: float, full_db: float) -> float:
	if percent <= 0.0:
		return 0.0
	var db := full_db - VOLUME_RANGE_DB * (1.0 - percent / 100.0)
	return db_to_linear(db)


static func load_from_disk() -> AppOptions:
	var options := AppOptions.new()
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		options.music_volume = clampf(float(file.get_value(AUDIO_SECTION, "music_volume", DEFAULT_VOLUME_PERCENT)), 0.0, 100.0)
		options.sfx_volume = clampf(float(file.get_value(AUDIO_SECTION, "sfx_volume", DEFAULT_VOLUME_PERCENT)), 0.0, 100.0)
	return options
