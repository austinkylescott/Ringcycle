extends Node

# Quick smoke tests for SpeciesRegistry, GameManager and TrainingSystem.
# Attach this script to a scene and run the scene in the editor to see printed results.

func _ready() -> void:
    print("[Test] Species smoke test starting...")

    # Ensure registry loaded
    if not (has_node("/root/SR") or has_node("/root/SpeciesRegistry")):
        push_error("[Test] SpeciesRegistry autoload not found (SR)")
        return
    var sr = null
    if has_node("/root/SR"):
        sr = get_node("/root/SR")
    else:
        sr = get_node("/root/SpeciesRegistry")

    print("[Test] species available:", sr.get_all_species())

    var species = sr.get_species("rookie")
    if species == null:
        push_error("[Test] rookie species not found")
        return

    # Create two wrestler instances from the same species via GameManager helper
    var wr_res1 = GM.create_wrestler_from_species(species)
    var wr_res2 = GM.create_wrestler_from_species(species)

    var w1 = Wrestler.new()
    var w2 = Wrestler.new()
    w1.apply_resource(wr_res1)
    w2.apply_resource(wr_res2)

    # Check initial independence
    var s1_before = w1.get_stat("strength")
    var s2_before = w2.get_stat("strength")
    print("[Test] initial strengths:", s1_before, s2_before)

    # Apply training to w1 only
    var ts = TrainingSystem.new()
    ts.apply_training(w1, "Strength Drill")

    var s1_after = w1.get_stat("strength")
    var s2_after = w2.get_stat("strength")

    var expected_delta = round(5 * w1.get_growth_multiplier("strength") * w1.get_training_efficiency())
    var actual_delta = int(s1_after - s1_before)

    if actual_delta == expected_delta:
        print("[Test] PASS: strength increased by expected delta:", actual_delta)
    else:
        push_error("[Test] FAIL: strength delta expected %s but got %s" % [expected_delta, actual_delta])

    # Ensure w2 unchanged
    if s2_after == s2_before:
        print("[Test] PASS: other wrestler unchanged")
    else:
        push_error("[Test] FAIL: other wrestler changed: before=%s after=%s" % [s2_before, s2_after])

    print("[Test] Species smoke test complete.")
