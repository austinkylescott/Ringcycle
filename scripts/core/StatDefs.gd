extends Node
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
const ALL := CORE + SUPPORT
