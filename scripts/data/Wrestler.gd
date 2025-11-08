extends Node
class_name Wrestler

var res:WrestlerResource

func apply_resource(r:WrestlerResource) -> void:
	res = r.duplicate(true)

func add_stats(delta: Dictionary) -> void:
	# delta is something like {"strength": +5, "toughness": +2}
	for key in delta.keys():
		var amount: int = int(delta[key])
		match key:
			"strength":
				res.strength += amount
			"technique":
				res.technique += amount
			"agility":
				res.agility += amount
			"toughness":
				res.toughness += amount
			"stamina":
				res.stamina += amount
			"charisma":
				res.charisma += amount
			_:
				# Ignore unknown keys for now
				pass

func apply_fatigue(amount:int) -> void:
	res.fatigue = clamp(res.fatigue + amount, 0, 100)

func rest():
	res.fatigue = max(0, res.fatigue - 20)
	res.morale = clamp(res.morale + 0.05, 0.0, 1.0)

func age_one_day():
	res.days_lived += 1
	res.lifespan_days -= 1
