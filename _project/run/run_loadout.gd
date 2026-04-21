extends Resource
class_name RunLoadout

@export_group("Ship")
@export var ship_storage_area_size: Vector2 = Vector2(400, 250)
@export var ship_storage_area_position: Vector2 = Vector2(0, -95)
@export var ship_storage_marker_height: float = 24.0
@export var ship_storage_max_weight: float = 100.0
@export var ship_max_health: float = 250.0

@export_group("Magnet")
@export var magnet_pull_frequency: float = 2.5
@export var magnet_pull_batch_size: int = 1
@export var magnet_hold_capacity: int = 10
@export var magnet_pull_base_speed: float = 200.0
@export var magnet_pull_max_speed: float = 1500.0
@export var magnet_pull_ramp_time: float = 0.6
@export var magnet_surface_slow_speed: float = 15.0
@export var magnet_surface_dwell_time: float = 1.2
@export var magnet_breakaway_ramp_time: float = 0.3
@export var magnet_breakaway_max_speed: float = 2000.0
@export var magnet_threat_penalty: float = 10.0
@export var magnet_width: float = 264.0
@export var magnet_max_health: float = 150.0

@export_group("Player")
@export var player_speed: float = 400.0
@export var player_jump_velocity: float = -600.0
@export var player_gravity: float = 1600.0
@export var player_max_health: float = 100.0
@export var player_equipment: Array[EquipmentData] = []
@export var player_selected_equipment_index: int = 0


func apply_to_level(level: Node) -> void:
	if level == null:
		return

	var ship := level.get_node_or_null("Ship") as Ship
	if ship:
		ship.apply_run_loadout(self)

	var magnet := ship.get_node_or_null("Magnet") as Magnet if ship else null
	if magnet:
		magnet.apply_run_loadout(self)

	var player := ship.get_node_or_null("Player") as Player if ship else null
	if player:
		player.apply_run_loadout(self)
