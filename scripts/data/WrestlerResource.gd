extends Resource
class_name WrestlerResource

@export var display_name:String = "Rookie"
@export var stage:String = "Rookie" # Rookie/Pro/Headliner/Superstar
@export var lifespan_days:int = 365*5

# Battle Stats
@export var strength:int = 50	# Power
@export var technique:int = 45	# Accuracy
@export var agility:int = 35		# Speed
@export var toughness:int = 40	# Defense
@export var stamina:int = 60		# Life
@export var charisma:int = 55	# Intelligence

# Lifestyle Stats
@export var fatigue:int = 0
@export var morale:float = 0.5	# 0-1
@export var momentum:int = 0		# Battle Resource (Guts)
@export var days_lived:int = 0

# Learned Moves
@export var learned_moved:Array[String] = []
#Legacy Bonuses (small % growth adders)
@export var legacy_growth_bonus:float = 0.0
