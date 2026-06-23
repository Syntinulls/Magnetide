extends InteractionHitbox
class_name MagnetLever

signal lever_flipped()
signal lever_flipped_back()
## Emitted when the player confirms advancing to the next threat level (second
## interact press while the "CONTINUE RUN?" prompt is shown).
signal advance_confirmed()

## Start rotation in radians (45 degrees clockwise).
@export var start_rotation: float = 0.785398
## End rotation in radians (45 degrees counter-clockwise).
@export var end_rotation: float = -0.785398
## Duration of rotation tween in seconds.
@export var rotation_tween_duration: float = 0.15

var _is_available: bool = false
var _is_flipped: bool = false
var _current_rotation_progress: float = 0.0  # 0.0 = start, 1.0 = end
var _target_rotation_progress: float = 0.0
var _is_tweening: bool = false
var _tween_elapsed: float = 0.0
var _tween_start_progress: float = 0.0
# Advance ("continue to next threat") mode, active while the threat cap is reached.
var _advance_mode: bool = false
var _advance_confirm_pending: bool = false

const OUTLINE_SHADER: Shader = preload("res://_project/shaders/outline.gdshader")

var _outline_material: ShaderMaterial = null

@onready var _handle_pivot: Node2D = $HandlePivot
@onready var _handle_sprite: Sprite2D = $HandlePivot/Handle
@onready var _base_sprite: Sprite2D = $Base
@onready var _continue_prompt: Label = $ContinuePrompt


func _ready() -> void:
	super._ready()
	player_exited.connect(_on_player_exited)
	set_available(false)
	reset_rotation()
	# Lever is always visible
	set_handle_visible(true)
	if _continue_prompt:
		_continue_prompt.visible = false
	_setup_highlight()


func _setup_highlight() -> void:
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_enabled", false)
	_outline_material.set_shader_parameter("outline_width", 3.0)
	# Share one material so the handle and base outline together.
	if _handle_sprite:
		_handle_sprite.material = _outline_material
	if _base_sprite:
		_base_sprite.material = _outline_material


func _set_highlight(active: bool) -> void:
	if _outline_material:
		_outline_material.set_shader_parameter("outline_enabled", active)


func _process(delta: float) -> void:
	# Handle tweening with timescale compensation
	if _is_tweening:
		_process_rotation_tween(delta)

	_update_prompt_and_highlight()

	if _advance_mode:
		_process_advance_input()
		return

	if not _is_available or not is_player_in_range:
		return

	if Input.is_action_just_pressed("interact"):
		if not _is_flipped:
			_is_flipped = true
			lever_flipped.emit()
			set_available(false)
		else:
			# Player flips lever back (manual abort during looting)
			_is_flipped = false
			flip_back_with_tween()
			lever_flipped_back.emit()
			set_available(false)


## Switch the lever between normal looting use and "continue to next threat"
## advance use. Entered when the threat cap is reached, reverted after advancing.
func set_advance_mode(enabled: bool) -> void:
	_advance_mode = enabled
	if not enabled:
		_advance_confirm_pending = false
		_set_continue_prompt_visible(false)


## Two-press confirmation: first interact shows "CONTINUE RUN?", second confirms.
func _process_advance_input() -> void:
	if not is_player_in_range:
		if _advance_confirm_pending:
			_advance_confirm_pending = false
			_set_continue_prompt_visible(false)
		return

	if not Input.is_action_just_pressed("interact"):
		return

	if not _advance_confirm_pending:
		_advance_confirm_pending = true
		_set_continue_prompt_visible(true)
	else:
		_advance_confirm_pending = false
		_set_continue_prompt_visible(false)
		# Consume advance mode so the cutscene isn't re-triggered.
		_advance_mode = false
		advance_confirmed.emit()


func _set_continue_prompt_visible(value: bool) -> void:
	if _continue_prompt:
		_continue_prompt.visible = value


## Highlight the lever and register its control prompt while it can be used.
## The prompt reflects the lever's current function ([E] BRAKE vs [E] CONTINUE).
func _update_prompt_and_highlight() -> void:
	var usable := is_player_in_range and (_advance_mode or _is_available)
	_set_highlight(usable)

	var prompts := Magnetide.control_prompts
	if prompts == null:
		return
	if usable:
		var action := "BRAKE"
		if _advance_mode:
			action = "CONTINUE"
		elif Magnetide.magnet and Magnetide.magnet.is_active:
			# Magnet is looting; flipping the lever departs the salvage pile.
			action = "DEPART"
		prompts.set_prompt(&"lever", "E", action, false, 5)
	else:
		prompts.clear_prompt(&"lever")


func _process_rotation_tween(delta: float) -> void:
	# Compensate for timescale to run at real-time speed
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_tween_elapsed += real_delta
	
	var t := clampf(_tween_elapsed / rotation_tween_duration, 0.0, 1.0)
	# Ease out quad for smooth deceleration
	t = 1.0 - (1.0 - t) * (1.0 - t)
	
	_current_rotation_progress = lerpf(_tween_start_progress, _target_rotation_progress, t)
	_apply_rotation()
	
	if _tween_elapsed >= rotation_tween_duration:
		_is_tweening = false
		_current_rotation_progress = _target_rotation_progress


func set_available(available: bool) -> void:
	_is_available = available
	# Don't change visibility here - let set_handle_visible control it separately


## Set handle visibility (used during minigame to keep lever visible).
func set_handle_visible(handle_visible: bool) -> void:
	if _handle_pivot:
		_handle_pivot.visible = handle_visible


func _on_player_exited() -> void:
	# Leaving range resets the advance confirmation (requires two presses again).
	if _advance_confirm_pending:
		_advance_confirm_pending = false
		_set_continue_prompt_visible(false)


## Reset lever to start rotation position (immediate, no tween).
func reset_rotation() -> void:
	_current_rotation_progress = 0.0
	_target_rotation_progress = 0.0
	_is_flipped = false
	_is_tweening = false
	_apply_rotation()


## Animate lever back to start position (0.0 progress) with tween.
func flip_back_with_tween() -> void:
	_tween_start_progress = _current_rotation_progress
	_target_rotation_progress = 0.0
	_tween_elapsed = 0.0
	_is_tweening = true
	_is_flipped = false


## Progress lever rotation by a given amount (0.0 to 1.0 range) with tweening.
## Returns the new target progress value.
func progress_rotation(amount: float) -> float:
	_tween_start_progress = _current_rotation_progress
	_target_rotation_progress = clampf(_target_rotation_progress + amount, 0.0, 1.0)
	_tween_elapsed = 0.0
	_is_tweening = true
	return _target_rotation_progress


## Set lever rotation progress directly (0.0 = start, 1.0 = end).
func set_rotation_progress(progress: float) -> void:
	_current_rotation_progress = clampf(progress, 0.0, 1.0)
	_apply_rotation()


## Set lever to fully flipped state (for entering looting mode).
func set_flipped(flipped: bool) -> void:
	_is_flipped = flipped
	if flipped:
		_current_rotation_progress = 1.0
		_target_rotation_progress = 1.0
	else:
		_current_rotation_progress = 0.0
		_target_rotation_progress = 0.0
	_is_tweening = false
	_apply_rotation()


func _apply_rotation() -> void:
	if _handle_pivot:
		_handle_pivot.rotation = lerpf(start_rotation, end_rotation, _current_rotation_progress)
