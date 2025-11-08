extends Node
class_name TrainingSystem

signal trained(action_name:String, stat_delta:Dictionary, fatigue:int, morale_delta:float)

func do_training(wrestler:Wrestler, action_name:String) -> void:
	var delta := {}
	var fatigue := 10
	var morale_delta := - 0.02
	
	match action_name:
		"Strength Drill":
			delta = {"strength": +5, "toughness": +2, "agility": -1}
		"Technique Practice":
			delta = {"technique":+5, "charisma": +2}
		"Conditioning":
			delta = {"stamina":+6, "strength": +1, "agility": +1}
		"Showmanship":
			delta = {"charisma": +6, "technique": +1}
		"Rest":
			wrestler.rest()
			delta = {}
			fatigue = -20
			morale_delta = +0.05
			
	if action_name != "Rest":
		wrestler.add_stats(delta)
		wrestler.apply_fatigue(fatigue)
		wrestler.res.morale = clamp(wrestler.res.morale + morale_delta, 0.0, 1.0)

	emit_signal("trained", action_name, delta, fatigue, morale_delta)
