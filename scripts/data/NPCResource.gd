extends Resource
class_name NPCResource

# ---------------------------------------------------------------------------
# NPCResource — persistent data for one non-player wrestler.
#
# NPCs are not full Wrestler nodes. They exist as resources owned by
# RosterManager and are resolved against during shows. They age on the
# same day tick as the player wrestler via RosterManager.tick_day().
#
# Stat philosophy:
#   Battle stats (power, technique, agility, toughness, stamina, charisma)
#     — only matter inside a match. get_combat_score() uses these exclusively.
#   Out-of-battle stats (fame, morale, fatigue)
#     — affect the world outside the ring: promo resolution, contract offers,
#       training growth, prize payouts. Never touch match resolution.
#
# NPC categories:
#   "anchor"     — fixture of their rank tier. Replaced on death by a new
#                  procedurally generated anchor. Never promoted.
#   "career"     — parallel career NPC. Can rank up, retire, or die.
#                  Primary source of long-term rivals and allies.
#   "transient"  — short-term NPC generated to fill a program slot.
#                  May die or disappear after their program ends.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
@export var id: String = ""              # unique, e.g. "npc_0042"
@export var display_name: String = ""
@export var category: String = "career" # "anchor" | "career" | "transient"

# Current stage — mirrors WrestlerResource.stage
# Valid: "Rookie", "Pro", "Legend_A", "Legend_B", "Legend_C"
@export var stage: String = "Rookie"

# Rank tier this NPC currently competes at.
# Valid: "E", "D", "C", "B", "A", "S"
@export var rank: String = "E"

# Promotion id this NPC is signed to. Empty = unsigned / indie.
@export var promotion_id: String = ""

# Species id for flavour display and move pool reference.
@export var species_id: String = ""

# Personality id from PersonalityDefs.
@export var personality: String = "determined"


# ---------------------------------------------------------------------------
# Battle stats (0–999)
# Only used inside match resolution via get_combat_score().
# ---------------------------------------------------------------------------
@export var power: int      = 40
@export var technique: int  = 40
@export var agility: int    = 40
@export var toughness: int  = 40
@export var stamina: int    = 40
@export var charisma: int   = 40


# ---------------------------------------------------------------------------
# Out-of-battle stats
# Never used in match resolution.
# ---------------------------------------------------------------------------
@export var fatigue: int = 0    # 0–100, affects NPC training sim (future use)
@export var morale: int  = 50   # 0–100, affects NPC training sim (future use)
@export var fame: int    = 0    # 0–100, drives promo resolution and opportunities


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
@export var lifespan_days: int = 1825
@export var days_lived: int    = 0


# ---------------------------------------------------------------------------
# Career tracking
# ---------------------------------------------------------------------------
@export var wins: int   = 0
@export var losses: int = 0
@export var championships_held: Array[String] = []
@export var events_triggered: Array[String]   = []


# ---------------------------------------------------------------------------
# Relationships
# Keyed by target id (player wrestler res id or another NPC id).
# Value is a RelationshipRecord resource.
# ---------------------------------------------------------------------------
@export var relationships: Dictionary = {}


# ---------------------------------------------------------------------------
# Stat helpers
# ---------------------------------------------------------------------------

func get_stat(key: String) -> float:
	match key:
		"power":         return float(power)
		"technique":     return float(technique)
		"agility":       return float(agility)
		"toughness":     return float(toughness)
		"stamina":       return float(stamina)
		"charisma":      return float(charisma)
		"fatigue":       return float(fatigue)
		"morale":        return float(morale)
		"fame":          return float(fame)
		"days_lived":    return float(days_lived)
		"lifespan_days": return float(lifespan_days)
	push_warning("NPCResource.get_stat: unknown key '%s'" % key)
	return 0.0


func set_stat(key: String, value: float) -> void:
	var clamped: float = StatDefs.clamp_value(key, value)
	match key:
		"power":         power         = int(clamped)
		"technique":     technique     = int(clamped)
		"agility":       agility       = int(clamped)
		"toughness":     toughness     = int(clamped)
		"stamina":       stamina       = int(clamped)
		"charisma":      charisma      = int(clamped)
		"fatigue":       fatigue       = int(clamped)
		"morale":        morale        = int(clamped)
		"fame":          fame          = int(clamped)
		"days_lived":    days_lived    = int(clamped)
		"lifespan_days": lifespan_days = int(clamped)
		_:
			push_warning("NPCResource.set_stat: unknown key '%s'" % key)


func add_to_stat(key: String, delta: float) -> void:
	set_stat(key, get_stat(key) + delta)


# ---------------------------------------------------------------------------
# Lifecycle helpers
# ---------------------------------------------------------------------------

func is_dead() -> bool:
	return lifespan_days <= 0


func age_one_day() -> void:
	days_lived    += 1
	lifespan_days  = max(0, lifespan_days - 1)


# ---------------------------------------------------------------------------
# Combat score — BATTLE STATS ONLY
#
# Used by ShowManager for match resolution.
# Weighted sum of the six battle stats scaled by personality modifier
# and fatigue penalty.
#
# Charisma weight is intentionally small and provisional — its exact
# combat role will be defined when the combat system is designed.
#
# Weights:
#   technique  0.25  — precision and ring smarts are primary
#   power      0.25  — raw strength is equally primary
#   stamina    0.20  — endurance shapes the late match
#   toughness  0.15  — damage mitigation
#   agility    0.10  — speed and evasion
#   charisma   0.05  — provisional; combat role TBD
#
# Fame is NEVER included here.
# ---------------------------------------------------------------------------

func get_combat_score() -> float:
	var base: float = (
		float(technique) * 0.25 +
		float(power)     * 0.25 +
		float(stamina)   * 0.20 +
		float(toughness) * 0.15 +
		float(agility)   * 0.10 +
		float(charisma)  * 0.05
	)

	# Personality modifier averaged across all battle stats
	var personality_bonus: float = 0.0
	for stat in StatDefs.CORE:
		personality_bonus += float(PersonalityDefs.get_modifier(personality, stat))
	personality_bonus /= float(StatDefs.CORE.size())
	base *= (1.0 + personality_bonus * 0.1)

	# Fatigue penalty — physical wear affects in-ring performance
	# even though fatigue is an out-of-battle stat
	var fatigue_factor: float = lerp(1.0, 0.3, float(fatigue) / 100.0)
	base *= fatigue_factor

	return base


# ---------------------------------------------------------------------------
# Promo score — OUT-OF-BATTLE STATS ONLY
#
# Used by ShowManager for promo segment resolution.
# Driven by fame as primary factor, personality as modifier,
# morale as effort multiplier. Battle stats play no role here.
#
# Returns a 0.0–1.0 score where:
#   0.0–0.25  → "heat"   (crowd turns on them)
#   0.25–0.50 → "flat"   (fails to connect)
#   0.50–0.75 → "decent" (solid promo)
#   0.75–1.0  → "strong" (commanding performance)
# ---------------------------------------------------------------------------

func get_promo_score() -> float:
	var fame_factor: float     = float(fame) / 100.0
	var personality_mod: float = _promo_personality_modifier()
	var morale_factor: float   = lerp(0.8, 1.1, float(morale) / 100.0)
	return clamp(fame_factor * morale_factor + personality_mod, 0.0, 1.0)


func _promo_personality_modifier() -> float:
	match personality:
		"showman":    return  0.20
		"passionate": return  0.15
		"confident":  return  0.15
		"cunning":    return  0.10
		"proud":      return  0.05
		"anxious":    return -0.15
		"melancholy": return -0.10
		"bitter":     return -0.10
		"lethargic":  return -0.05
	return 0.0


# ---------------------------------------------------------------------------
# Convenience display helpers
# ---------------------------------------------------------------------------

func get_personality_display() -> String:
	return PersonalityDefs.get_display_name(personality)


func get_record_display() -> String:
	return "%d-%d" % [wins, losses]


func get_win_rate() -> float:
	var total: int = wins + losses
	if total == 0:
		return 0.5
	return float(wins) / float(total)
