extends Node
class_name StormController

## Owns the acid storm. When ThreatManager's cap countdown expires (storm_arrived)
## it continually drains the player, ship, and magnet at a slow constant rate and
## shows a green acid vignette, until the player advances (cap_raised) or the run
## ends. Player/ship reaching zero ends the run via their destroyed signals
## (routed by RunController); the magnet is drained too but does not end the run.

@export_group("Drain Per Second")
@export var player_drain_per_second: float = 5.0
@export var ship_drain_per_second: float = 8.0
@export var magnet_drain_per_second: float = 8.0

@export_group("Vignette")
@export var vignette_color: Color = Color(0.22, 0.85, 0.18, 0.42)
@export var vignette_fade_seconds: float = 1.0
## CanvasLayer level for the vignette overlay. Above the world (layer 0) but
## below the game UI (layer 10), so it covers gameplay but not the HUD.
@export var vignette_canvas_layer: int = 5

var _threat_manager: ThreatManager = null
var _storm_active: bool = false
var _vignette_rect: TextureRect = null
var _vignette_tween: Tween = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_threat_manager = get_node_or_null("../ThreatManager") as ThreatManager
	if _threat_manager:
		_threat_manager.storm_arrived.connect(_on_storm_arrived)
		_threat_manager.cap_raised.connect(_on_cap_raised)
	_build_vignette()
	set_process(false)


func _process(delta: float) -> void:
	if not _storm_active:
		return
	_apply_drain(delta)


func _apply_drain(delta: float) -> void:
	var player := Magnetide.player
	if player and player.has_method("apply_storm_damage"):
		player.apply_storm_damage(player_drain_per_second * delta)
	var ship := Magnetide.ship
	if ship and ship.has_method("apply_storm_damage"):
		ship.apply_storm_damage(ship_drain_per_second * delta)
	var magnet := Magnetide.magnet
	if magnet and magnet.has_method("apply_storm_damage"):
		magnet.apply_storm_damage(magnet_drain_per_second * delta)


func _on_storm_arrived() -> void:
	if _storm_active:
		return
	_storm_active = true
	set_process(true)
	_fade_vignette(1.0)


func _on_cap_raised(_new_cap: int) -> void:
	_stop_storm()


func _stop_storm() -> void:
	if not _storm_active:
		return
	_storm_active = false
	set_process(false)
	_fade_vignette(0.0)


func stop_for_run_end() -> void:
	_stop_storm()


func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(vignette_color.r, vignette_color.g, vignette_color.b, 0.0))
	gradient.add_point(0.45, Color(vignette_color.r, vignette_color.g, vignette_color.b, 0.0))
	gradient.set_offset(gradient.get_point_count() - 1, 1.0)
	gradient.set_color(gradient.get_point_count() - 1, vignette_color)

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 512
	texture.height = 512

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "StormVignetteLayer"
	canvas_layer.layer = vignette_canvas_layer
	add_child(canvas_layer)

	_vignette_rect = TextureRect.new()
	_vignette_rect.name = "StormVignette"
	_vignette_rect.texture = texture
	_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.modulate = Color(1, 1, 1, 0)
	canvas_layer.add_child(_vignette_rect)


func _fade_vignette(target_alpha: float) -> void:
	if _vignette_rect == null:
		return
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette_rect, "modulate:a", target_alpha, vignette_fade_seconds)
