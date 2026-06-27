@tool
extends Control
class_name ThreatUI

## Top-center "wing" threat bar with 10 segments.
##
## Components:
##   - Base: the wing-shaped gradient background, with the segment dividers and
##     the central dome baked into the sprite.
##   - LockedOverlay: a TextureProgressBar (fills right -> left) that shades the
##     locked region beyond the current Threat Level Cap. The bar's right end is
##     the highest threat, so right-to-left fill covers the locked levels.
##   - LockIcon: sits at the cap boundary. Its position is sampled from the
##     ticker path so its y follows the slanted/dipping bar edge.
##   - Ticker: rides the underside of the bar along TickerPath (a hand-aligned
##     Path2D) via a PathFollow2D, tracking the continuous threat position.
##   - ThreatNumber: the current threat level, shown large in the central dome,
##     tinted to the gradient color at the current threat position.
##
## TickerPath authoring: select the TickerPath node and lay out the curve points
## along the bottom edge of the bar, starting at the LEFT tip (threat 0) and
## ending at the RIGHT tip (threat 100). The ticker is driven by arc-length, so
## the threat position maps linearly along the full length of whatever curve you
## draw; the lock icon and segment math reuse the same curve.

@export var threat_gradient: Gradient
## Lock icon vertical position (texture px). The bar is visually flat across most
## of its width, so the lock sits at this constant y for every cap boundary...
@export var lock_icon_y: float = 40.0:
	set(v):
		lock_icon_y = v
		_apply_editor_preview()
## ...except the central boundary (cap level 5), where the bar dips into the V and
## the lock drops to this lower y instead.
@export var lock_icon_dip_y: float = 76.0:
	set(v):
		lock_icon_dip_y = v
		_apply_editor_preview()
## Where the striped CONTENT starts and ends within the locked texture (px), used
## to map the 10 segments onto the stripes so each fill edge lands on a baked
## divider. The locked sprite is cropped edge-to-edge (890 px = 10 x 89 px), so
## these default to the full texture; tune only if the sprite is re-padded.
@export var locked_fill_start_px: float = 0.0:
	set(v):
		locked_fill_start_px = v
		_apply_editor_preview()
@export var locked_fill_end_px: float = 890.0:
	set(v):
		locked_fill_end_px = v
		_apply_editor_preview()
## Editor-only: preview the bar at this 0-based cap stage so you can tune the
## fill margins and lock placement live, without running the game.
@export_range(0, 9) var editor_preview_cap: int = 0:
	set(v):
		editor_preview_cap = v
		_apply_editor_preview()

@onready var _locked_overlay: TextureProgressBar = $LockedOverlay
@onready var _lock_icon: Sprite2D = $LockIcon
@onready var _ticker_path: Path2D = $TickerPath
@onready var _ticker_follow: PathFollow2D = $TickerPath/TickerFollow
@onready var _threat_number: Label = $MarginContainer/ThreatNumber

var _threat_manager: ThreatManager = null
var _segment_count: int = ThreatManager.LEVEL_COUNT
var _current_threat: float = 0.0
var _cap_stage: int = 0


func _ready() -> void:
	_segment_count = ThreatManager.LEVEL_COUNT
	if Engine.is_editor_hint():
		# Editor preview only: no threat manager, just lay out at the preview cap.
		_cap_stage = editor_preview_cap
		_refresh_layout()
		return
	if _threat_number and Magnetide and Magnetide.has_method("apply_digital_font"):
		Magnetide.apply_digital_font(_threat_number)
	_update_ticker_level(0)
	call_deferred("_refresh_layout")
	call_deferred("_connect_threat_manager")


func _connect_threat_manager() -> void:
	if Magnetide and Magnetide.level and "threat" in Magnetide.level and Magnetide.level.threat:
		_threat_manager = Magnetide.level.threat
		_threat_manager.threat_changed.connect(_on_threat_changed)
		_threat_manager.threat_level_changed.connect(_on_threat_level_changed)
		_threat_manager.cap_raised.connect(_on_cap_raised)
		_threat_manager.cap_reached.connect(_on_cap_reached)
		_current_threat = _threat_manager.current_threat
		_cap_stage = _threat_manager.threat_level_cap
		_update_ticker_level(_threat_manager.threat_level)
		_refresh_layout()


func _refresh_layout() -> void:
	_update_locked_overlay()
	_position_lock_icon()
	_position_ticker()


## Re-run layout in the editor when a preview/tuning export changes. No-op at
## runtime (the threat manager drives layout there) and before the node is ready.
func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	_cap_stage = editor_preview_cap
	_refresh_layout()


## Number of reachable segments (cap stage + 1); the rest are locked.
func _reachable_segments() -> int:
	return clampi(_cap_stage + 1, 0, _segment_count)


## Shade the locked region: fill right -> left for (total - reachable) segments.
##
## A raw value of N/10 would fill the rightmost N/10 of the FULL texture, but the
## striped content is inset by transparent padding, so the segment boundaries
## would not match the base's baked dividers. Instead we map segments onto the
## [locked_fill_start_px, locked_fill_end_px] content band and convert the
## resulting pixel boundary back into a right-to-left fill fraction.
func _update_locked_overlay() -> void:
	if not _locked_overlay:
		return
	var tex := _locked_overlay.texture_progress
	var tex_width := float(tex.get_width()) if tex else _locked_overlay.size.x
	if tex_width <= 0.0:
		return
	var locked := _segment_count - _reachable_segments()
	var segment_px := (locked_fill_end_px - locked_fill_start_px) / float(_segment_count)
	# Left edge (texture px) of the striped region; grows leftward as levels lock.
	var fill_left := locked_fill_end_px - float(locked) * segment_px
	# Right-to-left fill measures the covered fraction from the texture's right edge.
	var fraction := clampf(1.0 - fill_left / tex_width, 0.0, 1.0)
	_locked_overlay.value = _locked_overlay.max_value * fraction


func _position_ticker() -> void:
	if not _ticker_follow:
		return
	var ratio := clampf(_current_threat / ThreatManager.MAX_THREAT, 0.0, 1.0)
	_ticker_follow.progress = _threat_progress_along_path(ratio)
	_update_threat_color(ratio)


## Map a 0-1 threat ratio to arc-length along the ticker path so that each threat
## level occupies exactly one point-to-point segment of the curve. The 11 curve
## points sit on the segment dividers, so within a (straight) segment arc-length
## is x-linear, making the ticker's x exactly proportional to threat. This is more
## accurate than a plain arc-length ratio, where the longer sloped tip/dip
## segments would pull the ticker off the dividers.
func _threat_progress_along_path(ratio: float) -> float:
	var curve := _ticker_path.curve if _ticker_path else null
	if curve == null or curve.point_count < 2:
		return 0.0
	var segments := curve.point_count - 1
	var scaled := clampf(ratio, 0.0, 1.0) * float(segments)
	var seg := clampi(int(scaled), 0, segments - 1)
	var frac := scaled - float(seg)
	var progress := 0.0
	for i in range(seg):
		progress += curve.get_point_position(i).distance_to(curve.get_point_position(i + 1))
	progress += frac * curve.get_point_position(seg).distance_to(curve.get_point_position(seg + 1))
	return progress


## Place the lock icon at the cap boundary. Its x matches the locked overlay's
## fill boundary (the left edge of the locked region); its y is the bar's flat
## center, except at the central boundary (cap level 5) where the bar dips.
func _position_lock_icon() -> void:
	if not _lock_icon or not _locked_overlay:
		return
	var reachable := _reachable_segments()
	# Once the whole bar is reachable there is nothing left to lock.
	_lock_icon.visible = reachable < _segment_count
	if not _lock_icon.visible:
		return
	# Track the overlay's fill edge straight off its raw rect: the locked region's
	# left edge is reachable/total of the way across the overlay's own size, so
	# the icon follows the overlay wherever it is positioned or however it is sized.
	var fraction := float(reachable) / float(_segment_count)
	var is_center := reachable * 2 == _segment_count
	_lock_icon.position = Vector2(
		_locked_overlay.position.x + fraction * _locked_overlay.size.x,
		lock_icon_dip_y if is_center else lock_icon_y
	)


## Tint the dome number to the gradient color at the current threat position.
## The ticker keeps its own solid sprite color (set in the scene).
func _update_threat_color(ratio: float) -> void:
	if threat_gradient == null or _threat_number == null:
		return
	_threat_number.add_theme_color_override("font_color", threat_gradient.sample(clampf(ratio, 0.0, 1.0)))


func _on_threat_changed(new_value: float) -> void:
	_current_threat = new_value
	_position_ticker()


func _on_threat_level_changed(new_level: int) -> void:
	_update_ticker_level(new_level)


func _on_cap_raised(new_cap: int) -> void:
	_cap_stage = new_cap
	_update_locked_overlay()
	_position_lock_icon()


func _on_cap_reached() -> void:
	if _threat_manager:
		_cap_stage = _threat_manager.threat_level_cap
		_update_locked_overlay()
		_position_lock_icon()


func _update_ticker_level(stage_index: int) -> void:
	if _threat_number:
		_threat_number.text = str(stage_index + 1)
