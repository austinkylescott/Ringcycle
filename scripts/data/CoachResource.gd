extends Resource
class_name CoachResource

# ---------------------------------------------------------------------------
# CoachResource — frozen snapshot of a retired wrestler's coaching value.
# Generated at voluntary retirement via CoachResource.from_wrestler().
# Never generated on death.
#
# Bonus value is stage-scaled:
#   Rookie:      0–1
#   Pro:         1–2
#   Legend:      2–4
#   HoF Legend:  4–5
# ---------------------------------------------------------------------------

@export var display_name:  String = ""
@export var species_id:    String = ""
@export var stage_reached: String = ""
@export var portrait:      Texture2D

@export var is_hall_of_famer: bool = false

@export var bonus_stat:  String = ""
@export var bonus_value: int    = 0

@export var move_bias:         Array[String] = []
@export var evolution_hints:   Dictionary    = {}

@export var days_remaining:         int        = 0
@export var move_transfer_progress: Dictionary = {}


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

static func from_wrestler(w: Wrestler) -> CoachResource:
	var coach := CoachResource.new()

	if w == null or w.res == null:
		push_warning("CoachResource.from_wrestler: wrestler or resource is null")
		return coach

	var res := w.res

	coach.display_name    = res.display_name
	coach.species_id      = res.species.id if res.species != null else ""
	coach.stage_reached   = res.stage
	coach.portrait        = res.species.portrait if res.species != null else null
	coach.is_hall_of_famer = _check_hall_of_fame(res)

	# Pick randomly between top two stats
	var top_two := _get_top_two_stats(res)
	var chosen  := top_two[randi() % top_two.size()]
	var stat_val := int(res.get(chosen)) if res.get(chosen) != null else 0

	coach.bonus_stat  = chosen
	coach.bonus_value = _stat_to_bonus(stat_val, res.stage, coach.is_hall_of_famer)

	coach.move_bias        = res.learned_moves.duplicate()
	coach.evolution_hints  = _build_hints(w)
	coach.days_remaining   = int(res.lifespan_days)

	return coach


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _get_top_two_stats(res: WrestlerResource) -> Array[String]:
	var values: Array = []
	for stat in StatDefs.CORE:
		var v = res.get(stat)
		values.append({"stat": stat, "value": int(v) if v != null else 0})
	values.sort_custom(func(a, b): return a["value"] > b["value"])

	var top: Array[String] = [values[0]["stat"]]
	if values.size() > 1 and (values[0]["value"] - values[1]["value"]) <= 10:
		top.append(values[1]["stat"])
	return top


# Stage-scaled bonus:
#   Rookie:      raw stat maps to 0–1
#   Pro:         raw stat maps to 1–2
#   Legend:      raw stat maps to 2–4
#   HoF Legend:  raw stat maps to 4–5
static func _stat_to_bonus(stat_value: int, stage: String, is_hof: bool) -> int:
	# Base raw bonus from stat value (0–5 scale)
	var raw := _raw_bonus(stat_value)

	match stage:
		"Rookie":
			# Clamp to 0–1 regardless of stats
			return clampi(raw, 0, 1)
		"Pro":
			# Clamp to 1–2, minimum 1 even with low stats
			return clampi(raw, 1, 2)
		"Legend_A", "Legend_B", "Legend_C":
			if is_hof:
				# HoF Legend: 4–5
				return clampi(raw, 4, 5)
			else:
				# Legend: 2–4
				return clampi(raw, 2, 4)
		_:
			return clampi(raw, 0, 1)


# Raw 0–5 bracket based purely on stat value
static func _raw_bonus(stat_value: int) -> int:
	if stat_value >= 950: return 5
	if stat_value >= 800: return 4
	if stat_value >= 600: return 3
	if stat_value >= 400: return 2
	if stat_value >= 200: return 1
	return 0


static func _check_hall_of_fame(res: WrestlerResource) -> bool:
	if "world_championship" in res.championships_held:
		return true
	if res.championships_held.size() >= 3:
		return true
	return false


static func _build_hints(w: Wrestler) -> Dictionary:
	var hints := {}
	var root : Window = Engine.get_main_loop().root
	if not root.has_node("/root/ES"):
		return hints

	var es := root.get_node("/root/ES") as EvolutionSystem
	var line: EvolutionLineResource = es.get_line_for_species(
		w.res.species.id if w.res.species != null else ""
	)
	if line == null:
		return hints

	var reveal_level := ""
	if w.res.stage in ["Legend_A", "Legend_B", "Legend_C"]:
		reveal_level = "vague"
	if _check_hall_of_fame(w.res):
		reveal_level = "full"
	if reveal_level == "":
		return hints

	var path := _stage_to_legend_path(w.res.stage)
	if path == "":
		return hints

	var path_hints: Array[String] = es.get_legend_hints(line.line_id, path, reveal_level)
	if not path_hints.is_empty():
		hints[path] = path_hints

	return hints


static func _stage_to_legend_path(stage: String) -> String:
	match stage:
		"Legend_A": return "legend_a"
		"Legend_B": return "legend_b"
		"Legend_C": return "legend_c"
	return ""
