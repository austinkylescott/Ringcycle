extends Resource
class_name EvolutionCondition

# ---------------------------------------------------------------------------
# A single condition that must pass for an evolution transition to trigger.
# Multiple EvolutionConditions are grouped in EvolutionLineResource —
# ALL conditions in a group must pass simultaneously.
#
# Set the "type" field first, then fill in only the fields that type uses.
# Unused fields are ignored by the evaluator.
# ---------------------------------------------------------------------------

enum Type {
	STAT_MIN,          # stat >= value
	STAT_MAX,          # stat <= value (for against-grain paths)
	STAT_RATIO,        # stat_a >= stat_b * ratio
	TRAINING_MIN,      # training_session_counts[stat] >= sessions
	AGE_MIN,           # days_lived >= days
	ITEM_USED,         # item_id appears in career items_consumed
	EVENT_TRIGGERED,   # event_id appears in career events_triggered
	FAME_MIN,          # fame >= value
	STAGE_IS,          # current stage matches stage string
}

@export var type: Type = Type.STAT_MIN

# --- Used by STAT_MIN, STAT_MAX, FAME_MIN ---
@export var stat: String = ""
@export var value: float = 0.0

# --- Used by STAT_RATIO ---
@export var stat_a: String = ""
@export var stat_b: String = ""
@export var ratio: float = 1.0

# --- Used by TRAINING_MIN ---
# (also uses stat field above)
@export var sessions: int = 0

# --- Used by AGE_MIN ---
@export var days: int = 0

# --- Used by ITEM_USED ---
@export var item_id: String = ""

# --- Used by EVENT_TRIGGERED ---
@export var event_id: String = ""

# --- Used by STAGE_IS ---
@export var stage: String = ""

# ---------------------------------------------------------------------------
# Optional: hint text shown to the player when this condition is revealed
# by a Legend or Hall of Fame coach. Leave blank to show nothing.
# Full reveal shows hint_full. Partial reveal shows hint_vague.
# ---------------------------------------------------------------------------
@export var hint_vague: String = ""   # e.g. "Needs high Power..."
@export var hint_full: String = ""    # e.g. "Needs 400 Power"


# ---------------------------------------------------------------------------
# Evaluate this condition against a WrestlerResource.
# Called by EvolutionSystem — do not call directly in game logic.
# ---------------------------------------------------------------------------
func evaluate(res: WrestlerResource) -> bool:
	match type:
		Type.STAT_MIN:
			return _get_stat(res, stat) >= value

		Type.STAT_MAX:
			return _get_stat(res, stat) <= value

		Type.STAT_RATIO:
			var a := _get_stat(res, stat_a)
			var b := _get_stat(res, stat_b)
			if b == 0.0:
				return false
			return a >= b * ratio

		Type.TRAINING_MIN:
			var count: int = res.training_session_counts.get(stat, 0)
			return count >= sessions

		Type.AGE_MIN:
			return res.days_lived >= days

		Type.ITEM_USED:
			return item_id in res.items_consumed

		Type.EVENT_TRIGGERED:
			return event_id in res.events_triggered

		Type.FAME_MIN:
			return res.fame >= value

		Type.STAGE_IS:
			return res.stage == stage

	return false


# ---------------------------------------------------------------------------
# Returns a human-readable summary for debugging and editor tooltips.
# ---------------------------------------------------------------------------
func describe() -> String:
	match type:
		Type.STAT_MIN:
			return "%s >= %d" % [stat.capitalize(), int(value)]
		Type.STAT_MAX:
			return "%s <= %d" % [stat.capitalize(), int(value)]
		Type.STAT_RATIO:
			return "%s >= %s * %.1f" % [stat_a.capitalize(), stat_b.capitalize(), ratio]
		Type.TRAINING_MIN:
			return "%s training sessions >= %d" % [stat.capitalize(), sessions]
		Type.AGE_MIN:
			return "Days lived >= %d" % days
		Type.ITEM_USED:
			return "Used item: %s" % item_id
		Type.EVENT_TRIGGERED:
			return "Event triggered: %s" % event_id
		Type.FAME_MIN:
			return "Fame >= %d" % int(value)
		Type.STAGE_IS:
			return "Stage is %s" % stage
	return "Unknown condition"


# ---------------------------------------------------------------------------
# Internal helper — reads a stat from WrestlerResource safely.
# ---------------------------------------------------------------------------
func _get_stat(res: WrestlerResource, key: String) -> float:
	if key == "fame":
		return float(res.fame)
	if key in StatDefs.CORE:
		var v = res.get(key)
		return float(v) if v != null else 0.0
	if key in StatDefs.SUPPORT:
		var v = res.get(key)
		return float(v) if v != null else 0.0
	push_warning("EvolutionCondition._get_stat: unknown stat '%s'" % key)
	return 0.0
