extends RefCounted
class_name WeightedRandom


static func roll_weighted(entries: Array, get_weight: Callable, rng: RandomNumberGenerator = null) -> Variant:
	var valid_entries := _get_valid_entries(entries, get_weight)
	var total_weight := get_total_weight(valid_entries, get_weight)
	if total_weight <= 0.0:
		push_warning("WeightedRandom: Cannot roll because total valid weight is 0.")
		return null

	var roll := rng.randf() * total_weight if rng != null else randf() * total_weight
	for entry in valid_entries:
		roll -= float(get_weight.call(entry))
		if roll <= 0.0:
			return entry

	return valid_entries[valid_entries.size() - 1]


static func get_total_weight(entries: Array, get_weight: Callable) -> float:
	var total := 0.0
	for entry in entries:
		var weight := float(get_weight.call(entry))
		if _is_valid_weight(weight):
			total += weight
	return total


static func get_probability(weight: float, total_weight: float) -> float:
	if not _is_valid_weight(weight) or total_weight <= 0.0:
		return 0.0
	return weight / total_weight


static func _get_valid_entries(entries: Array, get_weight: Callable) -> Array:
	var valid_entries: Array = []
	for entry in entries:
		var weight := float(get_weight.call(entry))
		if _is_valid_weight(weight):
			valid_entries.append(entry)
		elif weight == 0.0:
			continue
		else:
			push_warning("WeightedRandom: Ignoring invalid weight %s." % weight)
	return valid_entries


static func _is_valid_weight(weight: float) -> bool:
	return weight > 0.0 and not is_nan(weight) and not is_inf(weight)
