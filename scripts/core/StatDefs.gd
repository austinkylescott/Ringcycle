class_name StatDefs

# ---------------------------------------------------------------------------
# Stat group constants
# Use these arrays anywhere you need to iterate over stats by category.
# ---------------------------------------------------------------------------

const CORE := [
	"power",        # formerly "strength" — raw damage output
	"technique",    # precision, combo efficiency
	"agility",      # speed, evasion
	"toughness",    # damage reduction
	"stamina",      # move chain length
	"charisma",     # fame gain, crowd mechanics, promo events
]

const SUPPORT := [
	"fatigue",    # 0–100, reduces training efficiency
	"morale",     # 0–100, multiplies training efficiency
	"momentum",   # 0–100, in-match resource
	"fame",       # 0–100, unlocks shows / market tiers
]

const LIFECYCLE := [
	"days_lived",
	"lifespan_days",
]

# Career tracking fields — written to WrestlerResource during gameplay.
# Used by EvolutionSystem condition evaluator and CoachResource generator.
const CAREER := [
	"career_stress_accumulated",  # float, cumulative stress score
	"injuries_sustained",         # int, total injury events
]

# Convenience — everything that Wrestler.get_stat() / add_to_stat() should accept.
const ALL := CORE + SUPPORT + LIFECYCLE


# ---------------------------------------------------------------------------
# Stat bounds
# ---------------------------------------------------------------------------

static func get_min(stat: String) -> float:
	match stat:
		"power", "technique", "agility", "toughness", "stamina", "charisma":
			return 0.0
		"fatigue":
			return 0.0
		"morale":
			return 0.0
		"momentum":
			return 0.0
		"fame":
			return 0.0
		"days_lived":
			return 0.0
		"lifespan_days":
			return 0.0
		_:
			return -INF


static func get_max(stat: String) -> float:
	match stat:
		"power", "technique", "agility", "toughness", "stamina", "charisma":
			return 999.0
		"fatigue":
			return 100.0
		"morale":
			return 100.0
		"momentum":
			return 100.0
		"fame":
			return 100.0
		# Lifecycle — no upper ceiling. Lifespan is species-generated at birth;
		# days_lived climbs until it reaches lifespan_days.
		"days_lived", "lifespan_days":
			return INF
		_:
			return INF


static func clamp_value(stat: String, value: float) -> float:
	var min_v := get_min(stat)
	var max_v := get_max(stat)
	# Both bounds are finite — clamp normally.
	# If either bound is INF / -INF, clamp() still works correctly in GDScript:
	# clamp(x, 0.0, INF) just enforces the floor.
	return clamp(value, min_v, max_v)
