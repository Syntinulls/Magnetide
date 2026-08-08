extends StormWeatherEffect
class_name AcidRainWeather

## Corrosive rain: a slow constant drain on the player, ship and magnet under a
## green vignette.
##
## The drain is a soft clock that punishes slow wave clears, not a kill timer — the
## player is expected to leave a storm damaged and recover between storms. Healing
## is suppressed for the duration because Player.apply_storm_damage() resets the
## same time-since-damage counter a regular hit does.

@export_range(0.0, 50.0, 0.05, "or_greater") var player_drain_per_second: float = 0.5
@export_range(0.0, 50.0, 0.05, "or_greater") var ship_drain_per_second: float = 0.0
@export_range(0.0, 50.0, 0.05, "or_greater") var magnet_drain_per_second: float = 0.0


func tick(delta: float) -> void:
	_drain(Magnetide.player, player_drain_per_second * delta)
	_drain(Magnetide.ship, ship_drain_per_second * delta)
	_drain(Magnetide.magnet, magnet_drain_per_second * delta)


func _drain(target: Node, amount: float) -> void:
	if amount <= 0.0 or target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_storm_damage"):
		target.apply_storm_damage(amount)
