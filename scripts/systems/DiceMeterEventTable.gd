extends Resource
class_name DiceMeterEventTable

@export var events: Array[DiceMeterEventData] = []

func get_candidates_for_roll(roll: int) -> Array[DiceMeterEventData]:
	var out: Array[DiceMeterEventData] = []
	for e: DiceMeterEventData in events:
		if e == null:
			continue
		if not e.is_valid():
			continue
		if e.matches_roll(roll):
			out.append(e)
	return out

func pick_event_for_roll(rng: RandomNumberGenerator, roll: int) -> DiceMeterEventData:
	var candidates: Array[DiceMeterEventData] = get_candidates_for_roll(roll)
	if candidates.is_empty():
		return null

	var total_weight: float = 0.0
	for e: DiceMeterEventData in candidates:
		total_weight += maxf(e.weight, 0.0)

	if total_weight <= 0.0:
		return candidates[0]

	var pick: float = rng.randf_range(0.0, total_weight)
	var run: float = 0.0
	for e2: DiceMeterEventData in candidates:
		run += maxf(e2.weight, 0.0)
		if pick <= run:
			return e2

	return candidates[candidates.size() - 1]
