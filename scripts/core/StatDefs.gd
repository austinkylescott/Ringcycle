class_name StatDefs

const CORE := [
	"strength",
	"technique",
	"agility",
	"toughness",
	"stamina",
	"charisma"
]

const SUPPORT := [
	"fatigue",		# 0-100
	"morale",		# 0...1
	"momentum",		# battle resource (guts, energy)
	"fame"
]

const LIFECYCLE := [
	"days_lived",
	"lifespan_days",
]

# Convenience
const ALL := CORE + SUPPORT + LIFECYCLE

static func get_min(stat:String) -> float:
	match stat:
		# Core Stats
		"strength", "technique", "agility", "toughness", "stamina", "charisma":
			return 0.0

		# Support
		"fatigue":
			return 0.0
		"morale":
			return 0.0
		"momentum":
			return 0.0
		"fame":
			return 0.0

		# Lifecycle
		"days_lived", "lifespan_days":
			return 0.0

		_:
			return -INF

static func get_max(stat:String) -> float:
	match stat:
		# Core Stats
		"strength", "technique", "agility", "toughness", "stamina", "charisma":
			return 999.0

		# Support
		"fatigue":
			return 100.0
		"morale":
			return 1.0
		"momentum":
			return 100.0
		"fame":
			return 100.0

		# Lifecycle
		"days_lived", "lifespan_days":
			return 0.0

		_:
			return -INF

static func clamp_value(stat:String, value:float) -> float:
	var min_v := get_min(stat)
	var max_v := get_max(stat)
	if min_v == -INF and max_v == INF:
		return value
	return clamp(value, min_v, max_v)
