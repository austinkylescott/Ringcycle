extends Resource
class_name RelationshipRecord

# ---------------------------------------------------------------------------
# RelationshipRecord — the relationship between two wrestlers (or NPC pairs).
#
# Stored in NPCResource.relationships and on GameManager for the player
# wrestler's relationships. Keyed by the OTHER party's id.
#
# Relationship types reflect the wrestling context:
#   "stranger"       — no meaningful history yet
#   "acquaintance"   — have shared a card, no program yet
#   "ally"           — currently allied, will not feud
#   "rival"          — active competitive rivalry, no personal heat
#   "enemy"          — personal animosity, feud heat
#   "nemesis"        — long-standing deep hatred, career-defining
#   "mentor"         — one party has coached or guided the other
#   "protege"        — inverse of mentor
#   "former_partner" — were allies, now separated (volatile state)
#
# Intensity drives program generation priority:
#   Low intensity  (<25)  — background, unlikely to get a program
#   Mid intensity  (25–60)— eligible for a program slot
#   High intensity (>60)  — priority program candidate
#
# History is a lightweight event log. Each entry is a Dictionary:
#   { "week": int, "event": String, "outcome": String }
# e.g. { "week": 14, "event": "match", "outcome": "player_won_dominant" }
#
# Phase 2 will expand history into full beat records for program generation.
# ---------------------------------------------------------------------------

# Relationship type — see type constants above.
@export var type: String = "stranger"

# Intensity — 0.0 to 100.0.
# Rises through interaction, decays slowly without it.
@export var intensity: float = 0.0

# The id of the OTHER party in this relationship.
# The owner of this record is implied by who holds it.
@export var other_id: String = ""

# Display name of the other party — cached for UI convenience.
@export var other_display_name: String = ""

# Week number (GM.week absolute counter) when this relationship was created.
@export var formed_week: int = 0

# Week number of last meaningful interaction.
@export var last_interaction_week: int = 0

# Lightweight history log. Capped at MAX_HISTORY_ENTRIES.
@export var history: Array = []  # Array[Dictionary]

const MAX_HISTORY_ENTRIES := 20

# Whether this relationship has been seen/acknowledged by the player.
# Used to flag new relationships for UI notification.
@export var is_new: bool = true


# ---------------------------------------------------------------------------
# Type constants — use these instead of raw strings in code
# ---------------------------------------------------------------------------
const TYPE_STRANGER        := "stranger"
const TYPE_ACQUAINTANCE    := "acquaintance"
const TYPE_ALLY            := "ally"
const TYPE_RIVAL           := "rival"
const TYPE_ENEMY           := "enemy"
const TYPE_NEMESIS         := "nemesis"
const TYPE_MENTOR          := "mentor"
const TYPE_PROTEGE         := "protege"
const TYPE_FORMER_PARTNER  := "former_partner"

# Types that allow friendly program beats
const FRIENDLY_TYPES := [TYPE_ALLY, TYPE_MENTOR, TYPE_PROTEGE]

# Types that allow heat-based program beats
const HEAT_TYPES := [TYPE_RIVAL, TYPE_ENEMY, TYPE_NEMESIS, TYPE_FORMER_PARTNER]


# ---------------------------------------------------------------------------
# Absolute week counter for decay calculations.
# Set from GM.week each time a record is accessed — avoids passing GM around.
# ---------------------------------------------------------------------------
var _current_week: int = 0


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

static func create(
	other_id_: String,
	other_name: String,
	formed_week_: int
) -> RelationshipRecord:
	var r: RelationshipRecord = RelationshipRecord.new()
	r.other_id           = other_id_
	r.other_display_name = other_name
	r.formed_week        = formed_week_
	r.last_interaction_week = formed_week_
	r.type      = TYPE_STRANGER
	r.intensity = 0.0
	r.is_new    = true
	return r


# ---------------------------------------------------------------------------
# Interaction — call after every show event involving both parties
# ---------------------------------------------------------------------------

# Records a show event and adjusts intensity and type.
# event_type: "match_win", "match_loss", "match_draw",
#             "promo_ally", "promo_confrontation", "interference_for",
#             "interference_against", "tag_partner"
# current_week: pass GM.week (or equivalent absolute week counter)
func record_interaction(event_type: String, current_week: int) -> void:
	last_interaction_week = current_week
	_current_week = current_week
	is_new = false

	var delta := _intensity_delta(event_type)
	intensity = clamp(intensity + delta, 0.0, 100.0)

	_append_history(current_week, event_type)
	_update_type(event_type)


# ---------------------------------------------------------------------------
# Decay — call weekly (on_week_start equivalent)
# Relationships fade without interaction.
# ---------------------------------------------------------------------------

func tick_decay(current_week: int) -> void:
	_current_week = current_week
	var weeks_since := current_week - last_interaction_week

	# No decay for the first 2 weeks of inactivity
	if weeks_since <= 2:
		return

	# Nemesis and mentor relationships decay much more slowly
	var decay_rate: float = 1.5
	match type:
		TYPE_NEMESIS, TYPE_MENTOR, TYPE_PROTEGE:
			decay_rate = 0.3
		TYPE_ENEMY:
			decay_rate = 0.8
		TYPE_FORMER_PARTNER:
			decay_rate = 1.0

	intensity = max(0.0, intensity - decay_rate)

	# If intensity drops to zero, type regresses toward stranger
	if intensity <= 0.0 and type not in [TYPE_NEMESIS, TYPE_MENTOR, TYPE_PROTEGE]:
		type = TYPE_STRANGER if type == TYPE_ACQUAINTANCE else TYPE_ACQUAINTANCE


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

func is_friendly() -> bool:
	return type in FRIENDLY_TYPES

func has_heat() -> bool:
	return type in HEAT_TYPES

func is_high_priority() -> bool:
	return intensity >= 60.0

func is_program_eligible() -> bool:
	return intensity >= 25.0 and type != TYPE_STRANGER


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _intensity_delta(event_type: String) -> float:
	match event_type:
		"match_win":              return 8.0
		"match_loss":             return 6.0
		"match_draw":             return 5.0
		"promo_ally":             return 4.0
		"promo_confrontation":    return 10.0
		"interference_for":       return 6.0
		"interference_against":   return 12.0
		"tag_partner":            return 5.0
	return 2.0


func _update_type(event_type: String) -> void:
	match event_type:
		"interference_against":
			# Escalate heat
			match type:
				TYPE_STRANGER, TYPE_ACQUAINTANCE:
					type = TYPE_RIVAL
				TYPE_RIVAL:
					if intensity >= 50.0:
						type = TYPE_ENEMY
				TYPE_ENEMY:
					if intensity >= 75.0:
						type = TYPE_NEMESIS
				TYPE_ALLY, TYPE_FORMER_PARTNER:
					type = TYPE_ENEMY  # Betrayal
		"tag_partner", "interference_for", "promo_ally":
			# Build alliance
			match type:
				TYPE_STRANGER:
					type = TYPE_ACQUAINTANCE
				TYPE_ACQUAINTANCE:
					if intensity >= 20.0:
						type = TYPE_ALLY
		"match_win", "match_loss", "match_draw":
			# Competitive history builds rivalry
			match type:
				TYPE_STRANGER:
					type = TYPE_ACQUAINTANCE
				TYPE_ACQUAINTANCE:
					if intensity >= 30.0:
						type = TYPE_RIVAL
				TYPE_RIVAL:
					if intensity >= 65.0:
						type = TYPE_ENEMY


func _append_history(week: int, event: String) -> void:
	history.append({ "week": week, "event": event })
	if history.size() > MAX_HISTORY_ENTRIES:
		history.pop_front()


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

func get_type_display() -> String:
	match type:
		TYPE_STRANGER:       return "Stranger"
		TYPE_ACQUAINTANCE:   return "Acquaintance"
		TYPE_ALLY:           return "Ally"
		TYPE_RIVAL:          return "Rival"
		TYPE_ENEMY:          return "Enemy"
		TYPE_NEMESIS:        return "Nemesis"
		TYPE_MENTOR:         return "Mentor"
		TYPE_PROTEGE:        return "Protégé"
		TYPE_FORMER_PARTNER: return "Former Partner"
	return type.capitalize()


func get_intensity_display() -> String:
	if intensity < 20.0:   return "Faint"
	if intensity < 40.0:   return "Developing"
	if intensity < 60.0:   return "Established"
	if intensity < 80.0:   return "Strong"
	return "Defining"
