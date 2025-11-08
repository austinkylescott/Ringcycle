extends Node
class_name TrainingSystem

func get_training_delta(action_name: String) -> Dictionary:
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

func apply_training(wrestler:Wrestler, action_name:String) -> void:
	var delta := get_training_delta(action_name)
	wrestler.add_stats(delta)
