extends Node
class_name EvolutionSystem

func should_evolve(w:Wrestler) -> bool:
	var half_life := (365.0*5) / 2 # midpoint trigger for prototype
	return w.res.days_lived >= half_life and w.res.stage == "Rookie"

func evolve(w:Wrestler) -> void:
	# 3-path prototype:
	# Bruiser: High STR, low morale
	# Showstopper: Balanced, high CHA
	# Ring General: High technique + toughness

	var strength = w.get_stat("strength")
	var technique = w.get_stat("technique")
	var agility = w.get_stat("agility")
	var toughness = w.get_stat("toughness")
	var charisma = w.get_stat("charisma")
	var morale = w.get_stat("morale")

	if strength >= max(technique,agility,toughness, charisma) and morale < 0.4:
		_apply_bruiser(w)
	elif abs(strength - technique) <=5 and charisma >= 65:
		_apply_showstopper(w)
	else:
		_apply_ring_general(w)

func _apply_bruiser(w:Wrestler) -> void:
	w.add_stats({"strength": +15, "toughness": +8, "agility": -3})
	w.res.stage = "Pro"

func _apply_showstopper(w:Wrestler) -> void:
	w.add_stats({"charisma": +15, "technique": +8})
	w.res.stage = "Pro"

func _apply_ring_general(w:Wrestler) -> void:
	w.add_stats({"technique": +12, "toughness": +8})
	w.res.stage = "Pro"
