extends Resource
class_name EvolutionLineResource

# ---------------------------------------------------------------------------
# Maps a complete species evolution line:
#   Rookie -> Pro -> Legend A / B / C
#
# Each stage slot holds a reference to its WrestlerSpeciesResource.
# Each transition slot holds an Array[EvolutionCondition] — ALL must pass.
#
# The EvolutionSystem reads this file to know:
#   - Which species resource to swap in when a transition fires
#   - Which conditions gate each transition
#   - Which hint text to surface for coach reveals
#
# One EvolutionLineResource per species line.
# Example on disk:
#   species/brick_line.tres
#   species/brick_rookie.tres
#   species/brick_pro.tres
#   species/brick_legend_a.tres
#   species/brick_legend_b.tres
#   species/brick_legend_c.tres
# ---------------------------------------------------------------------------

@export var line_id: String          # e.g. "brick"
@export var display_name: String     # e.g. "The Brick"

# ---------------------------------------------------------------------------
# Species forms — one resource per stage
# ---------------------------------------------------------------------------
@export var form_rookie:   WrestlerSpeciesResource
@export var form_pro:      WrestlerSpeciesResource
@export var form_legend_a: WrestlerSpeciesResource
@export var form_legend_b: WrestlerSpeciesResource
@export var form_legend_c: WrestlerSpeciesResource

# ---------------------------------------------------------------------------
# Transition conditions
# All conditions in an array must pass for that transition to fire.
# Evaluated in order: rookie_to_pro first, then legend paths.
# ---------------------------------------------------------------------------

# Rookie -> Pro: simple age + stat floor, same for all monsters of this line
@export var conditions_rookie_to_pro: Array[EvolutionCondition] = []

# Pro -> Legend A: natural path, rewards dominant stat training
@export var conditions_legend_a: Array[EvolutionCondition] = []

# Pro -> Legend B: specialist path, rewards investing in a weaker stat
@export var conditions_legend_b: Array[EvolutionCondition] = []

# Pro -> Legend C: against-grain path, hardest to discover
@export var conditions_legend_c: Array[EvolutionCondition] = []

# ---------------------------------------------------------------------------
# Legend priority
# If multiple Legend conditions are satisfied simultaneously, this order
# determines which fires. Default: C > B > A (rarest wins).
# Override per line if a species has different priority needs.
# ---------------------------------------------------------------------------
@export var legend_priority: Array[String] = ["legend_c", "legend_b", "legend_a"]

# ---------------------------------------------------------------------------
# Hint reveal levels
# Controls how much of the evolution chart a coach of this line can reveal.
# These are checked by the coaching system when assigning hint text.
#
# "none"    — no hint (default for most conditions)
# "vague"   — shows hint_vague from the EvolutionCondition
# "full"    — shows hint_full from the EvolutionCondition
# ---------------------------------------------------------------------------
@export var legend_a_hint_level: String = "none"
@export var legend_b_hint_level: String = "none"
@export var legend_c_hint_level: String = "none"


# ---------------------------------------------------------------------------
# Helpers used by EvolutionSystem
# ---------------------------------------------------------------------------

# Returns the conditions array for a given transition key.
# Valid keys: "rookie_to_pro", "legend_a", "legend_b", "legend_c"
func get_conditions(transition: String) -> Array:
	match transition:
		"rookie_to_pro": return conditions_rookie_to_pro
		"legend_a":      return conditions_legend_a
		"legend_b":      return conditions_legend_b
		"legend_c":      return conditions_legend_c
	push_warning("EvolutionLineResource.get_conditions: unknown transition '%s'" % transition)
	return []


# Returns the species resource for a given stage string.
# Valid stages: "Rookie", "Pro", "Legend_A", "Legend_B", "Legend_C"
func get_form(stage: String) -> WrestlerSpeciesResource:
	match stage:
		"Rookie":   return form_rookie
		"Pro":      return form_pro
		"Legend_A": return form_legend_a
		"Legend_B": return form_legend_b
		"Legend_C": return form_legend_c
	push_warning("EvolutionLineResource.get_form: unknown stage '%s'" % stage)
	return null


# Returns true if all conditions for a given transition pass.
func check_transition(transition: String, res: WrestlerResource) -> bool:
	var conditions := get_conditions(transition)
	if conditions.is_empty():
		return false
	for condition in conditions:
		if not condition.evaluate(res):
			return false
	return true


# Checks all three Legend paths in priority order and returns the first
# that passes, or empty string if none qualify.
func check_legend_transition(res: WrestlerResource) -> String:
	for path in legend_priority:
		if check_transition(path, res):
			return path
	return ""
