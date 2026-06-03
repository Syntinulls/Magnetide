extends Node2D
class_name SalvageSpawner

@export_group("Spawn Area")
## The horizontal position ratio where salvage piles spawn (right side of screen).
@export var spawn_x_ratio: float = 1.1
## The horizontal position ratio where salvage piles are despawned (left side of screen).
@export var despawn_x_ratio: float = -0.052

@export_group("Spawning")
## When true the spawner uses its own timer to create piles automatically.
## Set to false when spawning is driven externally (e.g. by MagnetMinigame).
@export var auto_spawn: bool = true
## Minimum time between spawns in seconds.
@export var spawn_interval_min: float = 20.0
## Maximum time between spawns in seconds.
@export var spawn_interval_max: float = 30.0

@export_group("Rarities")
@export_subgroup("Common")
@export var common_data: SalvagePileData = null
@export var common_weight: float = 70.0
@export_subgroup("Rare")
@export var rare_data: SalvagePileData = null
@export var rare_weight: float = 20.0
@export_subgroup("Epic")
@export var epic_data: SalvagePileData = null
@export var epic_weight: float = 8.0
@export_subgroup("Legendary")
@export var legendary_data: SalvagePileData = null
@export var legendary_weight: float = 2.0
@export_subgroup("Artifact")
@export var artifact_data: SalvagePileData = null
@export var artifact_weight: float = 1.0

@export_group("Salvage Properties")
## Minimum height of salvage pile as ratio of viewport height.
@export var pile_height_ratio_min: float = 0.125
## Maximum height of salvage pile as ratio of viewport height.
@export var pile_height_ratio_max: float = 0.15
## Artifact piles are smaller than normal piles.
@export var artifact_pile_height_multiplier: float = 0.62

var _salvage_pile_scene: PackedScene
var _spawn_timer: Timer
var _current_pile: SalvagePile = null
var _level: Node = null
var _threat_manager: ThreatManager = null
var _viewport_anchor: ViewportAnchor = null


func _get_pile_data_for_rarity(rarity: SalvagePile.Rarity) -> SalvagePileData:
	match rarity:
		SalvagePile.Rarity.COMMON:
			return common_data
		SalvagePile.Rarity.RARE:
			return rare_data
		SalvagePile.Rarity.EPIC:
			return epic_data
		SalvagePile.Rarity.LEGENDARY:
			return legendary_data
		SalvagePile.Rarity.ARTIFACT:
			return artifact_data
	return common_data


func _ready() -> void:
	_salvage_pile_scene = preload("res://_project/level/salvage/pile/salvage_pile.tscn")

	_level = get_parent()
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor
	_resolve_threat_manager()

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	if auto_spawn:
		_start_spawn_timer()


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _get_screen_width() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.x
	return get_viewport().get_visible_rect().size.x


func _get_screen_height() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.y
	return get_viewport().get_visible_rect().size.y


func _get_spawn_x() -> float:
	return _get_screen_width() * spawn_x_ratio


func _get_despawn_x() -> float:
	return _get_screen_width() * despawn_x_ratio


func _get_surface_y() -> float:
	if _level and "surface_y" in _level:
		return _level.surface_y
	return get_viewport().get_visible_rect().size.y * 0.463


func _process(_delta: float) -> void:
	var level_speed := _get_level_speed()

	if level_speed <= 0.0:
		if not _spawn_timer.paused:
			_spawn_timer.paused = true
	else:
		if _spawn_timer.paused:
			_spawn_timer.paused = false

	if _current_pile and _current_pile.is_active:
		if _current_pile.global_position.x < _get_despawn_x():
			_on_pile_removed()


func _start_spawn_timer() -> void:
	var interval := randf_range(spawn_interval_min, spawn_interval_max)
	_spawn_timer.start(interval)


func _on_spawn_timer_timeout() -> void:
	_spawn_salvage()


func _on_pile_removed() -> void:
	if _current_pile:
		_current_pile.deactivate()
		_current_pile.queue_free()
		_current_pile = null
	if auto_spawn:
		_start_spawn_timer()


func on_pile_acquired() -> void:
	_on_pile_removed()


func _pick_rarity() -> SalvagePile.Rarity:
	var weights := _get_active_rarity_weights()
	var rarity_entries: Array = [
		SalvagePile.Rarity.COMMON,
		SalvagePile.Rarity.RARE,
		SalvagePile.Rarity.EPIC,
		SalvagePile.Rarity.LEGENDARY,
		SalvagePile.Rarity.ARTIFACT,
	]
	var selected: Variant = WeightedRandom.roll_weighted(
		rarity_entries,
		Callable(self, "_get_rarity_roll_weight").bind(weights)
	)
	return int(selected) if selected != null else SalvagePile.Rarity.COMMON


func _get_rarity_roll_weight(rarity: int, weights: Dictionary) -> float:
	if _get_pile_data_for_rarity(rarity) == null:
		return 0.0
	return float(weights.get(rarity, 0.0))


func _get_active_rarity_weights() -> Dictionary:
	if not _threat_manager:
		_resolve_threat_manager()
	if _threat_manager:
		return _threat_manager.get_pile_rarity_weights()
	return {
		SalvagePile.Rarity.COMMON: common_weight,
		SalvagePile.Rarity.RARE: rare_weight,
		SalvagePile.Rarity.EPIC: epic_weight,
		SalvagePile.Rarity.LEGENDARY: legendary_weight,
		SalvagePile.Rarity.ARTIFACT: artifact_weight,
	}


func _resolve_threat_manager() -> void:
	if _threat_manager:
		return
	if _level:
		_threat_manager = _level.get_node_or_null("ThreatManager") as ThreatManager


func _spawn_salvage() -> void:
	if _current_pile and _current_pile.is_active:
		return

	_current_pile = _salvage_pile_scene.instantiate() as SalvagePile
	add_child(_current_pile)

	var spawn_y := _get_screen_height()  # Bottom of screen
	var target_height := _get_screen_height() * randf_range(pile_height_ratio_min, pile_height_ratio_max)
	var rot := randf_range(0.0, TAU)
	var rarity := _pick_rarity()
	if rarity == SalvagePile.Rarity.ARTIFACT:
		target_height *= artifact_pile_height_multiplier

	_current_pile.pile_data = _get_pile_data_for_rarity(rarity)
	_current_pile.activate(rarity, Vector2(_get_spawn_x(), spawn_y), _level, target_height, rot)


## Spawn a salvage pile on demand (used by MagnetMinigame).
## If custom_spawn_x >= 0, the pile spawns at that X position instead of the
## default off-screen location.  Returns the new SalvagePile instance.
func spawn_on_demand(custom_spawn_x: float = -1.0) -> SalvagePile:
	return spawn_on_demand_with_rarity(custom_spawn_x, _pick_rarity())


## Spawn a salvage pile on demand with a specific rarity.
## If custom_spawn_x >= 0, the pile spawns at that X position instead of the
## default off-screen location.  Returns the new SalvagePile instance.
func spawn_on_demand_with_rarity(custom_spawn_x: float, rarity: SalvagePile.Rarity) -> SalvagePile:
	if _current_pile and _current_pile.is_active:
		_current_pile.deactivate()
		_current_pile.queue_free()
		_current_pile = null

	_current_pile = _salvage_pile_scene.instantiate() as SalvagePile
	add_child(_current_pile)

	var spawn_x := custom_spawn_x if custom_spawn_x >= 0.0 else _get_spawn_x()
	var spawn_y := _get_screen_height()  # Bottom of screen
	var target_height := _get_screen_height() * randf_range(pile_height_ratio_min, pile_height_ratio_max)
	var rot := randf_range(0.0, TAU)
	if rarity == SalvagePile.Rarity.ARTIFACT:
		target_height *= artifact_pile_height_multiplier

	_current_pile.pile_data = _get_pile_data_for_rarity(rarity)
	_current_pile.activate(rarity, Vector2(spawn_x, spawn_y), _level, target_height, rot)
	return _current_pile
