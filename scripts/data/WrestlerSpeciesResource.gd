extends Resource
class_name WrestlerSpeciesResource

@export var id: String
@export var display_name: String

@export var base_stats := {
	"strength": 50,
	"technique": 40,
	"agility": 40,
	"toughness": 40,
	"stamina": 40,
	"charisma": 40,
}

# Baseline growth rates for this species
# 1.0 = normal, >1 faster, <1 slower
@export var growth_profile := {
	"strength": 1.3, 	# ++
	"stamina": 0.8,		# -
	# anything not present defaults to 1.0
}

@export var move_pool: Array[String] = []
@export var portrait: Texture2D
@export var body_sprite: Texture2D
