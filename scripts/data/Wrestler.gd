extends Node
class_name Wrestler

# ---------------------------------------------------------------------------
# Wrestler is the behavioral layer over WrestlerResource.
# It owns all stat mutation, career tracking, and personality logic.
#
# Rules:
#   - No other system reads or writes WrestlerResource fields directly.
#   - All stat changes go through add_to_stat() or add_stats().
#   - All career events go through the record_* / trigger_* methods below.
#   - UI code only calls get_stat() and the read helpers — never res.field.
# ---------------------------------------------------------------------------

var res: WrestlerResource


# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func apply_resource(r: WrestlerResource) -> void:
	# Duplicate so we never mutate the source template
	res = r.duplicate(true)


# ---------------------------------------------------------------------------
# Stat reading
# ---------------------------------------------------------------------------

func get_stat(key: String) -> float:
	if res == null:
		return 0.0
	if key in StatDefs.ALL:
		var v = res.get(key)
		return float(v) if v != null else 0.0
	push_warning("Wrestler.get_stat: unknown key '%s'" % key)
	return 0.0


# ---------------------------------------------------------------------------
# Stat writing — all mutations go through these three methods
# ---------------------------------------------------------------------------

# Set a stat to an absolute value.
# Use for: initialisation, evolution overrides, loading from save.
func set_stat_absolute(key: String, value) -> void:
	if res == null:
		return
	if not key in StatDefs.ALL:
		push_warning("Wrestler.set_stat_absolute: unknown key '%s'" % key)
		return
	res.set(key, StatDefs.clamp_value(key, float(value)))


# Add a delta to a stat.
# Use for: training results, match rewards, injury penalties, item effects.
func add_to_stat(key: String, delta) -> void:
	if res == null:
		return
	if not key in StatDefs.ALL:
		push_warning("Wrestler.add_to_stat: unknown key '%s'" % key)
		return
	var current := get_stat(key)
	res.set(key, StatDefs.clamp_value(key, current + float(delta)))


# Batch stat update.
# Use for: training deltas, match outcomes, evolution bonuses.
# e.g. add_stats({"power": 5, "fatigue": 10, "morale": -5})
func add_stats(delta: Dictionary) -> void:
	if res == null:
		return
	for key in delta.keys():
		add_to_stat(key, delta[key])


# ---------------------------------------------------------------------------
# Growth multiplier
# Applied by TrainingSystem to scale raw training gains.
# Combines species growth profile, active effects, and soft cap taper.
# ---------------------------------------------------------------------------

func get_growth_multiplier(stat: String) -> float:
	if res == null:
		return 1.0

	var base := 1.0

	# Species growth profile for this form
	if res.species != null and res.species.growth_profile.has(stat):
		base *= float(res.species.growth_profile[stat])

	# Active effect multipliers
	for effect in res.active_effects:
		if effect.growth_multipliers.has(stat):
			base *= float(effect.growth_multipliers[stat])

	# Personality modifier — converts -2..2 scale to a multiplier
	# -2 = 0.6x, -1 = 0.8x, 0 = 1.0x, +1 = 1.2x, +2 = 1.4x
	var personality_mod := PersonalityDefs.get_modifier(res.personality, stat)
	base *= (1.0 + personality_mod * 0.2)

	# Soft cap taper
	# Above the species soft cap threshold, gains taper toward zero.
	# Global curve: linear taper from full gain at cap to 10% gain at 999.
	if res.species != null and res.species.soft_caps.has(stat):
		var cap := float(res.species.soft_caps[stat])
		var current := get_stat(stat)
		if current > cap:
			var over := current - cap
			var range := 999.0 - cap
			if range > 0.0:
				# taper_factor goes from 1.0 at cap to 0.1 at 999
				var taper := 1.0 - (over / range) * 0.9
				base *= max(taper, 0.1)

	return base


# ---------------------------------------------------------------------------
# Training efficiency
# Combined fatigue and morale factor applied to all training gains.
# Both stats are now 0–100.
#   fatigue: 0 = full efficiency, 100 = 30% efficiency
#   morale:  0 = 80% efficiency,  100 = 120% efficiency
# ---------------------------------------------------------------------------

func get_training_efficiency() -> float:
	var fatigue := clamp(get_stat("fatigue"), 0.0, 100.0)
	var morale  := clamp(get_stat("morale"),  0.0, 100.0)

	var fatigue_factor := lerp(1.0, 0.3, fatigue / 100.0)
	var morale_factor  := lerp(0.8, 1.2, morale  / 100.0)

	return fatigue_factor * morale_factor


# ---------------------------------------------------------------------------
# Career tracking
# All game systems call these methods to record what happened this career.
# These feeds EvolutionSystem condition evaluation and CoachResource generation.
# ---------------------------------------------------------------------------

# Call after every training session. Increments the session counter for that
# stat and fires the matching personality pressure event.
func record_training_session(stat: String) -> void:
	if res == null:
		return
	var current: int = res.training_session_counts.get(stat, 0)
	res.training_session_counts[stat] = current + 1
	apply_personality_pressure("train_" + stat)


# Call when a career event fires (championship won, crowd reaction, etc.).
# Appends to events_triggered so EvolutionCondition.EVENT_TRIGGERED can check it.
func trigger_event(event_id: String) -> void:
	if res == null:
		return
	if not event_id in res.events_triggered:
		res.events_triggered.append(event_id)
	apply_personality_pressure(event_id)


# Call when an item is used. Appends to items_consumed.
func use_item(item_id: String, pressure_event: String = "item_food") -> void:
	if res == null:
		return
	res.items_consumed.append(item_id)
	apply_personality_pressure(pressure_event)


# Call when a championship is won. Appends to championships_held and
# triggers the championship_won personality pressure event.
func record_championship(championship_id: String) -> void:
	if res == null:
		return
	if not championship_id in res.championships_held:
		res.championships_held.append(championship_id)
	trigger_event("championship_won")


# Call when an injury event fires.
func record_injury(severity: String = "minor") -> void:
	if res == null:
		return
	res.injuries_sustained += 1
	var pressure_event := "injury_minor" if severity == "minor" else "injury_severe"
	apply_personality_pressure(pressure_event)
	# Stress penalty — severe injuries add more stress than minor ones
	var stress := 0.1 if severity == "minor" else 0.3
	apply_stress(stress)


# Adds to career stress score. Called by overtraining, injuries, overwork.
# Clamped to 0.0–1.0. Higher stress = worse coach quality at retirement.
func apply_stress(amount: float) -> void:
	if res == null:
		return
	res.career_stress_accumulated = clamp(
		res.career_stress_accumulated + amount, 0.0, 1.0
	)


# ---------------------------------------------------------------------------
# Personality system
# ---------------------------------------------------------------------------

# Applies pressure from an event toward related personalities.
# Reads weights from PersonalityDefs.PRESSURE_EVENTS.
# When any bucket crosses SHIFT_THRESHOLD the personality shifts and all
# buckets reset.
func apply_personality_pressure(event_id: String) -> void:
	if res == null:
		return

	var weights := PersonalityDefs.get_pressure(event_id)
	if weights.is_empty():
		return

	# Add weights to buckets
	for pid in weights.keys():
		var current: float = res.personality_pressure.get(pid, 0.0)
		var next := current + float(weights[pid])
		# Buckets don't go below zero — negative weights drain but don't invert
		res.personality_pressure[pid] = max(0.0, next)

	# Check for a shift — iterate PersonalityDefs order for determinism
	for pid in PersonalityDefs.all_ids():
		if pid == res.personality:
			continue
		var pressure: float = res.personality_pressure.get(pid, 0.0)
		if pressure >= PersonalityDefs.SHIFT_THRESHOLD:
			_shift_personality(pid)
			return


# Bypasses accumulation and shifts personality immediately.
# Use for dramatic career moments (career-ending injury, world title win).
func apply_dramatic_flip(flip_event: String) -> void:
	if res == null:
		return
	if PersonalityDefs.DRAMATIC_FLIPS.has(flip_event):
		var target: String = PersonalityDefs.DRAMATIC_FLIPS[flip_event]
		_shift_personality(target)


func _shift_personality(new_personality: String) -> void:
	if not PersonalityDefs.is_valid(new_personality):
		push_warning("Wrestler._shift_personality: invalid personality '%s'" % new_personality)
		return
	res.personality = new_personality
	# Clear all buckets on shift
	res.personality_pressure.clear()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

# Called once per in-game day by CalendarSystem.
func age_one_day() -> void:
	add_to_stat("days_lived",   1)
	add_to_stat("lifespan_days", -1)
	on_day_passed()


# Called after age_one_day. Ticks down active effect durations.
func on_day_passed() -> void:
	if res == null:
		return

	var expired: Array[StatEffect] = []
	for effect in res.active_effects:
		if effect.duration_days > 0:
			effect.duration_days -= 1
			if effect.duration_days <= 0:
				expired.append(effect)

	for effect in expired:
		res.active_effects.erase(effect)


# Returns true if this monster's lifespan has run out.
func is_dead() -> bool:
	return get_stat("lifespan_days") <= 0


# ---------------------------------------------------------------------------
# Effect application
# ---------------------------------------------------------------------------

func apply_effect(effect: StatEffect) -> void:
	if res == null:
		return
	# Apply instant deltas immediately
	if not effect.instant_deltas.is_empty():
		add_stats(effect.instant_deltas)
	# Queue ongoing effects for daily tick
	if effect.duration_days != 0:
		res.active_effects.append(effect)


# ---------------------------------------------------------------------------
# Convenience read helpers (used by UI and systems — not for stat math)
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	return res.display_name if res != null else ""

func get_stage() -> String:
	return res.stage if res != null else ""

func get_personality_display() -> String:
	return PersonalityDefs.get_display_name(res.personality) if res != null else ""

func is_alive() -> bool:
	return not is_dead()
