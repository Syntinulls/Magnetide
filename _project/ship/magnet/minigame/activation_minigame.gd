extends Control
class_name ActivationMinigame

signal minigame_completed(success: bool)
signal marker_hit_success(marker_index: int, total_markers: int)

enum State { INACTIVE, PLACING_MARKERS, PLAYING, SHOWING_RESULT }

@export_group("Bar")
## Padding from the edges of the bar for the cog icon.
@export var bar_padding: float = 20.0

@export_group("Markers")
## Minimum distance between markers as ratio of bar width.
@export var min_marker_spacing_ratio: float = 0.08
## Left boundary of marker placement zone as ratio of bar width (from left edge).
@export var marker_zone_left_ratio: float = 0.15
## Right boundary of marker placement zone as ratio of bar width (from left edge).
@export var marker_zone_right_ratio: float = 0.75
## Time between each marker appearing during placement animation.
@export var marker_appear_delay: float = 0.3

@export_group("Cog Movement")
## Initial speed of cog as ratio of bar width per second.
@export var cog_initial_speed_ratio: float = 0.05
## Maximum speed of cog as ratio of bar width per second.
@export var cog_max_speed_ratio: float = 0.25
## Time to accelerate from initial to max speed.
@export var cog_accel_time: float = 1.5

@export_group("Guide Layout")
## Pixel gap between the top of the bar and the chevron guide.
@export var chevron_bar_gap: float = 6.0
## Pixel gap between the chevron guide and the result icons above it.
@export var result_icon_chevron_gap: float = 8.0

@export_group("Scoring")
## Distance threshold for green (perfect) hit as ratio of bar width.
@export var green_threshold_ratio: float = 0.04
## Distance threshold for yellow (good) hit as ratio of bar width.
@export var yellow_threshold_ratio: float = 0.08
## Number of yellow markers allowed per rarity (COMMON, RARE, EPIC, LEGENDARY).
@export var allowed_yellows: Array[int] = [2, 1, 1, 0]
## Number of markers per rarity (COMMON, RARE, EPIC, LEGENDARY).
@export var markers_per_rarity: Array[int] = [2, 3, 4, 5]

@export_group("Timing")
## Time to show result before closing.
@export var result_display_time: float = 1.5

var _state: State = State.INACTIVE
var _current_rarity: SalvagePile.Rarity = SalvagePile.Rarity.COMMON
var _marker_positions: Array[float] = []  # X positions as ratio of bar width
var _marker_results: Array[int] = []  # 0=pending, 1=green, 2=yellow, 3=red
var _current_marker_index: int = 0
var _cog_position_ratio: float = 1.0  # 1.0 = right edge, 0.0 = left edge
var _cog_speed_ratio: float = 0.0
var _cog_accel_elapsed: float = 0.0
var _markers_placed: int = 0
var _marker_place_timer: float = 0.0
var _result_timer: float = 0.0
var _game_won: bool = false

# UI References
var _bar_sprite: Sprite2D
var _cog_sprite: Sprite2D
var _chevron_sprite: Sprite2D
var _marker_container: Node2D
var _result_icon_container: Node2D
var _yellow_allowance_container: Node2D

# Yellow tracking
var _yellows_used: int = 0

# Camera tracking
var _anchor_marker: Marker2D = null
var _camera: Camera2D = null
var _base_scale: Vector2 = Vector2.ONE

# Textures
var _bar_texture: Texture2D
var _cog_texture: Texture2D
var _marker_texture: Texture2D
var _icon_neutral: Texture2D
var _icon_success: Texture2D
var _icon_failure: Texture2D
var _icon_chevron: Texture2D
var _icon_yellow_empty: Texture2D
var _icon_yellow_filled: Texture2D


func _ready() -> void:
	_bar_texture = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_bar.png")
	_cog_texture = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_cog.png")
	_marker_texture = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_marker_animation.png")
	_icon_neutral = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_icon_neutral.png")
	_icon_success = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_icon_success.png")
	_icon_failure = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_icon_failure.png")
	_icon_chevron = preload("res://_project/ship/magnet/minigame/sprites/magnetgame_icon_chevron.png")
	# Use neutral icon for yellow allowance (modulated to show state)
	_icon_yellow_empty = _icon_neutral
	_icon_yellow_filled = _icon_neutral
	
	# Run even when timescale is slowed
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_ui()
	visible = false
	set_process(false)


func _setup_ui() -> void:
	# Create bar sprite
	_bar_sprite = Sprite2D.new()
	_bar_sprite.texture = _bar_texture
	_bar_sprite.centered = true
	add_child(_bar_sprite)
	
	# Create marker container (behind cog)
	_marker_container = Node2D.new()
	_bar_sprite.add_child(_marker_container)
	
	# Create result icon container (above markers)
	_result_icon_container = Node2D.new()
	_bar_sprite.add_child(_result_icon_container)

	# Create cog sprite
	_cog_sprite = Sprite2D.new()
	_cog_sprite.texture = _cog_texture
	_cog_sprite.centered = true
	_bar_sprite.add_child(_cog_sprite)

	# Create chevron guide sprite above the bar
	_chevron_sprite = Sprite2D.new()
	_chevron_sprite.texture = _icon_chevron
	_chevron_sprite.centered = true
	_chevron_sprite.position.y = _get_chevron_y()
	_bar_sprite.add_child(_chevron_sprite)

	# Create yellow allowance container (below bar, left side)
	_yellow_allowance_container = Node2D.new()
	_bar_sprite.add_child(_yellow_allowance_container)


func start_minigame(rarity: SalvagePile.Rarity) -> void:
	_current_rarity = rarity
	_reset_state()
	_generate_marker_positions()
	_setup_yellow_allowance_icons()
	
	# Apply rarity color to cog
	var rarity_color: Color = SalvagePile.RARITY_COLORS.get(rarity, Color.WHITE)
	_cog_sprite.modulate = rarity_color
	_chevron_sprite.modulate = rarity_color

	visible = true
	set_process(true)
	_state = State.PLACING_MARKERS


func _setup_yellow_allowance_icons() -> void:
	var rarity_index := int(_current_rarity)
	var max_yellows := allowed_yellows[rarity_index] if rarity_index < allowed_yellows.size() else 2
	
	if max_yellows <= 0:
		return
	
	var bar_height := _bar_texture.get_size().y
	var bar_width := _bar_texture.get_size().x
	var icon_spacing := 25.0
	var start_x := -bar_width * 0.5 + 30.0  # Left side of bar
	var y_pos := bar_height * 0.5 + 20.0  # Below bar
	
	for i in range(max_yellows):
		var icon := Sprite2D.new()
		icon.texture = _icon_neutral
		icon.centered = true
		icon.position.x = start_x + i * icon_spacing
		icon.position.y = y_pos
		icon.modulate = Color.WHITE  # White by default
		_yellow_allowance_container.add_child(icon)


func _reset_state() -> void:
	_marker_positions.clear()
	_marker_results.clear()
	_current_marker_index = 0
	_cog_position_ratio = 1.0
	_cog_speed_ratio = cog_initial_speed_ratio
	_cog_accel_elapsed = 0.0
	_markers_placed = 0
	_marker_place_timer = 0.0
	_result_timer = 0.0
	_game_won = false
	
	# Clear existing markers and icons
	for child in _marker_container.get_children():
		child.queue_free()
	for child in _result_icon_container.get_children():
		child.queue_free()
	for child in _yellow_allowance_container.get_children():
		child.queue_free()
	
	_yellows_used = 0
	
	# Reset bar modulate
	_bar_sprite.modulate = Color.WHITE
	
	# Position cog at right edge
	_update_cog_position()


func _generate_marker_positions() -> void:
	var rarity_index := int(_current_rarity)
	var marker_count := markers_per_rarity[rarity_index] if rarity_index < markers_per_rarity.size() else 2
	
	var zone_start := marker_zone_left_ratio
	var zone_end := marker_zone_right_ratio
	
	# Generate positions with minimum spacing
	var attempts := 0
	while _marker_positions.size() < marker_count and attempts < 100:
		var pos := randf_range(zone_start, zone_end)
		var valid := true
		
		for existing_pos in _marker_positions:
			if absf(pos - existing_pos) < min_marker_spacing_ratio:
				valid = false
				break
		
		if valid:
			_marker_positions.append(pos)
		attempts += 1
	
	# Sort markers from right to left (cog travels left)
	_marker_positions.sort()
	_marker_positions.reverse()
	
	# Initialize results as pending
	for i in range(_marker_positions.size()):
		_marker_results.append(0)


func _process(delta: float) -> void:
	# Update position and scale based on camera
	_update_camera_tracking()
	
	# Compensate marker animation speed for timescale
	_update_marker_animation_speed()
	
	match _state:
		State.PLACING_MARKERS:
			_process_placing_markers(delta)
		State.PLAYING:
			_process_playing(delta)
		State.SHOWING_RESULT:
			_process_showing_result(delta)


## Set the world-space anchor marker for camera tracking.
func set_anchor_marker(marker: Marker2D) -> void:
	_anchor_marker = marker


func _update_camera_tracking() -> void:
	# Get camera if not cached
	if not _camera:
		_camera = get_viewport().get_camera_2d()
	
	if not _anchor_marker or not _camera:
		return
	
	# Get the marker's screen position using canvas transform
	var screen_pos := _anchor_marker.get_global_transform_with_canvas().origin
	position = screen_pos
	
	# Scale with camera zoom (zoom > 1 means zoomed in, so UI should be larger)
	var zoom := _camera.zoom
	scale = _base_scale * zoom


func _update_marker_animation_speed() -> void:
	# Set speed_scale on all marker AnimatedSprite2D to compensate for Engine.time_scale
	var speed_multiplier := 1.0 / Engine.time_scale if Engine.time_scale > 0.0 else 1.0
	for marker in _marker_container.get_children():
		if marker is AnimatedSprite2D:
			marker.speed_scale = speed_multiplier


func _process_placing_markers(delta: float) -> void:
	# Compensate for Engine.time_scale to run at real-time speed
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_marker_place_timer += real_delta
	
	if _markers_placed < _marker_positions.size():
		if _marker_place_timer >= marker_appear_delay:
			_marker_place_timer = 0.0
			_place_marker(_markers_placed)
			_markers_placed += 1
	else:
		# All markers placed, start playing
		_state = State.PLAYING


func _place_marker(index: int) -> void:
	var bar_width := _bar_texture.get_size().x
	var pos_ratio := _marker_positions[index]
	
	# Create animated marker sprite (12 frames, 1 row, 12fps)
	var marker := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	# SpriteFrames already has "default" animation, just configure it
	frames.set_animation_speed("default", 12.0)
	frames.set_animation_loop("default", true)
	
	# Split the spritesheet into 12 frames
	var sheet_width := _marker_texture.get_width()
	@warning_ignore("integer_division")
	var frame_width := sheet_width / 12
	var frame_height := _marker_texture.get_height()
	
	for i in range(12):
		var atlas := AtlasTexture.new()
		atlas.atlas = _marker_texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("default", atlas)
	
	marker.sprite_frames = frames
	marker.centered = true
	marker.position.x = (pos_ratio - 0.5) * bar_width
	marker.position.y = 0.0
	marker.process_mode = Node.PROCESS_MODE_ALWAYS  # Ignore timescale
	marker.play("default")
	_marker_container.add_child(marker)
	
	# Create result icon above marker (same x, above in y)
	var icon := Sprite2D.new()
	icon.texture = _icon_neutral
	icon.centered = true
	icon.position.x = marker.position.x
	icon.position.y = _get_result_icon_y()
	icon.modulate = Color.WHITE  # Neutral - no modulation
	_result_icon_container.add_child(icon)


func _process_playing(delta: float) -> void:
	# Compensate for Engine.time_scale to run at real-time speed
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	
	# Accelerate cog
	if _cog_accel_elapsed < cog_accel_time:
		_cog_accel_elapsed += real_delta
		var t := clampf(_cog_accel_elapsed / cog_accel_time, 0.0, 1.0)
		_cog_speed_ratio = lerpf(cog_initial_speed_ratio, cog_max_speed_ratio, t)
	
	# Move cog left
	_cog_position_ratio -= _cog_speed_ratio * real_delta
	_update_cog_position()
	
	# Auto-fail markers that the cog has passed without player input
	_check_passed_markers()
	
	# Check if cog reached left edge
	if _cog_position_ratio <= 0.0:
		_cog_position_ratio = 0.0
		_update_cog_position()
		_finish_game()


func _check_passed_markers() -> void:
	# Check if cog has passed the current marker beyond the yellow threshold
	# If so, auto-fail it to red since it's now impossible to hit
	# Cog moves left (decreasing ratio), markers sorted right-to-left
	# Yellow zone is from (marker_pos + yellow_threshold) to (marker_pos - yellow_threshold)
	# When cog passes left of (marker_pos - yellow_threshold), it's impossible to hit
	while _current_marker_index < _marker_positions.size():
		var marker_pos := _marker_positions[_current_marker_index]
		var left_edge := marker_pos - yellow_threshold_ratio
		if _cog_position_ratio < left_edge:
			_auto_fail_marker(_current_marker_index)
			_current_marker_index += 1
		else:
			break


func _auto_fail_marker(index: int) -> void:
	# Mark as red (missed)
	_marker_results[index] = 3
	
	# Update marker color
	var markers := _marker_container.get_children()
	if index < markers.size():
		var marker := markers[index] as CanvasItem
		if marker:
			marker.modulate = Color.RED
	
	# Update result icon
	var icons := _result_icon_container.get_children()
	if index < icons.size():
		var icon := icons[index] as Sprite2D
		if icon:
			icon.texture = _icon_failure
			icon.modulate = Color.RED


func _use_yellow_allowance() -> void:
	# Light up the next yellow allowance icon
	var icons := _yellow_allowance_container.get_children()
	if _yellows_used < icons.size():
		var icon := icons[_yellows_used] as Sprite2D
		if icon:
			icon.modulate = Color.YELLOW  # Light up yellow
	_yellows_used += 1


func _update_cog_position() -> void:
	var bar_width := _bar_texture.get_size().x
	var usable_width := bar_width - bar_padding * 2.0
	var x := (bar_padding + usable_width * _cog_position_ratio) - bar_width * 0.5
	_cog_sprite.position.x = x
	_chevron_sprite.position.x = x


func _get_chevron_y() -> float:
	return _get_bar_top_y() - _get_texture_half_height(_icon_chevron) - chevron_bar_gap


func _get_result_icon_y() -> float:
	return _get_chevron_y() - _get_texture_half_height(_icon_chevron) - _get_texture_half_height(_icon_neutral) - result_icon_chevron_gap


func _get_bar_top_y() -> float:
	return -_bar_texture.get_size().y * 0.5


func _get_texture_half_height(texture: Texture2D) -> float:
	return texture.get_size().y * 0.5 if texture else 0.0


func _input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	
	if event.is_action_pressed("interact"):
		_check_marker_hit()


func _check_marker_hit() -> void:
	if _current_marker_index >= _marker_positions.size():
		return
	
	var marker_pos := _marker_positions[_current_marker_index]
	var distance := absf(_cog_position_ratio - marker_pos)
	
	var result: int
	var color: Color
	
	if distance <= green_threshold_ratio:
		result = 1  # Green
		color = Color.GREEN
		marker_hit_success.emit(_current_marker_index, _marker_positions.size())
	elif distance <= yellow_threshold_ratio:
		result = 2  # Yellow
		color = Color.YELLOW
		marker_hit_success.emit(_current_marker_index, _marker_positions.size())
		_use_yellow_allowance()
	else:
		# Outside yellow zone - red (miss)
		result = 3  # Red
		color = Color.RED
	
	_marker_results[_current_marker_index] = result
	
	# Update marker color (AnimatedSprite2D)
	var markers := _marker_container.get_children()
	if _current_marker_index < markers.size():
		var marker := markers[_current_marker_index] as CanvasItem
		if marker:
			marker.modulate = color
	
	# Update result icon with correct texture and color modulation
	var icons := _result_icon_container.get_children()
	if _current_marker_index < icons.size():
		var icon := icons[_current_marker_index] as Sprite2D
		if icon:
			if result == 1:  # Green
				icon.texture = _icon_success
				icon.modulate = Color.GREEN
			elif result == 2:  # Yellow
				icon.texture = _icon_success
				icon.modulate = Color.YELLOW
			else:  # Red
				icon.texture = _icon_failure
				icon.modulate = Color.RED
	
	_current_marker_index += 1


func _finish_game() -> void:
	# Calculate win/lose
	var rarity_index := int(_current_rarity)
	var max_yellows := allowed_yellows[rarity_index] if rarity_index < allowed_yellows.size() else 2
	
	var yellow_count := 0
	var red_count := 0
	
	for result in _marker_results:
		if result == 2:
			yellow_count += 1
		elif result == 3 or result == 0:  # Red or not hit
			red_count += 1
	
	_game_won = red_count == 0 and yellow_count <= max_yellows
	
	# Status icons already convey the result, no bar modulation needed
	_state = State.SHOWING_RESULT
	_result_timer = 0.0


func _process_showing_result(delta: float) -> void:
	# Compensate for Engine.time_scale to run at real-time speed
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_result_timer += real_delta
	if _result_timer >= result_display_time:
		_end_minigame()


func _end_minigame() -> void:
	visible = false
	set_process(false)
	_state = State.INACTIVE
	minigame_completed.emit(_game_won)


func cancel_minigame() -> void:
	visible = false
	set_process(false)
	_state = State.INACTIVE
	_reset_state()
