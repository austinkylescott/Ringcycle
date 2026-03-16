extends Node
class_name TrainingSystem

# ---------------------------------------------------------------------------
# TrainingSystem computes and applies the result of one training action.
#
# 12 training actions — 6 standard, 6 intensive:
#   Standard:  1 core stat gain, moderate fatigue, small morale hit
#   Intensive: 2 core stat gains, high fatigue, moderate morale hit, extra stress
#
# Flow:
#   1. GymHub calls apply_training(wrestler, action_name)
#   2. get_base_delta() returns raw stat changes for that action
#   3. compute_effective_delta() scales core gains through:
#        - get_growth_multiplier() — species profile, personality, soft cap
#        - get_training_efficiency() — fatigue and morale combined factor
#      Support stats (fatigue, morale) are never scaled — always applied raw.
#   4. apply_training() writes delta, records session, fires personality pressure
#
# CalendarSystem calls on_week_start(wrestler) every Monday.
#
# TUNING NOTE (2026-03-16):
#   Base deltas reduced ~50% from original values. Training alone should not
#   be able to push a stat to 800+. That ceiling requires shows, tours, and
#   items on top of a training foundation. Target stat ranges at key milestones
#   (balanced play, no items/tours):
#     Rookie → Pro  (~500 days):   40–80 per stat
#     Pro → Legend  (~1172 days):  100–180 per stat (specialist ~250 in focus stat)
#     End of Legend career:        250–400 range; 800+ requires show/tour bonuses
# ---------------------------------------------------------------------------

# Tracks which stats were trained this in-game week for varied detection.
# Cleared by on_week_start() each Monday.
var _stats_trained_this_week: Array[String] = []


# ---------------------------------------------------------------------------
# Base deltas
# ---------------------------------------------------------------------------

func get_base_delta(action_name: String) -> Dictionary:
	match action_name:

		# --- Standard: 1 core stat only ---
		"Power Drill":
			return {"power": 2, "fatigue": 10, "morale": -5}
		"Technique Practice":
			return {"technique": 2, "fatigue": 10, "morale": -5}
		"Conditioning":
			return {"stamina": 3, "fatigue": 10, "morale": -5}
		"Agility Drills":
			return {"agility": 2, "fatigue": 10, "morale": -5}
		"Toughness Training":
			return {"toughness": 2, "fatigue": 10, "morale": -5}
		"Showmanship":
			return {"charisma": 3, "fatigue": 10, "morale": -5}

		# --- Rest ---
		"Rest":
			return {"fatigue": -20, "morale": 10}

		# --- Intensive: 2 core stats ---
		# Primary stat gains significantly, secondary gains moderately.
		# High fatigue cost, moderate morale hit, extra stress.
		"Heavy Lifting":
			return {"power": 5, "toughness": 2, "fatigue": 20, "morale": -10}
		"Sparring":
			return {"technique": 5, "charisma": 2, "fatigue": 20, "morale": -10}
		"Endurance Run":
			return {"stamina": 6, "agility": 2, "fatigue": 20, "morale": -10}
		"Speed Work":
			return {"agility": 5, "stamina": 2, "fatigue": 20, "morale": -10}
		"Iron Circuit":
			return {"toughness": 5, "power": 2, "fatigue": 20, "morale": -10}
		"Crowd Work":
			return {"charisma": 6, "technique": 2, "fatigue": 20, "morale": -10}

		_:
			push_warning("TrainingSystem.get_base_delta: unknown action '%s'" % action_name)
			return {}


# ---------------------------------------------------------------------------
# Action metadata helpers
# ---------------------------------------------------------------------------

# Returns the primary stat trained by an action, or "" for rest / unknown.
func get_primary_stat(action_name: String) -> String:
	match action_name:
		"Power Drill",        "Heavy Lifting":  return "power"
		"Technique Practice", "Sparring":       return "technique"
		"Conditioning",       "Endurance Run":  return "stamina"
		"Agility Drills",     "Speed Work":     return "agility"
		"Toughness Training", "Iron Circuit":   return "toughness"
		"Showmanship",        "Crowd Work":     return "charisma"
		_:                                      return ""


# Returns true if the action is an intensive variant.
func is_intensive(action_name: String) -> bool:
	return action_name in [
		"Heavy Lifting", "Sparring", "Endurance Run",
		"Speed Work", "Iron Circuit", "Crowd Work",
	]


# ---------------------------------------------------------------------------
# Effective delta computation
# Core stats scaled by growth multiplier * training efficiency.
# Support stats (fatigue, morale) always applied raw.
# ---------------------------------------------------------------------------

func compute_effective_delta(w: Wrestler, base: Dictionary) -> Dictionary:
	var eff := {}
	var efficiency := w.get_training_efficiency()

	for key in base.keys():
		var value: float = float(base[key])
		if key in StatDefs.CORE:
			var growth_mult := w.get_growth_multiplier(key)
			eff[key] = roundi(value * growth_mult * efficiency)
		else:
			eff[key] = value

	return eff


# ---------------------------------------------------------------------------
# Apply training — main entry point called by GymHub
# ---------------------------------------------------------------------------

func apply_training(w: Wrestler, action_name: String) -> void:
	if w == null or w.res == null:
		return

	var base := get_base_delta(action_name)
	if base.is_empty():
		return

	var delta := compute_effective_delta(w, base)
	w.add_stats(delta)

	var primary_stat := get_primary_stat(action_name)

	if primary_stat != "":
		# Record session — increments count and fires train_{stat} pressure
		w.record_training_session(primary_stat)

		# Track for varied week detection
		if not primary_stat in _stats_trained_this_week:
			_stats_trained_this_week.append(primary_stat)

		# Stress accumulation
		var stress_tick := 0.005
		if w.get_stat("fatigue") > 70.0:
			stress_tick += 0.01
		if is_intensive(action_name):
			stress_tick += 0.01
		w.apply_stress(stress_tick)

		# Obsessive drilling — fires every 3 sessions of the same stat
		var session_count: int = w.res.training_session_counts.get(primary_stat, 0)
		if session_count > 0 and session_count % 3 == 0:
			w.apply_personality_pressure("train_same_repeatedly")

	if action_name == "Rest":
		w.apply_stress(-0.02)


# ---------------------------------------------------------------------------
# Week boundary — called by CalendarSystem on Monday (day 1 of new week)
# ---------------------------------------------------------------------------

func on_week_start(w: Wrestler) -> void:
	if w != null and _stats_trained_this_week.size() >= 3:
		w.apply_personality_pressure("train_varied")
	_stats_trained_this_week.clear()
