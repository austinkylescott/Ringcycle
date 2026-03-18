extends Node
class_name RosterManager

# ---------------------------------------------------------------------------
# RosterManager — autoload alias "RM"
#
# Owns all NPCs and Promotions in the game world. Responsible for:
#   - Generating the initial world roster at game start
#   - Aging all NPCs on the day tick (called by GameManager.advance_day)
#   - Replacing dead anchors with fresh generated NPCs
#   - Promoting career NPCs when they meet rank-up criteria
#   - Providing query API for ShowManager and UI systems
#
# Add to project.godot autoloads:
#   RM="*res://scripts/core/RosterManager.gd"
#
# Depends on: SR (SpeciesRegistry), PersonalityDefs, StatDefs
#
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# World configuration
# Tunable constants for roster density per rank tier.
# ---------------------------------------------------------------------------

# How many anchor NPCs exist per rank tier at all times.
const ANCHORS_PER_RANK := 2

# How many career NPCs start per rank tier.
const CAREER_PER_RANK := 4

# How many transient NPC slots exist per rank tier.
# Filled on demand by ShowManager when a program needs a new face.
const TRANSIENT_SLOTS_PER_RANK := 2

# Stat floor and ceiling per rank tier.
# NPCs are generated with stats in this range.
const RANK_STAT_RANGES := {
	"E": { "min": 20,  "max": 80  },
	"D": { "min": 60,  "max": 140 },
	"C": { "min": 120, "max": 220 },
	"B": { "min": 180, "max": 320 },
	"A": { "min": 280, "max": 450 },
	"S": { "min": 400, "max": 600 },
}

# Fame floor per rank — NPCs arrive already having some notoriety.
const RANK_FAME_FLOOR := {
	"E": 0,  "D": 10, "C": 25,
	"B": 40, "A": 60, "S": 75,
}

# Lifespan range in days per rank tier.
# Higher ranked NPCs tend to be veterans — shorter remaining lifespan.
const RANK_LIFESPAN_RANGES := {
	"E": { "min": 365,  "max": 2190 },
	"D": { "min": 365,  "max": 2190 },
	"C": { "min": 547,  "max": 2555 },
	"B": { "min": 730,  "max": 2920 },
	"A": { "min": 365,  "max": 2190 },
	"S": { "min": 180,  "max": 1095 },
}

# Rank promotion thresholds — career NPCs check these weekly.
const RANK_PROMOTION_WIN_RATE := 0.65   # must win 65% of matches
const RANK_PROMOTION_MIN_WINS := 10     # must have at least N wins at current rank
const RANK_PROMOTION_FAME     := 30     # must have fame >= this value

# ---------------------------------------------------------------------------
# Rank order — used for promotion logic
# ---------------------------------------------------------------------------
const RANK_ORDER := ["E", "D", "C", "B", "A", "S"]

# ---------------------------------------------------------------------------
# NPC id counter — incremented for every NPC ever created this session.
# ---------------------------------------------------------------------------
var _npc_counter: int = 0

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

# All living NPCs. id -> NPCResource
var _npcs: Dictionary = {}

# All promotions. id -> PromotionResource
var _promotions: Dictionary = {}

# Anchor slot registry — rank -> Array[npc_id]
# Always kept at ANCHORS_PER_RANK length by replacing dead anchors.
var _anchors: Dictionary = {}

# Signals
signal npc_died(npc: NPCResource)
signal npc_promoted(npc: NPCResource, old_rank: String, new_rank: String)
signal anchor_replaced(old_npc: NPCResource, new_npc: NPCResource, rank: String)
signal promotion_created(promo: PromotionResource)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

func _ready() -> void:
	_generate_world()
	print("[RosterManager] World generated: %d NPCs, %d promotions" % [
		_npcs.size(), _promotions.size()
	])


func _generate_world() -> void:
	# Generate one promotion per rank tier
	for rank in RANK_ORDER:
		var promo: PromotionResource = _generate_promotion(rank)
		_promotions[promo.id] = promo
		emit_signal("promotion_created", promo)

	# Generate anchors and career NPCs for each rank
	for rank in RANK_ORDER:
		_anchors[rank] = []
		var promo: PromotionResource = get_promotion_for_rank(rank)

		# Anchors
		for _i in range(ANCHORS_PER_RANK):
			var npc: NPCResource = _generate_npc(rank, "anchor")
			_register_npc(npc, promo)
			_anchors[rank].append(npc.id)

		# Career NPCs
		for _i in range(CAREER_PER_RANK):
			var npc: NPCResource = _generate_npc(rank, "career")
			_register_npc(npc, promo)


# ---------------------------------------------------------------------------
# Day tick — called by GameManager.advance_day()
# ---------------------------------------------------------------------------

func tick_day() -> void:
	var dead_ids: Array[String] = []

	for npc_id in _npcs.keys():
		var npc: NPCResource = _npcs[npc_id]
		npc.age_one_day()
		if npc.is_dead():
			dead_ids.append(npc_id)

	for npc_id in dead_ids:
		_handle_npc_death(npc_id)

	# Tick championship reigns
	for promo in _promotions.values():
		promo.tick_championship_reigns()


# ---------------------------------------------------------------------------
# Week tick — called by CalendarSystem / CareerSimulator on week boundary
# ---------------------------------------------------------------------------

func tick_week() -> void:
	# Decay all relationships between NPCs (player relationships
	# are decayed by ShowManager after each show)
	for npc in _npcs.values():
		for rel in npc.relationships.values():
			rel.tick_decay(_absolute_week())

	# Check career NPCs for rank promotion
	for npc in _npcs.values():
		if npc.category == "career":
			_check_npc_promotion(npc)


# ---------------------------------------------------------------------------
# NPC death handling
# ---------------------------------------------------------------------------

func _handle_npc_death(npc_id: String) -> void:
	var npc: NPCResource = _npcs[npc_id]

	# Remove from promotion roster
	var promo: PromotionResource = get_promotion_for_rank(npc.rank)
	if promo != null:
		promo.release_npc(npc_id)

	emit_signal("npc_died", npc)

	# If this was an anchor, replace it immediately
	if npc.category == "anchor":
		_replace_anchor(npc)

	# Remove from registry last
	_npcs.erase(npc_id)


func _replace_anchor(dead_npc: NPCResource) -> void:
	var rank := dead_npc.rank
	var new_npc := _generate_npc(rank, "anchor")
	var promo: PromotionResource = get_promotion_for_rank(rank)
	_register_npc(new_npc, promo)

	# Update anchor slot
	var slot_idx: int = _anchors[rank].find(dead_npc.id)
	if slot_idx >= 0:
		_anchors[rank][slot_idx] = new_npc.id

	emit_signal("anchor_replaced", dead_npc, new_npc, rank)
	print("[RosterManager] Anchor replaced at %s rank: %s → %s" % [
		rank, dead_npc.display_name, new_npc.display_name
	])


# ---------------------------------------------------------------------------
# NPC rank promotion
# ---------------------------------------------------------------------------

func _check_npc_promotion(npc: NPCResource) -> void:
	# Anchors never promote
	if npc.category == "anchor":
		return

	# Already at max rank
	var rank_idx := RANK_ORDER.find(npc.rank)
	if rank_idx >= RANK_ORDER.size() - 1:
		return

	# Check thresholds
	if npc.get_win_rate() < RANK_PROMOTION_WIN_RATE:
		return
	if npc.wins < RANK_PROMOTION_MIN_WINS:
		return
	if npc.fame < RANK_PROMOTION_FAME:
		return

	var old_rank := npc.rank
	var new_rank: String = RANK_ORDER[rank_idx + 1]

	# Move to new promotion
	var old_promo := get_promotion_for_rank(old_rank)
	var new_promo := get_promotion_for_rank(new_rank)

	if old_promo != null:
		old_promo.release_npc(npc.id)
	if new_promo != null and new_promo.has_roster_space():
		new_promo.sign_npc(npc.id)
		npc.rank = new_rank
		npc.promotion_id = new_promo.id
		# Stat boost on promotion — they're now competing at a higher level
		_apply_promotion_stat_boost(npc, new_rank)
		emit_signal("npc_promoted", npc, old_rank, new_rank)
		print("[RosterManager] %s promoted from %s to %s" % [
			npc.display_name, old_rank, new_rank
		])


func _apply_promotion_stat_boost(npc: NPCResource, new_rank: String) -> void:
	# Small boost to bring stats closer to the new rank's floor
	var range_data: Dictionary = RANK_STAT_RANGES[new_rank]
	var floor: int = range_data["min"]
	for stat in StatDefs.CORE:
		var current := int(npc.get_stat(stat))
		if current < floor:
			npc.set_stat(stat, float(floor + randi_range(0, 10)))


# ---------------------------------------------------------------------------
# NPC generation
# ---------------------------------------------------------------------------

func _generate_npc(rank: String, category: String) -> NPCResource:
	var npc       := NPCResource.new()
	npc.id         = _next_npc_id()
	npc.category   = category
	npc.rank       = rank
	npc.stage      = "Rookie"  # All generated NPCs start as Rookies stat-wise

	# Pick a random species for flavour
	var all_species := SR.get_all_species()
	var rookie_species := all_species.filter(
		func(s: WrestlerSpeciesResource): return s.stage == "Rookie"
	)
	if not rookie_species.is_empty():
		var species: WrestlerSpeciesResource = rookie_species[randi() % rookie_species.size()]
		npc.species_id    = species.id
		npc.display_name  = _generate_npc_name(species.display_name, rank)
	else:
		npc.display_name  = _generate_npc_name("", rank)
		npc.species_id    = ""

	# Stats — random within rank range
	var range_data: Dictionary = RANK_STAT_RANGES[rank]
	var stat_min: int = range_data["min"]
	var stat_max: int = range_data["max"]

	for stat in StatDefs.CORE:
		npc.set_stat(stat, float(randi_range(stat_min, stat_max)))

	# Support stats
	npc.set_stat("fatigue", 0.0)
	npc.set_stat("morale",  float(randi_range(40, 80)))
	npc.set_stat("fame",    float(RANK_FAME_FLOOR[rank] + randi_range(0, 20)))

	# Personality
	var personalities := PersonalityDefs.all_ids().filter(func(p): return p != "legendary")
	npc.personality = personalities[randi() % personalities.size()]

	# Lifespan
	var lifespan_range: Dictionary = RANK_LIFESPAN_RANGES[rank]
	npc.lifespan_days = randi_range(lifespan_range["min"], lifespan_range["max"])
	npc.days_lived    = 0

	# Anchors start mid-career — they've been around a while
	if category == "anchor":
		var age := randi_range(180, 730)
		npc.days_lived    = age
		npc.lifespan_days = max(180, npc.lifespan_days - age)
		npc.wins          = randi_range(10, 60)
		npc.losses        = randi_range(5, 40)

	return npc


func _register_npc(npc: NPCResource, promo: PromotionResource) -> void:
	_npcs[npc.id] = npc
	if promo != null and promo.has_roster_space():
		promo.sign_npc(npc.id)
		npc.promotion_id = promo.id


# ---------------------------------------------------------------------------
# Transient NPC generation
# Called by ShowManager when a program needs a fresh opponent.
# ---------------------------------------------------------------------------

func generate_transient_opponent(rank: String) -> NPCResource:
	var npc: NPCResource = _generate_npc(rank, "transient")
	var promo: PromotionResource = get_promotion_for_rank(rank)
	_register_npc(npc, promo)
	return npc


# ---------------------------------------------------------------------------
# Promotion generation
# ---------------------------------------------------------------------------

func _generate_promotion(rank: String) -> PromotionResource:
	var promo          := PromotionResource.new()
	promo.id            = "promo_%s_001" % rank.to_lower()
	promo.rank          = rank
	promo.prestige      = _rank_to_prestige(rank)
	promo.roster_cap    = 12 + (RANK_ORDER.find(rank) * 2)
	promo.weekly_show_count = 1 if RANK_ORDER.find(rank) < 3 else 2
	promo.ple_week      = 4
	promo.show_day      = 6

	# Generate name and show names
	var names := _promotion_names_for_rank(rank)
	promo.display_name  = names["full"]
	promo.short_name    = names["short"]
	promo.ple_name      = names["ple"]
	promo.description   = names["description"]

	# Add one championship
	var champ                  := PromotionResource.ChampionshipRecord.new()
	champ.id                    = "%s_heavyweight" % promo.short_name.to_lower()
	champ.display_name          = "%s Heavyweight Championship" % promo.short_name
	champ.champion_id           = ""
	promo.championships.append(champ)

	return promo


func _rank_to_prestige(rank: String) -> float:
	match rank:
		"E": return 0.5
		"D": return 0.75
		"C": return 1.0
		"B": return 1.25
		"A": return 1.5
		"S": return 2.0
	return 1.0


# ---------------------------------------------------------------------------
# Name generation
# Procedural promotion and NPC names — placeholder quality for Phase 1.
# Replace with a richer name table in Phase 2.
# ---------------------------------------------------------------------------

const PROMOTION_PREFIXES := [
	"Irongate", "Steelchain", "Thunderdome", "Crimson", "Vortex",
	"Apex", "Nexus", "Pinnacle", "Sovereign", "Eclipse",
]

const PROMOTION_SUFFIXES := [
	"Wrestling", "Combat", "Championship Wrestling", "Fight League",
	"Pro Wrestling", "Athletic", "Grappling Alliance",
]

const PROMOTION_PLE_NAMES := [
	"Reckoning", "Supremacy", "Battleground", "Collision",
	"Final Hour", "Ascension", "Dominion", "Reckoning Night",
]

const NPC_GIVEN_NAMES := [
	"Rex", "Grim", "Stone", "Blaze", "Iron", "Duke", "Sable",
	"Vex", "Kade", "Rook", "Flint", "Bolt", "Crane", "Wolf",
	"Ash", "Dusk", "Raze", "Pike", "Thorn", "Brax",
]

const NPC_SURNAMES := [
	"Harrow", "Dread", "Vale", "Cross", "Storm", "Morrow",
	"Slade", "Kane", "Ford", "Black", "Drake", "Stone",
	"Vane", "Colt", "Rush", "Hart", "Steele", "Graves",
]


func _promotion_names_for_rank(rank: String) -> Dictionary:
	var prefix: String = PROMOTION_PREFIXES[randi() % PROMOTION_PREFIXES.size()]
	var suffix: String = PROMOTION_SUFFIXES[randi() % PROMOTION_SUFFIXES.size()]
	var ple: String    = PROMOTION_PLE_NAMES[randi() % PROMOTION_PLE_NAMES.size()]

	var full  := "%s %s" % [prefix, suffix]
	var short := "%s%s" % [prefix.substr(0, 2).to_upper(), rank]

	var descriptions := {
		"E": "A local indie circuit where careers begin.",
		"D": "A regional promotion building toward national recognition.",
		"C": "An established national promotion with a loyal fanbase.",
		"B": "A major promotion with TV exposure and international reach.",
		"A": "One of the top promotions in the world.",
		"S": "The pinnacle of the sport. Every title here means everything.",
	}

	return {
		"full":        full,
		"short":       short,
		"ple":         "%s %s" % [prefix, ple],
		"description": descriptions.get(rank, ""),
	}


func _generate_npc_name(species_name: String, _rank: String) -> String:
	var given:   String = NPC_GIVEN_NAMES[randi() % NPC_GIVEN_NAMES.size()]
	var surname: String = NPC_SURNAMES[randi() % NPC_SURNAMES.size()]

	# Occasionally use the species name as a nickname
	if species_name != "" and randf() < 0.3:
		return '"%s" %s %s' % [species_name, given, surname]

	return "%s %s" % [given, surname]


func _next_npc_id() -> String:
	_npc_counter += 1
	return "npc_%04d" % _npc_counter


# ---------------------------------------------------------------------------
# Query API — used by ShowManager and UI
# ---------------------------------------------------------------------------

# Returns an NPC by id, or null.
func get_npc(npc_id: String) -> NPCResource:
	return _npcs.get(npc_id, null)


# Returns all living NPCs.
func get_all_npcs() -> Array:
	return _npcs.values()


# Returns all NPCs at a given rank.
func get_npcs_at_rank(rank: String) -> Array:
	return _npcs.values().filter(func(n: NPCResource): return n.rank == rank)


# Returns all NPCs in a given promotion.
func get_npcs_in_promotion(promo_id: String) -> Array:
	return _npcs.values().filter(func(n: NPCResource): return n.promotion_id == promo_id)


# Returns a promotion by id, or null.
func get_promotion(promo_id: String) -> PromotionResource:
	return _promotions.get(promo_id, null)


# Returns all promotions.
func get_all_promotions() -> Array:
	return _promotions.values()


# Returns the (first) promotion at a given rank tier.
# Phase 2 will handle multiple promotions per rank.
func get_promotion_for_rank(rank: String) -> PromotionResource:
	for promo in _promotions.values():
		if promo.rank == rank:
			return promo
	return null


# Returns the anchor NPCs for a given rank.
func get_anchors_for_rank(rank: String) -> Array:
	var anchor_ids: Array = _anchors.get(rank, [])
	var result: Array = []
	for npc_id in anchor_ids:
		var npc := get_npc(npc_id)
		if npc != null:
			result.append(npc)
	return result


# Returns a random NPC from a given rank, excluding a specific id.
# Used by ShowManager to pick opponents.
func get_random_opponent(rank: String, exclude_id: String = "") -> NPCResource:
	var pool := get_npcs_at_rank(rank).filter(
		func(n: NPCResource): return n.id != exclude_id
	)
	if pool.is_empty():
		# Fall back to generating a transient if nobody is available
		return generate_transient_opponent(rank)
	return pool[randi() % pool.size()]


# ---------------------------------------------------------------------------
# Absolute week counter helper
# Converts GM calendar into a monotonically increasing week number.
# ---------------------------------------------------------------------------

func _absolute_week() -> int:
	# GM.year and GM.month are 1-based, GM.week is 1-4
	return ((GM.year - 1) * 48) + ((GM.month - 1) * 4) + GM.week
