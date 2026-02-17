extends Resource
class_name BackgroundBand

@export_group("Coverage")
## The Y position ratio where this band starts (0.0 = top, 1.0 = bottom).
@export var y_min: float = 0.185
## The Y position ratio where this band ends (0.0 = top, 1.0 = bottom).
@export var y_max: float = 0.37

@export_group("Scale")
## Minimum scale for sprites in this band.
@export var scale_min: float = 0.2
## Maximum scale for sprites in this band.
@export var scale_max: float = 0.4

@export_group("Appearance")
## Alpha/opacity for sprites in this band (0.0 - 1.0).
@export var alpha: float = 1.0
## Minimum brown tint hue.
@export var brown_hue_min: float = 0.05
## Maximum brown tint hue.
@export var brown_hue_max: float = 0.12
## Minimum saturation for brown tints.
@export var brown_sat_min: float = 0.3
## Maximum saturation for brown tints.
@export var brown_sat_max: float = 0.6
## Minimum value/brightness for brown tints.
@export var brown_val_min: float = 0.2
## Maximum value/brightness for brown tints.
@export var brown_val_max: float = 0.5

@export_group("Speed")
## Minimum speed multiplier at top of band (y_min).
@export var speed_ratio_min: float = 0.3
## Maximum speed multiplier at bottom of band (y_max).
@export var speed_ratio_max: float = 0.5

@export_group("Pool")
## Number of sprites in this band's object pool.
@export var sprite_count: int = 100
## Maximum horizontal spacing between sprites when recycling.
@export var max_spacing: float = 50.0


func random_color() -> Color:
	var h := randf_range(brown_hue_min, brown_hue_max)
	var s := randf_range(brown_sat_min, brown_sat_max)
	var v := randf_range(brown_val_min, brown_val_max)
	return Color.from_hsv(h, s, v, alpha)
