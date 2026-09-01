extends LeverModifierBehavior
class_name InvertModifierBehavior

## "Invert!" (positive): the standard board with every cluster turned inside out
## -- a wide yellow flanked by two narrow greens, instead of a narrow green
## flanked by two wide yellows. Only the positions swap; each colour keeps the
## width it is authored at, so the perfect windows sit at the cluster edges and
## the forgiving middle is where the green used to be. Zone count, threat
## scaling, lights, and the win condition are all unchanged.


func build_board(minigame: LeverMinigame, threat_level: int) -> void:
	var cluster_count := minigame.scale_for_threat(threat_level, minigame.zones_min, minigame.zones_max)
	var width_scale := minigame.get_zone_width_scale(threat_level)
	var green_width := minigame.green_width_ratio * width_scale
	var half_yellow := minigame.yellow_width_ratio * width_scale * 0.5
	var centers := minigame.generate_centers(
		cluster_count, minigame.min_green_center_spacing_ratio, minigame.green_edge_margin_ratio
	)
	for center in centers:
		var right_edge: float = center + half_yellow + green_width
		var index := minigame.add_objective(center, right_edge)
		minigame.append_zone(
			LeverMinigame.ZoneType.GREEN, center - half_yellow - green_width, center - half_yellow, index
		)
		minigame.append_zone(
			LeverMinigame.ZoneType.YELLOW, center - half_yellow, center + half_yellow, index
		)
		minigame.append_zone(
			LeverMinigame.ZoneType.GREEN, center + half_yellow, right_edge, index
		)
