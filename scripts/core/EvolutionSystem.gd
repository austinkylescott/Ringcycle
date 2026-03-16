extends Node
class_name EvolutionSystem

# ---------------------------------------------------------------------------
# EvolutionSystem checks whether the active wrestler qualifies for an
# evolution transition and applies it if so.
#
# It reads transition conditions from EvolutionLineResource files, which are
# discovered at startup by scanning res://scripts/data/species/ recursively.
# Each WrestlerSpeciesResource has an id — the line registry maps
# species ids to their parent EvolutionLineResource.
#
# Call check_evolution(wrestler) after every action in GymHub.
# It is safe to call every day — returns early if no transition is ready.
# ---------------------------------------------------------------------------

signal evolution_triggered(wrestler: Wrestler, new_stage: String)

# line_id -> EvolutionLineResource
var _lines: Dictionary = {}

# species_form_id -> EvolutionLineResource
# Allows lookup by any form id in the line (rookie, pro, or legend)
var _form_to_line: Dictionary = {}


# ---------------------------------------------------------------------------
# Startup — scan species folders for EvolutionLineResource files
# ---------------------------------------------------------------------------

func _ready() -> void:
	_scan_folder("res://scripts/data/species")
	print("[EvolutionSystem] loaded %d evolution lines: %s" % [
		_lines.size(), _lines.keys()
	])


func _scan_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with("."):
			fname = dir.get_next()
			continue

		var full := "%s/%s" % [path, fname]

		if dir.current_is_dir():
			# Recurse into species subfolders (brick/, showboat/, etc.)
			_scan_folder(full)
		elif fname.to_lower().ends_with(".tres") or fname.to_lower().ends_with(".res"):
			var res := ResourceLoader.load(full)
			if res is EvolutionLineResource:
				_register_line(res)

		fname = dir.get_next()

	dir.list_dir_end()


func _register_line(line: EvolutionLineResource) -> void:
	_lines[line.line_id] = line

	# Map every form id back to this line for fast lookup
	var forms := [
		line.form_rookie,
		line.form_pro,
		line.form_legend_a,
		line.form_legend_b,
		line.form_legend_c,
	]
	for form in forms:
		if form != null and form.id != "":
			_form_to_line[form.id] = line


# ---------------------------------------------------------------------------
# Main check — call after every action
# ---------------------------------------------------------------------------

# Checks whether the wrestler qualifies for any evolution transition.
# Applies the transition and emits evolution_triggered if so.
# Returns the new stage string, or "" if no transition occurred.
func check_evolution(w: Wrestler) -> String:
	if w == null or w.res == null:
		return ""

	var line := _get_line_for_wrestler(w)
	if line == null:
		return ""

	match w.res.stage:
		"Rookie":
			if line.check_transition("rookie_to_pro", w.res):
				return _apply_evolution(w, line, "Pro", line.form_pro)

		"Pro":
			var legend_path := line.check_legend_transition(w.res)
			if legend_path != "":
				var stage_name := _legend_path_to_stage(legend_path)
				var form := line.get_form(stage_name)
				return _apply_evolution(w, line, stage_name, form)

	return ""


# ---------------------------------------------------------------------------
# Apply an evolution transition
# ---------------------------------------------------------------------------

func _apply_evolution(
	w: Wrestler,
	_line: EvolutionLineResource,
	new_stage: String,
	new_form: WrestlerSpeciesResource
) -> String:
	if new_form == null:
		push_warning("EvolutionSystem._apply_evolution: new_form is null for stage '%s'" % new_stage)
		return ""

	# Swap species reference — growth profile, soft caps, and available move pool update.
	# learned_moves is intentionally NOT touched — moves learned during a career
	# are personal history and persist through every form change.
	w.res.species = new_form
	w.res.stage   = new_stage

	# Clear personality pressure on evolution — it's a fresh chapter
	w.res.personality_pressure.clear()

	# Record the evolution as a career event for condition tracking
	w.trigger_event("evolved_to_%s" % new_stage.to_lower())

	emit_signal("evolution_triggered", w, new_stage)

	print("[EvolutionSystem] %s evolved to %s" % [w.get_display_name(), new_stage])
	return new_stage


# ---------------------------------------------------------------------------
# Hint reveal
# Used by the coaching UI to show partial or full evolution conditions.
# Returns an array of hint strings for a given legend path.
#
# reveal_level: "vague" or "full"
# ---------------------------------------------------------------------------

func get_legend_hints(
	line_id: String,
	legend_path: String,
	reveal_level: String
) -> Array[String]:
	var hints: Array[String] = []
	var line := _lines.get(line_id, null) as EvolutionLineResource
	if line == null:
		return hints

	var conditions := line.get_conditions(legend_path)
	for condition in conditions:
		var hint := ""
		if reveal_level == "full":
			hint = condition.hint_full
		else:
			hint = condition.hint_vague
		if hint != "":
			hints.append(hint)

	return hints


# ---------------------------------------------------------------------------
# Registry accessors
# ---------------------------------------------------------------------------

func get_line(line_id: String) -> EvolutionLineResource:
	return _lines.get(line_id, null)


func get_line_for_species(species_id: String) -> EvolutionLineResource:
	return _form_to_line.get(species_id, null)


func get_all_lines() -> Array:
	return _lines.values()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_line_for_wrestler(w: Wrestler) -> EvolutionLineResource:
	if w.res.species == null:
		return null
	return _form_to_line.get(w.res.species.id, null)


func _legend_path_to_stage(legend_path: String) -> String:
	match legend_path:
		"legend_a": return "Legend_A"
		"legend_b": return "Legend_B"
		"legend_c": return "Legend_C"
	push_warning("EvolutionSystem._legend_path_to_stage: unknown path '%s'" % legend_path)
	return ""
