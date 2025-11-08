extends Node
class_name Wrestler

var res:WrestlerResource

func apply_resource(r:WrestlerResource) -> void:
	res = r.duplicate(true)

func get_stat(key: String) -> float:
	if res == null:
		return 0
	if key in StatDefs.ALL or key in StatDefs.LIFECYCLE:
		return res.get(key)
	return 0

func set_stat(key: String, value) -> void:
	if res == null:
		return
	if key in StatDefs.ALL or key in StatDefs.LIFECYCLE:
		res.set(key, value)

func add_stats(delta: Dictionary) -> void:
	if res == null:
		return
	# delta is something like {"strength": +5, "toughness": +2}
	for key in delta.keys():
		if key in StatDefs.ALL:
			var current = res.get(key)
			if typeof(current) in [TYPE_INT, TYPE_FLOAT]:
				res.set(key, current + delta[key])

func get_core_stats() -> Dictionary:
	var out := {}
	for key in StatDefs.CORE:
		out[key] = get_stat(key)
	return out

# Domain-specific helpers

func apply_fatigue(amount:int) -> void:
	var f = int(get_stat("fatigue"))
	set_stat("fatigue", clamp(f + amount, 0, 100))

func rest():
	var f = int(get_stat("fatigue"))
	var m = float(get_stat("morale"))
	set_stat("fatigue", max(0, f - 20))
	set_stat("morale", clamp(m + 0.05, 0.0, 1.0))

func age_one_day():
	var life = int(get_stat("lifespan_days"))
	var days = int(get_stat("days_lived"))
	set_stat("lifespan_days", life - 1)
	set_stat("days_lived", days + 1)
