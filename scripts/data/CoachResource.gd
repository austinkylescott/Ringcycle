extends Resource
class_name CoachResource

# ---------------------------------------------------------------------------
# CoachResource is a frozen snapshot of a retired monster's coaching value.
# It is generated once at retirement via CoachResource.from_wrestler() and
# never mutated during gameplay.
#
# Two independent outputs:
#   1. stat_bonus — flat per-session training bonus derived from the retired
#      monster's dominant stat value (0–5 scale, bracket-based)
#   2. move_bias  — list of move ids the coach predisposes the active wrestler
#      toward learning. Sampled probabilistically by the move learn system.
#
# Personality does NOT carry into retirement. The coach has no personality.
# The player sees "Technique +4" — not who this monster was.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Identity (display only)
# ---------------------------------------------------------------------------
@export var display_name: String = ""
@export var species_id: String   = ""
@export var stage_reached: String = ""   # highest stage achieved e.g. "Legend_C"
@export var portrait: Texture2D

# Whether this coach is a Hall of Famer — gates evolution hint reveal level
@export var is_hall_of_famer: bool = false


# ---------------------------------------------------------------------------
# Coaching bonus
# The stat this coach boosts and by how much (0–5).
# Randomly chosen between the top two stats at retirement.
# ---------------------------------------------------------------------------
@export var bonus_stat: String = ""   # e.g. "power"
@export var bonus_value: int   = 0    # 0–5


# ---------------------------------------------------------------------------
# Move bias
# Moves the coach predisposes the active wrestler toward learning.
# The move learn system adds extra weight to these ids when sampling.
# Derived from the coach's learned_moves at retirement.
# ---------------------------------------------------------------------------
@export var move_bias: Array[String] = []


# ---------------------------------------------------------------------------
# Evolution hints
# Populated if the coach reached Legend or Hall of Fame status.
# Maps legend path id -> hint string to surface in the evolution chart UI.
#
# Legend coach:      hint_vague strings for the path they achieved
# Hall of Fame coach: hint_full strings for the path they achieved
# ---------------------------------------------------------------------------
@export var evolution_hints: Dictionary = {}   # path_id -> Array[String]


# ---------------------------------------------------------------------------
# Lifespan
# Coaches continue aging after retirement. When days_remaining hits 0
# the coach dies and their slot opens. GameManager ticks this each day.
# ---------------------------------------------------------------------------
@export var days_remaining: int = 0


# ---------------------------------------------------------------------------
# Move transfer state
# Tracks progress toward the active wrestler learning each bias move.
# Populated and ticked by the move learn system — not set at retirement.
# move_id -> float progress 0.0–1.0
# ---------------------------------------------------------------------------
@export var move_transfer_progress: Dictionary = {}


# ---------------------------------------------------------------------------
# Factory — generate a CoachResource from a retiring Wrestler
# ---------------------------------------------------------------------------

static func from_wrestler(w: Wrestler) -> CoachResource:
	var coach := CoachResource.new()

	if w == null or w.res == null:
		push_warning("CoachResource.from_wrestler: wrestler or resource is null")
		return coach

	var res := w.res

	# --- Identity ---
	coach.display_name  = res.display_name
	coach.species_id    = res.species.id if res.species != null else ""
	coach.stage_reached = res.stage
	coach.portrait      = res.species.portrait if res.species != null else null
	coach.is_hall_of_famer = _check_hall_of_fame(res)

	# --- Stat bonus ---
	# Pick randomly between the top two core stats at retirement
	var top_two  := _get_top_two_stats(res)
	var chosen   := top_two[randi() % top_two.size()]
	var stat_val := int(res.get(chosen)) if res.get(chosen) != null else 0

	coach.bonus_stat  = chosen
	coach.bonus_value = _stat_to_bonus(stat_val)

	# --- Move bias ---
	# Coach can bias toward any move they learned during their career
	coach.move_bias = res.learned_moves.duplicate()

	# --- Evolution hints ---
	coach.evolution_hints = _build_hints(w)

	# --- Lifespan ---
	# Coach lives out their remaining lifespan after retirement
	coach.days_remaining = int(res.lifespan_days)

	return coach


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Returns the top two core stats by current value.
# If two stats are tied or within 10 points, both are eligible.
static func _get_top_two_stats(res: WrestlerResource) -> Array[String]:
	var values: Array = []
	for stat in StatDefs.CORE:
		var v = res.get(stat)
		values.append({"stat": stat, "value": int(v) if v != null else 0})

	# Sort descending by value
	values.sort_custom(func(a, b): return a["value"] > b["value"])

	var top: Array[String] = [values[0]["stat"]]

	# Include second stat if within 10 points of the highest
	if values.size() > 1 and (values[0]["value"] - values[1]["value"]) <= 10:
		top.append(values[1]["stat"])

	return top


# Converts a raw stat value to a 0–5 coaching bonus.
static func _stat_to_bonus(stat_value: int) -> int:
	if stat_value >= 950: return 5
	if stat_value >= 800: return 4
	if stat_value >= 600: return 3
	if stat_value >= 400: return 2
	if stat_value >= 200: return 1
	return 0


# Checks Hall of Fame eligibility from the career record.
# HoF requires winning the world championship OR a threshold of titles.
static func _check_hall_of_fame(res: WrestlerResource) -> bool:
	if "world_championship" in res.championships_held:
		return true
	# Holding 3 or more distinct championships also qualifies
	# Threshold is a placeholder — tune during content pass
	if res.championships_held.size() >= 3:
		return true
	return false


# Builds evolution hint arrays from the wrestler's career.
# Requires EvolutionSystem autoload (ES) to look up the line.
static func _build_hints(w: Wrestler) -> Dictionary:
	var hints := {}

	if not Engine.get_main_loop().root.has_node("/root/ES"):
		return hints

	var es = Engine.get_main_loop().root.get_node("/root/ES")
	var line: EvolutionLineResource = es.get_line_for_species(
		w.res.species.id if w.res.species != null else ""
	)
	if line == null:
		return hints

	# Determine hint level from stage reached
	var reveal_level := ""
	if w.res.stage in ["Legend_A", "Legend_B", "Legend_C"]:
		reveal_level = "vague"
	if _check_hall_of_fame(w.res):
		reveal_level = "full"

	if reveal_level == "":
		return hints

	# Only reveal hints for the path the coach actually achieved
	var path := _stage_to_legend_path(w.res.stage)
	if path == "":
		return hints

	var path_hints := es.get_legend_hints(line.line_id, path, reveal_level)
	if not path_hints.is_empty():
		hints[path] = path_hints

	return hints


static func _stage_to_legend_path(stage: String) -> String:
	match stage:
		"Legend_A": return "legend_a"
		"Legend_B": return "legend_b"
		"Legend_C": return "legend_c"
	return ""
