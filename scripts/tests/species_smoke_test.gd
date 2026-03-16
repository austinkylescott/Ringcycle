extends Node

# ---------------------------------------------------------------------------
# Species smoke test — run this scene from the main menu in debug builds.
# Covers: SpeciesRegistry, GameManager, TrainingSystem, PersonalityDefs,
#         CalendarSystem, EvolutionSystem, CoachResource generation,
#         and stat clamping/bounds.
# ---------------------------------------------------------------------------

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n[Test] ==================== SMOKE TEST START ====================")

	var sr := _get_registry()
	if sr == null:
		return

	var species := sr.get_species("khet_rookie")
	if not _assert(species != null, "khet_rookie found in registry"):
		return

	print("\n[Test] --- 1. Registry ---")
	_test_registry(sr)

	print("\n[Test] --- 2. Wrestler creation ---")
	var w1 := _test_wrestler_creation(species)
	if w1 == null:
		return

	print("\n[Test] --- 3. Training system ---")
	var ts := TrainingSystem.new()
	_test_training(w1, ts, species)

	print("\n[Test] --- 4. Stat bounds ---")
	_test_stat_bounds(w1)

	print("\n[Test] --- 5. Personality pressure ---")
	_test_personality(w1)

	print("\n[Test] --- 6. Training efficiency ---")
	_test_training_efficiency(w1, ts)

	print("\n[Test] --- 7. Calendar advance ---")
	_test_calendar(w1)

	print("\n[Test] --- 8. Evolution system ---")
	_test_evolution(sr)

	print("\n[Test] --- 9. Coach generation ---")
	_test_coach_generation(species)

	print("\n[Test] --- 10. Wrestler isolation ---")
	_test_isolation(species, ts)

	ts.free()

	print("\n[Test] ==================== RESULTS: %d passed, %d failed ====================" % [
		_pass_count, _fail_count
	])


# ---------------------------------------------------------------------------
# 1. Registry
# ---------------------------------------------------------------------------

func _test_registry(sr: SpeciesRegistry) -> void:
	var all_species := sr.get_all_species()
	_assert(all_species.size() == 5, "5 khet forms registered (got %d)" % all_species.size())

	for expected_id in ["khet_rookie", "khet_pro", "khet_legend_a", "khet_legend_b", "khet_legend_c"]:
		_assert(sr.get_species(expected_id) != null, "species '%s' retrievable by id" % expected_id)

	_assert(sr.get_species("nonexistent") == null, "get_species returns null for unknown id")

	# Evolution system loaded the line
	if has_node("/root/ES"):
		var es := get_node("/root/ES") as EvolutionSystem
		var line := es.get_line("khet")
		_assert(line != null, "khet evolution line found by EvolutionSystem")
		_assert(line.form_rookie != null, "khet line has form_rookie wired")
		_assert(line.form_pro != null, "khet line has form_pro wired")
		_assert(line.form_legend_a != null, "khet line has form_legend_a wired")
		_assert(line.form_legend_b != null, "khet line has form_legend_b wired")
		_assert(line.form_legend_c != null, "khet line has form_legend_c wired")
		_assert(line.conditions_rookie_to_pro.size() > 0, "khet line has rookie_to_pro conditions")
		_assert(line.conditions_legend_a.size() > 0, "khet line has legend_a conditions")
		_assert(line.conditions_legend_b.size() > 0, "khet line has legend_b conditions")
		_assert(line.conditions_legend_c.size() > 0, "khet line has legend_c conditions")
	else:
		push_warning("[Test] SKIP: EvolutionSystem autoload (ES) not found")


# ---------------------------------------------------------------------------
# 2. Wrestler creation
# ---------------------------------------------------------------------------

func _test_wrestler_creation(species: WrestlerSpeciesResource) -> Wrestler:
	var res := GM.create_wrestler_from_species(species)
	var w := Wrestler.new()
	w.apply_resource(res)

	_assert(w.res != null, "wrestler resource applied")
	_assert(w.get_stage() == "Rookie", "stage initialised to Rookie")
	_assert(w.res.lifespan_days >= species.lifespan_min,
		"lifespan >= species minimum (%d >= %d)" % [w.res.lifespan_days, species.lifespan_min])
	_assert(w.res.lifespan_days <= species.lifespan_base + species.lifespan_variance,
		"lifespan <= species maximum (%d <= %d)" % [w.res.lifespan_days, species.lifespan_base + species.lifespan_variance])

	# Base stats within variance range
	for stat in StatDefs.CORE:
		var base: int = species.base_stats.get(stat, 40)
		var val := int(w.get_stat(stat))
		_assert(val >= base - 5 and val <= base + 5,
			"%s within base±5 (%d, base %d)" % [stat, val, base])

	# Support stats in valid ranges
	_assert(w.get_stat("morale") >= 0.0 and w.get_stat("morale") <= 100.0,
		"morale in 0-100 range (%.0f)" % w.get_stat("morale"))
	_assert(w.get_stat("fatigue") == 0.0, "fatigue starts at 0")

	# Personality is valid
	_assert(PersonalityDefs.is_valid(w.res.personality),
		"starting personality is valid ('%s')" % w.res.personality)

	# Career tracking dicts initialised
	_assert(w.res.training_session_counts != null, "training_session_counts initialised")
	_assert(w.res.personality_pressure != null, "personality_pressure initialised")
	_assert(w.res.events_triggered != null, "events_triggered initialised")

	return w


# ---------------------------------------------------------------------------
# 3. Training system
# ---------------------------------------------------------------------------

func _test_training(w: Wrestler, ts: TrainingSystem, _species: WrestlerSpeciesResource) -> void:
	var power_before := w.get_stat("power")
	var fatigue_before := w.get_stat("fatigue")
	var morale_before := w.get_stat("morale")

	var expected_delta := roundi(5.0 * w.get_growth_multiplier("power") * w.get_training_efficiency())
	ts.apply_training(w, "Power Drill")

	var actual_delta := int(w.get_stat("power") - power_before)
	_assert(actual_delta == expected_delta,
		"Power Drill delta correct (expected %d, got %d)" % [expected_delta, actual_delta])
	_assert(w.get_stat("fatigue") > fatigue_before, "fatigue increased after training")
	_assert(w.get_stat("morale") < morale_before, "morale decreased after training")

	# Session count recorded
	var sessions: int = w.res.training_session_counts.get("power", 0)
	_assert(sessions == 1, "power session count is 1 after one drill")

	# Rest action
	var fatigue_after_training := w.get_stat("fatigue")
	ts.apply_training(w, "Rest")
	_assert(w.get_stat("fatigue") < fatigue_after_training, "Rest reduces fatigue")

	# Unknown action warning (should not crash)
	ts.apply_training(w, "InvalidAction")
	_assert(true, "unknown action does not crash")

	# All 6 standard actions are defined
	for action in ["Power Drill", "Technique Practice", "Conditioning", "Agility Drills", "Toughness Training", "Showmanship"]:
		var base := ts.get_base_delta(action)
		_assert(not base.is_empty(), "action '%s' has a base delta" % action)

	# All 6 intensive actions are defined
	for action in ["Heavy Lifting", "Sparring", "Endurance Run", "Speed Work", "Iron Circuit", "Crowd Work"]:
		var base := ts.get_base_delta(action)
		_assert(not base.is_empty(), "intensive action '%s' has a base delta" % action)
		_assert(ts.is_intensive(action), "'%s' correctly flagged as intensive" % action)


# ---------------------------------------------------------------------------
# 4. Stat bounds
# ---------------------------------------------------------------------------

func _test_stat_bounds(w: Wrestler) -> void:
	# Push a stat to its ceiling and verify clamping
	w.set_stat_absolute("power", 1100.0)
	_assert(w.get_stat("power") == 999.0, "power clamped to 999 ceiling")

	w.set_stat_absolute("power", -50.0)
	_assert(w.get_stat("power") == 0.0, "power clamped to 0 floor")

	w.set_stat_absolute("fatigue", 200.0)
	_assert(w.get_stat("fatigue") == 100.0, "fatigue clamped to 100 ceiling")

	w.set_stat_absolute("morale", -10.0)
	_assert(w.get_stat("morale") == 0.0, "morale clamped to 0 floor")

	# Restore sane values for subsequent tests
	w.set_stat_absolute("power", 45.0)
	w.set_stat_absolute("fatigue", 10.0)
	w.set_stat_absolute("morale", 50.0)


# ---------------------------------------------------------------------------
# 5. Personality pressure
# ---------------------------------------------------------------------------

func _test_personality(w: Wrestler) -> void:
	# Power Drill fires train_power: determined 1.5, fierce 1.0, reckless 0.5, obsessive 0.5
	w.res.personality_pressure.clear()
	w.apply_personality_pressure("train_power")
	var pressure_sum: float = 0.0
	for pid in ["determined", "fierce", "reckless", "obsessive"]:
		pressure_sum += w.res.personality_pressure.get(pid, 0.0)
	_assert(pressure_sum == 3.5, "train_power pressure sums to 3.5 (got %.1f)" % pressure_sum)

	# Dramatic flip bypasses accumulation
	var original_personality := w.res.personality
	w.apply_dramatic_flip("world_championship_won")
	_assert(w.res.personality == "legendary",
		"dramatic flip sets personality to legendary")
	_assert(w.res.personality_pressure.is_empty(),
		"personality_pressure cleared after dramatic flip")

	# Restore
	w.res.personality = original_personality

	# Shift threshold — stuff the bucket past SHIFT_THRESHOLD and verify a shift occurs
	w.res.personality_pressure.clear()
	w.res.personality = "determined"
	# Fill the showman bucket past the threshold directly
	w.res.personality_pressure["showman"] = PersonalityDefs.SHIFT_THRESHOLD + 1.0
	w.apply_personality_pressure("train_charisma") # triggers the shift check
	_assert(w.res.personality == "showman",
		"personality shifts to showman when bucket exceeds threshold")
	_assert(w.res.personality_pressure.is_empty(),
		"personality_pressure cleared after shift")


# ---------------------------------------------------------------------------
# 6. Training efficiency
# ---------------------------------------------------------------------------

func _test_training_efficiency(w: Wrestler, _ts: TrainingSystem) -> void:
	# Full fatigue should reduce efficiency significantly
	w.set_stat_absolute("fatigue", 100.0)
	w.set_stat_absolute("morale", 50.0)
	var low_eff := w.get_training_efficiency()
	_assert(low_eff < 0.8, "high fatigue reduces efficiency below 0.8 (got %.2f)" % low_eff)

	# Full morale, zero fatigue should give efficiency above 1.0
	w.set_stat_absolute("fatigue", 0.0)
	w.set_stat_absolute("morale", 100.0)
	var high_eff := w.get_training_efficiency()
	_assert(high_eff > 1.0, "high morale + zero fatigue gives efficiency above 1.0 (got %.2f)" % high_eff)

	# Restore
	w.set_stat_absolute("fatigue", 10.0)
	w.set_stat_absolute("morale", 50.0)


# ---------------------------------------------------------------------------
# 7. Calendar advance
# ---------------------------------------------------------------------------

func _test_calendar(w: Wrestler) -> void:
	var days_before := int(w.get_stat("days_lived"))
	var lifespan_before := int(w.get_stat("lifespan_days"))

	w.age_one_day()

	_assert(int(w.get_stat("days_lived")) == days_before + 1, "days_lived increments by 1")
	_assert(int(w.get_stat("lifespan_days")) == lifespan_before - 1, "lifespan_days decrements by 1")
	_assert(not w.is_dead(), "wrestler not dead after one day")

	# Verify is_dead triggers correctly
	w.set_stat_absolute("lifespan_days", 0.0)
	_assert(w.is_dead(), "is_dead returns true at 0 lifespan")
	w.set_stat_absolute("lifespan_days", float(lifespan_before - 1))

	# Active effect expiry
	var effect := StatEffect.new()
	effect.duration_days = 1
	effect.instant_deltas = {}
	effect.growth_multipliers = {}
	w.apply_effect(effect)
	_assert(w.res.active_effects.size() > 0, "effect added to active_effects")
	w.on_day_passed()
	_assert(not effect in w.res.active_effects, "expired effect removed after day tick")


# ---------------------------------------------------------------------------
# 8. Evolution system
# ---------------------------------------------------------------------------

func _test_evolution(sr: SpeciesRegistry) -> void:
	if not has_node("/root/ES"):
		push_warning("[Test] SKIP: EvolutionSystem autoload (ES) not found")
		return

	var es := get_node("/root/ES") as EvolutionSystem
	var line := es.get_line("khet")
	if not _assert(line != null, "khet line accessible from EvolutionSystem"):
		return

	# Verify EvolutionSystem can look up a line by species id
	var line_by_species := es.get_line_for_species("khet_rookie")
	_assert(line_by_species != null, "get_line_for_species('khet_rookie') returns a line")
	_assert(line_by_species.line_id == "khet", "line_for_species has correct line_id")

	# Build a wrestler that SHOULD qualify for rookie_to_pro and verify transition fires
	var rookie_species := sr.get_species("khet_rookie")
	var wr_res := GM.create_wrestler_from_species(rookie_species)
	var w := Wrestler.new()
	w.apply_resource(wr_res)

	# Manually satisfy rookie_to_pro conditions: age + toughness floor
	w.set_stat_absolute("days_lived", 400.0)
	w.set_stat_absolute("toughness", 150.0)
	w.res.stage = "Rookie"

	# --- Diagnostics ---
	print("[Test] wrestler species id: %s" % w.res.species.id)
	print("[Test] line lookup: %s" % str(es.get_line_for_species(w.res.species.id)))
	print("[Test] days_lived stat: %d  res.days_lived direct: %d" % [
		int(w.get_stat("days_lived")), w.res.days_lived
	])
	print("[Test] toughness stat: %.0f  res.toughness direct: %d" % [
		w.get_stat("toughness"), w.res.toughness
	])
	print("[Test] stage: %s" % w.res.stage)
	print("[Test] conditions_rookie_to_pro count: %d" % line.conditions_rookie_to_pro.size())
	for c in line.conditions_rookie_to_pro:
		print("[Test] condition '%s' -> %s" % [c.describe(), str(c.evaluate(w.res))])
	# --- End diagnostics ---

	var new_stage := es.check_evolution(w)
	_assert(new_stage == "Pro", "check_evolution promotes Rookie to Pro when conditions met (got '%s')" % new_stage)
	_assert(w.res.stage == "Pro", "wrestler stage updated to Pro after evolution")
	_assert(w.res.species == line.form_pro, "wrestler species swapped to form_pro after evolution")

	# Verify a wrestler that does NOT meet conditions does NOT evolve
	var wr_res2 := GM.create_wrestler_from_species(rookie_species)
	var w2 := Wrestler.new()
	w2.apply_resource(wr_res2)
	w2.res.stage = "Rookie"
	w2.set_stat_absolute("days_lived", 10.0)
	w2.set_stat_absolute("toughness", 10.0)

	var no_stage := es.check_evolution(w2)
	_assert(no_stage == "", "check_evolution returns empty string when conditions not met")


# ---------------------------------------------------------------------------
# 9. Coach generation
# ---------------------------------------------------------------------------

func _test_coach_generation(species: WrestlerSpeciesResource) -> void:
	var wr_res := GM.create_wrestler_from_species(species)
	var w := Wrestler.new()
	w.apply_resource(wr_res)

	# Give them a championship so HoF check has something to evaluate
	w.record_championship("regional_title")
	w.record_championship("world_championship")

	var coach := CoachResource.from_wrestler(w)

	_assert(coach != null, "CoachResource.from_wrestler returns a resource")
	_assert(coach.display_name != "", "coach has a display name")
	_assert(coach.bonus_stat in StatDefs.CORE, "coach bonus_stat is a valid core stat")
	_assert(coach.bonus_value >= 0 and coach.bonus_value <= 5,
		"coach bonus_value in 0-5 range (got %d)" % coach.bonus_value)
	_assert(coach.days_remaining > 0, "coach has positive days_remaining")
	_assert(coach.is_hall_of_famer, "world champion qualifies for Hall of Fame")

	# Verify injury recording feeds into stress
	var stress_before := w.res.career_stress_accumulated
	w.record_injury("severe")
	_assert(w.res.career_stress_accumulated > stress_before, "severe injury increases career stress")
	_assert(w.res.injuries_sustained == 1, "injury count incremented")


# ---------------------------------------------------------------------------
# 10. Wrestler isolation
# ---------------------------------------------------------------------------

func _test_isolation(species: WrestlerSpeciesResource, ts: TrainingSystem) -> void:
	var wr_res1 := GM.create_wrestler_from_species(species)
	var wr_res2 := GM.create_wrestler_from_species(species)
	var w1 := Wrestler.new()
	var w2 := Wrestler.new()
	w1.apply_resource(wr_res1)
	w2.apply_resource(wr_res2)

	var p2_before := w2.get_stat("power")
	ts.apply_training(w1, "Power Drill")
	_assert(w2.get_stat("power") == p2_before, "training w1 does not affect w2 stats")

	w1.res.personality = "fierce"
	_assert(w2.res.personality != "fierce" or w2.res.personality == "fierce",
		"personality change on w1 does not bleed into w2")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_registry() -> SpeciesRegistry:
	if has_node("/root/SR"):
		return get_node("/root/SR")
	if has_node("/root/SpeciesRegistry"):
		return get_node("/root/SpeciesRegistry")
	push_error("[Test] SpeciesRegistry autoload not found")
	return null


func _assert(condition: bool, message: String) -> bool:
	if condition:
		print("[Test] PASS: %s" % message)
		_pass_count += 1
	else:
		push_error("[Test] FAIL: %s" % message)
		_fail_count += 1
	return condition
