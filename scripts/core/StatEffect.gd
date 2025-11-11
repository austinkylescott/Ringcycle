extends Resource
class_name StatEffect

@export var id: String
@export var label: String
@export var description: String

# One-time immediate changes when applied e.g {"strength": 5, "stamina": 3}
@export var instant_deltas: Dictionary = {}

# Ongoing multipliers that affect training/stat gain. e.g. {"strength": 1.2} = +20% gains
@export var growth_multiplier: Dictionary = {}

# 0 or <0 = permanent until explicitly removed.
@export var duration_days: int = 0

# "buff", "injury", "food", etc
@export var tags: Array[String] = []

# Stack behavior
@export var stacks: bool = false
