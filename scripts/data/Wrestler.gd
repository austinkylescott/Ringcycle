extends Node
class_name Wrestler

var res:WrestlerResource

func apply_resource(r:WrestlerResource) -> void:
	# Never mutate original template directly
	res = r.duplicate(true)

func get_stat(key: String) -> float:
	if res == null:
		return 0.0
	# Only allow known stats / lifecycle keys
	if key in StatDefs.ALL:
		var v = res.get(key)
		return v if v != null else 0.0
	push_warning("get_stat: Unknown key '%s'" % key)
	return 0.0

# Your stat becomes VALUE
# Initialization, Evolution changes, loading from save, overrides
func set_stat_absolute(key: String, value) -> void:
	if res == null:
		return
	if not (key in StatDefs.ALL or key in StatDefs.LIFECYCLE):
		push_warning("set_stat_absolute: Unknown key '%s'" % key)
		return

	var num := float(value)
	var clamped := StatDefs.clamp_value(key,num)
	res.set(key, clamped)


# Modify current value by this amount
# Training results, match rewards, events, items, injuries. "+/- X"
func add_to_stat(key: String, delta) -> void:
	if res == null:
		return

	if not (key in StatDefs.ALL or key in StatDefs.LIFECYCLE):
		push_warning("add_to_stat: Unknown key '%s'" % key)
		return

	var current := get_stat(key)
	var target := current + float(delta)
	var clamped := StatDefs.clamp_value(key, target)
	res.set(key, clamped)

# Batch stat updates
# Training results, match outcomes, events
# {"strength": +5, "toughness": +2, "fatigue": +10"}
func add_stats(delta: Dictionary) -> void:
	if res == null:
		return
	for key in delta.keys():
		add_to_stat(key, delta[key])

func get_growth_multiplier(stat:String) -> float:
	if res == null or res.species == null:
		return 1.0

	var base := 1.0

	# species base growth
	if res.species.growth_profile.has(stat):
		base *= float(res.species.growth_profile[stat])

	# stage growth
	if GrowthProfiles.STAGE_MULTIPLIERS.has(res.stage):
		var stage_map = GrowthProfiles.STAGE_MULTIPLIERS[res.stage]
		if stage_map.has(stat):
			base *= float(stage_map[stat])

	# effects
	for effect in res.active_effects:
		for key in effect.growth_multipliers.keys():
				if key == stat:
					base *= float(effect.growth_multipliers[key])

	return base

func get_training_efficiency() -> float:
	var fatigue := float(clamp(get_stat("fatigue"), 0.0, 100.0))
	var morale := float(clamp(get_stat("morale"), 0.0, 1.0))

	var fatigue_factor := float(lerp(1.0, 0.3, fatigue / 100.0))
	var morale_factor := float(lerp(0.8, 1.2, morale))

	return fatigue_factor * morale_factor


# Domain-specific helpers

func apply_fatigue(amount:int) -> void:
	add_to_stat("fatigue", amount)

func rest():
	var f = int(get_stat("fatigue"))
	var m = float(get_stat("morale"))
	add_to_stat("fatigue", max(0, f - 20))
	add_to_stat("morale", clamp(m + 0.05, 0.0, 1.0))

func age_one_day():
	add_to_stat("lifespan_days", -1)
	add_to_stat("days_lived", +1)

func apply_effect(effect: StatEffect) -> void:
	# Apply instant deltas
	if effect.instant_deltas.size() > 0:
		add_stats(effect.instant_deltas)

	# Track ongoing effects
	if effect.duration_days != 0:
		# for a real system you'd wrap this in an ActiveEffect with remaining_days
		res.active_effects.append(effect)

func on_day_passed() -> void:
	# if you introduce ActiveEffect wrapper with remaining_days, decrement here
	# and remove expired ones
	pass
