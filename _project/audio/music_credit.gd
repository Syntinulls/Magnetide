extends Resource
class_name MusicCredit

## Attribution for one music track, authored beside the track it credits as
## `<track_filename>.credit.tres` (the track keeps its verbatim source filename, spec §3).
## The credits screen finds these by scanning the same BGM category folders playback scans,
## so crediting a new track is a file drop next to it rather than a code edit — the rule the
## BgmPlayer already follows for the tracks themselves.
##
## Every field exists because the license requires it. CC BY asks for the title of the
## material, the name of the author, a link to the material, a link to the license, and a
## statement of whether the material was changed.

## Track title as its source credits it.
@export var title: String = ""
## Author to credit, exactly as the source names them. Required by the license.
@export var artist: String = ""
## Link to the material on the site it came from.
@export var source_url: String = ""
## License name shown beside the track.
@export var license: String = "CC BY 3.0"
## Link to the license deed.
@export var license_url: String = "https://creativecommons.org/licenses/by/3.0/"
## True when the track was altered for the game (trimmed, looped, re-mixed). CC BY requires
## saying so when it is.
@export var modified: bool = false


## True once this credit carries everything the license asks for. The credits screen lists
## an incomplete entry anyway — quietly dropping a credit is worse than showing a gap — so
## this exists to make the gaps findable rather than to gate display.
func is_complete() -> bool:
	return not title.strip_edges().is_empty() \
		and not artist.strip_edges().is_empty() \
		and not source_url.strip_edges().is_empty()


## The credit file that belongs beside `track_path`, whether or not it exists yet.
static func path_for_track(track_path: String) -> String:
	return "%s.credit.tres" % track_path.get_basename()
