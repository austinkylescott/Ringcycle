extends Node
class_name TrainingSystem

func get_base_delta(action_name: String) -> Dictionary:
	match action_name:
		"Strength Drill":
			return {"strength": +5, "toughness": +2, "agility": -1, "fatigue": +10, "morale": -.02}
		"Technique Practice":
			return {"technique":+5, "charisma": +2, "fatigue": +10, "morale": -.02}
		"Conditioning":
			return {"stamina":+6, "strength": +1, "agility": +1, "fatigue": +10, "morale": -.02}
		"Showmanship":
			return {"charisma": +6, "technique": +1, "fatigue": +10, "morale": -.02}
		"Rest":
			return {"fatigue": -20, "morale": 0.05}
		_:
			return {}


func compute_effective_delta(w:Wrestler, base:Dictionary) -> Dictionary:
	var eff := {}
	var efficiency := w.get_training_efficiency()

	for key in base.keys():
		var value = base[key]

		if key in StatDefs.CORE:
			var growth_mult := float(w.get_growth_multiplier(key))
			eff[key] = round(value * growth_mult * efficiency)
		elif key == "fatigue" or key == "morale":
			# Could also scale these with efficiency
			eff[key] = value
		else:
			eff[key] = value
	return eff

func apply_training(w:Wrestler, action_name:String) -> void:
	var base := get_base_delta(action_name)
	var delta := compute_effective_delta(w, base)
	w.add_stats(delta)
