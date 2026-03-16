extends Node

# ---------------------------------------------------------------------------
# Species smoke test — run this scene from the main menu in debug builds.
# Verifies SpeciesRegistry, GameManager, TrainingSystem, and the personality
# pressure system all work together correctly.
#
# Expected output in the Godot console:
#   [Test] PASS: power increased by expected delta: N
#   [Test] PASS: other wrestler unchanged
#   [Test] PASS: training session count recorded
#   [Test] PASS: personality pressure applied
#   [Test] Species smoke test complete.
# ---------------------------------------------------------------------------

func _ready() -> void:
	print("[Test] Species smoke test starting...")

	# --- SpeciesRegistry check ---
	if not (has_node("/root/SR") or has_node("/root/SpeciesRegistry")):
		push_error("[Test] SpeciesRegistry autoload not found")
		return

	var sr: SpeciesRegistry
	if has_node("/root/SR"):
		sr = get_node("/root/SR")
	else:
		sr = get_node("/root/SpeciesRegistry")

	var all_species := sr.get_all_species()
	print("[Test] species available: %d" % all_species.size())

	if all_species.is_empty():
		push_error("[Test] No species found — add at least one WrestlerSpeciesResource to scripts/data/species/")
		return

	# Use first available species
	var species: WrestlerSpeciesResource = all_species[0]
	print("[Test] using species: %s (id: %s)" % [species.display_name, species.id])

	# --- Create two wrestlers from the same species ---
	var wr_res1 := GM.create_wrestler_from_species(species)
	var wr_res2 := GM.create_wrestler_from_species(species)

	var w1 := Wrestler.new()
	var w2 := Wrestler.new()
	w1.apply_resource(wr_res1)
	w2.apply_resource(wr_res2)

	# --- Stat independence check ---
	var p1_before := w1.get_stat("power")
	var p2_before := w2.get_stat("power")
	print("[Test] initial power — w1: %d  w2: %d" % [int(p1_before), int(p2_before)])

	# --- Training delta check ---
	var ts := TrainingSystem.new()

	# Compute expected delta before training (pre-training state)
	var expected_delta := roundi(
		5.0 * w1.get_growth_multiplier("power") * w1.get_training_efficiency()
	)

	ts.apply_training(w1, "Power Drill")

	var p1_after := w1.get_stat("power")
	var p2_after := w2.get_stat("power")
	var actual_delta := int(p1_after - p1_before)

	if actual_delta == expected_delta:
		print("[Test] PASS: power increased by expected delta: %d" % actual_delta)
	else:
		push_error("[Test] FAIL: power delta expected %d but got %d (before: %d after: %d eff: %.2f)" % [
			expected_delta, actual_delta, int(p1_before), int(p1_after),
			w1.get_training_efficiency()
		])

	# --- Isolation check ---
	if p2_after == p2_before:
		print("[Test] PASS: other wrestler unchanged")
	else:
		push_error("[Test] FAIL: other wrestler changed — before: %d after: %d" % [
			int(p2_before), int(p2_after)
		])

	# --- Session count check ---
	var session_count: int = w1.res.training_session_counts.get("power", 0)
	if session_count == 1:
		print("[Test] PASS: training session count recorded")
	else:
		push_error("[Test] FAIL: expected session count 1, got %d" % session_count)

	# --- Personality pressure check ---
	# Power Drill fires train_power pressure toward determined, fierce, reckless, obsessive
	var pressure_sum := 0.0
	for pid in ["determined", "fierce", "reckless", "obsessive"]:
		pressure_sum += w1.res.personality_pressure.get(pid, 0.0)

	if pressure_sum > 0.0:
		print("[Test] PASS: personality pressure applied (total: %.1f)" % pressure_sum)
	else:
		push_error("[Test] FAIL: no personality pressure recorded after Power Drill")

	# --- Lifespan check ---
	if w1.res.lifespan_days >= species.lifespan_min:
		print("[Test] PASS: lifespan rolled correctly (%d days)" % w1.res.lifespan_days)
	else:
		push_error("[Test] FAIL: lifespan %d is below species minimum %d" % [
			w1.res.lifespan_days, species.lifespan_min
		])

	# --- Morale range check (0-100 not 0.0-1.0) ---
	var morale := w1.get_stat("morale")
	if morale >= 0.0 and morale <= 100.0:
		print("[Test] PASS: morale in 0-100 range (%.0f)" % morale)
	else:
		push_error("[Test] FAIL: morale out of range: %.4f" % morale)

	print("[Test] Species smoke test complete.")

	# Clean up the TrainingSystem node we created manually
	ts.free()
