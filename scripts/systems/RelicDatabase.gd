extends Node
class_name RelicDatabase

@export var relics: Array[RelicData] = []

# Rarity drop rates
@export var common_weight: float = 60.0
@export var rare_weight: float = 30.0
@export var epic_weight: float = 10.0

# Rare bonus cap (from RunState.rare_relic_bonus or run-scoped bonus)
@export var rare_bonus_cap: float = 0.50

# Band bias multipliers (preferred / adjacent / off)
@export var band_pref_mult: float = 1.75
@export var band_adj_mult: float = 1.15
@export var band_off_mult: float = 0.85

var _by_id: Dictionary = {} # StringName -> RelicData
var _by_rarity: Dictionary = {} # int -> Array (stored as Array[RelicData], but Dictionary is Variant)

func _ready() -> void:
	_rebuild_indices()

func _rebuild_indices() -> void:
	_by_id.clear()
	_by_rarity.clear()

	# Store typed arrays inside the dictionary (still Variant-typed at the Dictionary level)
	var commons: Array[RelicData] = []
	var rares: Array[RelicData] = []
	var epics: Array[RelicData] = []

	_by_rarity[int(RelicData.Rarity.COMMON)] = commons
	_by_rarity[int(RelicData.Rarity.RARE)] = rares
	_by_rarity[int(RelicData.Rarity.EPIC)] = epics
	# Legendary not rolled by default unless you add it; keep separate if needed.

	for r: RelicData in relics:
		if r == null:
			continue
		if not r.is_valid():
			push_warning("[RelicDatabase] Invalid relic (missing id/name/effect_id).")
			continue

		_by_id[r.id] = r

		match r.rarity:
			RelicData.Rarity.COMMON:
				commons.append(r)
			RelicData.Rarity.RARE:
				rares.append(r)
			RelicData.Rarity.EPIC:
				epics.append(r)
			RelicData.Rarity.LEGENDARY:
				# Not in the normal pools by default.
				# If you want legendaries rollable, add a weight + pool like others.
				pass

func get_relic(id: StringName) -> RelicData:
	if _by_id.has(id):
		return _by_id[id] as RelicData
	return null

func has_relic(id: StringName) -> bool:
	return _by_id.has(id)

# -------------------------
# Rarity roll (with rare_bonus)
# -------------------------
func roll_rarity(rng: RandomNumberGenerator, rare_bonus: float) -> RelicData.Rarity:
	var b: float = clampf(rare_bonus, 0.0, rare_bonus_cap)

	# Shift some common chance into rare+epic
	var cw: float = common_weight
	var rw: float = rare_weight
	var ew: float = epic_weight

	var shift: float = cw * b
	cw = maxf(0.0, cw - shift)

	# Mostly rare, some epic
	rw += shift * 0.80
	ew += shift * 0.20

	var total: float = cw + rw + ew
	if total <= 0.0:
		return RelicData.Rarity.COMMON

	var roll: float = rng.randf() * total
	if roll < cw:
		return RelicData.Rarity.COMMON
	roll -= cw
	if roll < rw:
		return RelicData.Rarity.RARE
	return RelicData.Rarity.EPIC

# -------------------------
# Typed pool fetch (FIXES Array vs Array[RelicData] crash)
# -------------------------
func _get_pool_for_rarity(rarity: int) -> Array[RelicData]:
	var out: Array[RelicData] = []

	var v: Variant = _by_rarity.get(rarity, null)
	if v == null:
		return out

	# v is a Variant Array (untyped). Convert into Array[RelicData].
	if v is Array:
		var arr: Array = v as Array
		for item in arr:
			if item is RelicData:
				out.append(item as RelicData)

	return out

# -------------------------
# Band bias helper
# -------------------------
func _band_weight_mult(target_band: int, relic_band: int) -> float:
	if relic_band == target_band:
		return band_pref_mult

	# Adjacent mapping:
	# Survival <-> Core <-> Greed/Damage
	var adj: bool = false
	if target_band == int(RelicData.Band.SURVIVAL) and relic_band == int(RelicData.Band.CORE):
		adj = true
	elif target_band == int(RelicData.Band.CORE) and (relic_band == int(RelicData.Band.SURVIVAL) or relic_band == int(RelicData.Band.GREED_DAMAGE)):
		adj = true
	elif target_band == int(RelicData.Band.GREED_DAMAGE) and relic_band == int(RelicData.Band.CORE):
		adj = true

	return band_adj_mult if adj else band_off_mult

func _pick_weighted_from(list: Array[RelicData], rng: RandomNumberGenerator, avoid_ids: Dictionary, target_band: int) -> RelicData:
	if list.is_empty():
		return null

	var total: float = 0.0
	for r: RelicData in list:
		if r == null:
			continue
		if avoid_ids.has(r.id):
			continue
		var w: float = maxf(0.0, r.roll_weight)
		w *= _band_weight_mult(target_band, int(r.band))
		total += w

	if total <= 0.0:
		for r2: RelicData in list:
			if r2 != null and not avoid_ids.has(r2.id):
				return r2
		return null

	var roll: float = rng.randf() * total
	for r3: RelicData in list:
		if r3 == null:
			continue
		if avoid_ids.has(r3.id):
			continue
		var w2: float = maxf(0.0, r3.roll_weight)
		w2 *= _band_weight_mult(target_band, int(r3.band))
		if roll < w2:
			return r3
		roll -= w2

	for r4: RelicData in list:
		if r4 != null and not avoid_ids.has(r4.id):
			return r4
	return null

# -------------------------
# Public: roll choices with rarity + band bias
# -------------------------
func roll_choices(
	rng: RandomNumberGenerator,
	owned_ids: Array[StringName],
	count: int,
	rare_bonus: float,
	target_band: int
) -> Array[RelicData]:
	var out: Array[RelicData] = []
	if count <= 0:
		return out

	var avoid: Dictionary = {}
	for id: StringName in owned_ids:
		avoid[id] = true

	for _i in range(count):
		var chosen: RelicData = null

		for _attempt in range(50):
			var rar: RelicData.Rarity = roll_rarity(rng, rare_bonus)

			var pool: Array[RelicData] = _get_pool_for_rarity(int(rar))
			chosen = _pick_weighted_from(pool, rng, avoid, target_band)

			# If exhausted, degrade to common
			if chosen == null and rar != RelicData.Rarity.COMMON:
				var common_pool: Array[RelicData] = _get_pool_for_rarity(int(RelicData.Rarity.COMMON))
				chosen = _pick_weighted_from(common_pool, rng, avoid, target_band)

			if chosen != null:
				break

		if chosen == null:
			break

		out.append(chosen)
		avoid[chosen.id] = true

	return out
