extends Resource
class_name StormWeatherEffect

## Base for a storm's environment effect. Modeled on EnemyBehavior: an authored
## resource the storm director drives through setup/tick/teardown, so a new kind of
## weather is a new subclass plus a .tres, not a change to StormController.
##
## Effects reach run actors through the Magnetide autoload (player, ship, magnet,
## level) rather than being handed a context, and declare their screen tint here so
## the director can drive its authored vignette node without knowing what the
## weather is.

## Screen vignette color while this weather is active. Alpha 0 means no vignette.
@export var vignette_color: Color = Color(0, 0, 0, 0)
@export_range(0.0, 10.0, 0.05, "or_greater") var vignette_fade_seconds: float = 1.0


func setup() -> void:
	pass


func teardown() -> void:
	pass


func tick(_delta: float) -> void:
	pass
