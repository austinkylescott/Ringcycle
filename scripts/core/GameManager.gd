extends Node
class_name GameManager

# ---------------------------------------------------------------------------
# GameManager — central game state autoload (GM).
#
# SINGLE SOURCE OF TRUTH FOR TIME:
#   advance_day() — the ONE function that advances both the world
#   calendar and the wrestler's lifespan. Called exactly once per in-game day
#   by either CalendarSystem (player) or CareerSimulator (sim). Nothing else
#   should ever call advance_day() or wrestler.age_one_day() directly.
#
# Calendar: tracks world timeline continuously, never resets.
# Lifespan: tracked on WrestlerResource (days_lived / lifespan_days).
#
# RosterManager integration:
#   RM.tick_day() is called once per advance_day() after the calendar tick.
#   RM.tick_week() is called once per week boundary after week_started fires.
# ---------------------------------------------------------------------------

var current_wrestler_res:  WrestlerResource
var current_wrestler_node: Wrestler

# World calendar — continuous, never resets
var day:   int = 1
var week:  int = 1
var month: int = 1
var year:  int = 1

# Coach queue — index 0 = primary, index 1 = secondary
var coaches: Array[CoachResource] = []

# Hall of Fame — all voluntarily retired wrestlers
var hall_of_fame: Array[CoachResource] = []

# Retire threshold — rolled per wrestler, fuzzy around 50%
var retire_option_unlocked: bool  = false
var _retire_threshold_pct:  float = 0.0

# ---------------------------------------------------------------------------
# Player contract state
# Empty strings mean the player is unsigned (indie / working the circuit).
# ---------------------------------------------------------------------------
var contracted_promotion_id: String = ""   # id of signed promotion, or ""
var contract_shows_attended: int    = 0    # shows attended under current contract

# ---------------------------------------------------------------------------
# Player relationship registry
# Keyed by NPC id. Value is a RelationshipRecord.
# All relationship reads/writes for the player wrestler go through GM
# so they persist across wrestler deaths and retirements.
# ---------------------------------------------------------------------------
var player_relationships: Dictionary = {}  # npc_id -> RelationshipRecord


signal day_advanced(day: int, week: int, month: int, year: int)
signal wrestler_changed(wrestler: Wrestler)
signal evolution_triggered(wrestler: Wrestler, new_stage: String)
signal coach_died(coach: CoachResource, slot: int)
signal coach_assigned(coach: CoachResource, slot: int)
signal wrestler_retired(wrestler: Wrestler, coach: CoachResource)
signal wrestler_died(wrestler: Wrestler)
signal retire_available()
signal week_started(wrestler: Wrestler)
signal contract_offered(promotion: PromotionResource)
signal contract_signed(promotion: PromotionResource)
signal contract_released(promotion_id: String)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

func _ready() -> void:
	_start_new_wrestler()


# ---------------------------------------------------------------------------
# THE single day-advance function.
# Advances both the wrestler's lifespan AND the world calendar exactly once.
# Returns true if the wrestler died this day (caller should stop and handle).
# ---------------------------------------------------------------------------

func advance_day() -> bool:
	var wrestler: Wrestler = current_wrestler_node
	if wrestler == null:
		return false

	# 1. Age the wrestler exactly once
	wrestler.age_one_day()

	# 2. Death check — if dead, retire and return true so caller can react
	if wrestler.is_dead():
		die_current_wrestler()
		return true

	# 3. Advance world calendar
	var prev_week: int = week
	_tick_calendar()

	# 4. Tick coaches
	_tick_coaches()

	# 5. Tick the world roster — NPC aging, death, anchor replacement
	if has_node("/root/RM"):
		var rm: RosterManager = get_node("/root/RM") as RosterManager
		if rm != null:
			rm.tick_day()

	# 6. Check evolution
	_check_evolution()

	# 7. Check retire threshold
	_check_retire_threshold()

	# 8. Week boundary — fire signal and tick week-level systems
	if week != prev_week:
		emit_signal("week_started", current_wrestler_node)
		_on_week_boundary()

	emit_signal("day_advanced", day, week, month, year)
	return false


# Internal calendar tick — only called from advance_day()
func _tick_calendar() -> void:
	day += 1
	if day > 7:
		day = 1
		week += 1
		if week > 4:
			week = 1
			month += 1
			if month > 12:
				month = 1
				year += 1


# Called once per week boundary from advance_day()
func _on_week_boundary() -> void:
	# Tick week-level roster logic (relationship decay, NPC promotion checks)
	if has_node("/root/RM"):
		var rm: RosterManager = get_node("/root/RM") as RosterManager
		if rm != null:
			rm.tick_week()

	# Decay player relationships
	_tick_player_relationships()

	# Check for contract offer eligibility
	_check_contract_offer()


# ---------------------------------------------------------------------------
# Player relationship management
# ---------------------------------------------------------------------------

# Returns the player's relationship record with a given NPC.
# Creates a new Stranger record if none exists.
func get_player_relationship(npc_id: String) -> RelationshipRecord:
	if not player_relationships.has(npc_id):
		var npc: NPCResource = null
		if has_node("/root/RM"):
			var rm: RosterManager = get_node("/root/RM") as RosterManager
			if rm != null:
				npc = rm.get_npc(npc_id)
		var npc_name: String = npc.display_name if npc != null else npc_id
		var rel: RelationshipRecord = RelationshipRecord.create(npc_id, npc_name, _absolute_week())
		player_relationships[npc_id] = rel
	return player_relationships[npc_id]


# Records a show interaction between the player and an NPC.
# Called by ShowManager after resolving each show event.
func record_player_interaction(npc_id: String, event_type: String) -> void:
	var rel: RelationshipRecord = get_player_relationship(npc_id)
	rel.record_interaction(event_type, _absolute_week())


func _tick_player_relationships() -> void:
	var current_week := _absolute_week()
	for rel in player_relationships.values():
		rel.tick_decay(current_week)


# Returns all player relationships sorted by intensity descending.
func get_player_relationships_sorted() -> Array:
	var rels := player_relationships.values()
	rels.sort_custom(func(a: RelationshipRecord, b: RelationshipRecord):
		return a.intensity > b.intensity
	)
	return rels


# Returns player relationships of a specific type.
func get_player_relationships_of_type(type: String) -> Array:
	return player_relationships.values().filter(
		func(r: RelationshipRecord): return r.type == type
	)


# ---------------------------------------------------------------------------
# Contract management
# ---------------------------------------------------------------------------

func sign_contract(promotion_id: String) -> void:
	contracted_promotion_id = promotion_id
	contract_shows_attended = 0
	var promo := _get_rm_promotion(promotion_id)
	if promo != null:
		emit_signal("contract_signed", promo)
		SL.log_event("CONTRACT SIGNED — %s" % promo.display_name)


func release_contract() -> void:
	var old_id := contracted_promotion_id
	contracted_promotion_id = ""
	contract_shows_attended = 0
	emit_signal("contract_released", old_id)


func is_contracted() -> bool:
	return contracted_promotion_id != ""


func get_contracted_promotion() -> PromotionResource:
	return _get_rm_promotion(contracted_promotion_id)


# ---------------------------------------------------------------------------
# Contract offer logic
# Called weekly. Checks if the player has earned a contract offer.
# Phase 1: one offer threshold per rank based on fame and wins.
# ---------------------------------------------------------------------------

func _check_contract_offer() -> void:
	# Already contracted — no new offers
	if is_contracted():
		return

	var wrestler: Wrestler = current_wrestler_node
	if wrestler == null:
		return

	var fame  := int(wrestler.get_stat("fame"))
	var rank  := _get_player_rank()

	# Fame threshold to attract a contract offer, per rank
	# These are low for Phase 1 — tune during playtesting
	var fame_threshold := _contract_fame_threshold(rank)
	if fame < fame_threshold:
		return

	# Find the appropriate promotion for the player's rank
	if not has_node("/root/RM"):
		return
	var rm: RosterManager = get_node("/root/RM") as RosterManager
	if rm == null:
		return

	var promo := rm.get_promotion_for_rank(rank)
	if promo == null:
		return

	# Don't offer repeatedly — check if we've offered this one recently
	# Phase 2 will track offer history; for now just emit once per fame threshold
	emit_signal("contract_offered", promo)
	SL.log_event("CONTRACT OFFER — %s (Fame: %d)" % [promo.display_name, fame])


func _contract_fame_threshold(rank: String) -> int:
	match rank:
		"E": return 15
		"D": return 30
		"C": return 45
		"B": return 60
		"A": return 75
		"S": return 90
	return 999


# Returns the player's current competitive rank based on fame.
# Phase 2 will use a more nuanced rank system tied to contracts and wins.
func _get_player_rank() -> String:
	var wrestler: Wrestler = current_wrestler_node
	if wrestler == null:
		return "E"
	var fame := int(wrestler.get_stat("fame"))
	if fame >= 85: return "S"
	if fame >= 70: return "A"
	if fame >= 55: return "B"
	if fame >= 40: return "C"
	if fame >= 20: return "D"
	return "E"


# Public accessor used by ShowManager and UI
func get_player_rank() -> String:
	return _get_player_rank()


# ---------------------------------------------------------------------------
# Wrestler creation
# ---------------------------------------------------------------------------

func _start_new_wrestler() -> void:
	_retire_threshold_pct  = randf_range(0.45, 0.55)
	retire_option_unlocked = false

	var rookies: Array = SR.get_all_species().filter(
		func(s: WrestlerSpeciesResource): return s.stage == "Rookie"
	)
	var valid_rookies: Array = rookies.filter(func(s: WrestlerSpeciesResource):
		return ES.get_line_for_species(s.id) != null
	)

	if not valid_rookies.is_empty():
		var species: WrestlerSpeciesResource = valid_rookies[randi() % valid_rookies.size()]
		var wr := create_wrestler_from_species(species)
		_load_wrestler_from_resource(wr)
		return

	push_warning("GameManager: no valid rookie species found with a complete evolution line")
	var default_wr          := WrestlerResource.new()
	default_wr.display_name = "Unknown"
	default_wr.stage        = "Rookie"
	default_wr.lifespan_days = 1825
	_load_wrestler_from_resource(default_wr)


func create_wrestler_from_species(species: WrestlerSpeciesResource) -> WrestlerResource:
	var wr         := WrestlerResource.new()
	wr.species      = species
	wr.stage        = "Rookie"
	wr.display_name = species.display_name

	for key in StatDefs.CORE:
		var base: int = species.base_stats.get(key, 40)
		wr.set(key, base + randi_range(-5, 5))

	wr.lifespan_days = _roll_lifespan(species)

	var all_personalities := PersonalityDefs.all_ids()
	var eligible := all_personalities.filter(func(p): return p != "legendary")
	wr.personality = eligible[randi() % eligible.size()]

	wr.training_session_counts = {}
	wr.personality_pressure    = {}
	wr.events_triggered        = []
	wr.items_consumed          = []
	wr.championships_held      = []

	return wr


func _roll_lifespan(species: WrestlerSpeciesResource) -> int:
	var roll := randi_range(-species.lifespan_variance, species.lifespan_variance)
	return max(species.lifespan_min, species.lifespan_base + roll)


func _load_wrestler_from_resource(res: WrestlerResource) -> void:
	current_wrestler_res = res
	if is_instance_valid(current_wrestler_node):
		current_wrestler_node.queue_free()
	current_wrestler_node = Wrestler.new()
	current_wrestler_node.apply_resource(res)
	emit_signal("wrestler_changed", current_wrestler_node)


# ---------------------------------------------------------------------------
# Retirement
# ---------------------------------------------------------------------------

func voluntary_retire() -> void:
	if current_wrestler_node == null:
		return

	var coach := CoachResource.from_wrestler(current_wrestler_node)
	add_to_hall_of_fame(coach)
	_assign_coach_to_queue(coach)

	SL.log_event("RETIRED — %s | Stage: %s | Coach bonus: %s +%d | Days remaining: %d" % [
		current_wrestler_node.get_display_name(),
		current_wrestler_node.get_stage(),
		coach.bonus_stat, coach.bonus_value,
		coach.days_remaining,
	])

	emit_signal("wrestler_retired", current_wrestler_node, coach)
	release_contract()
	_start_new_wrestler()


func die_current_wrestler() -> void:
	if current_wrestler_node == null:
		return

	SL.log_event("DIED — %s | Stage: %s | No coach created" % [
		current_wrestler_node.get_display_name(),
		current_wrestler_node.get_stage(),
	])

	emit_signal("wrestler_died", current_wrestler_node)
	release_contract()
	_start_new_wrestler()


# ---------------------------------------------------------------------------
# Retire threshold
# ---------------------------------------------------------------------------

func _check_retire_threshold() -> void:
	if retire_option_unlocked:
		return
	if current_wrestler_node == null:
		return

	var res := current_wrestler_node.res
	if res == null:
		return

	var original_lifespan := res.days_lived + res.lifespan_days
	if original_lifespan <= 0:
		return

	if res.days_lived >= original_lifespan * _retire_threshold_pct:
		retire_option_unlocked = true
		emit_signal("retire_available")


# ---------------------------------------------------------------------------
# Coach queue
# ---------------------------------------------------------------------------

func _assign_coach_to_queue(coach: CoachResource) -> void:
	if coaches.size() < 2:
		coaches.append(coach)
		emit_signal("coach_assigned", coach, coaches.size() - 1)
	else:
		coaches[1] = coach
		emit_signal("coach_assigned", coach, 1)


func get_primary_coach() -> CoachResource:
	return coaches[0] if coaches.size() > 0 else null


func get_secondary_coach() -> CoachResource:
	return coaches[1] if coaches.size() > 1 else null


func get_active_coaches() -> Array[CoachResource]:
	return coaches.duplicate()


func _promote_coaches() -> void:
	var alive: Array[CoachResource] = []
	for c in coaches:
		if c != null:
			alive.append(c)
	coaches = alive


func _tick_coaches() -> void:
	var died_indices: Array[int] = []
	for i in range(coaches.size()):
		coaches[i].days_remaining -= 1
		if coaches[i].days_remaining <= 0:
			died_indices.append(i)
	for i in died_indices:
		emit_signal("coach_died", coaches[i], i)
		coaches[i] = null
	if not died_indices.is_empty():
		_promote_coaches()


# ---------------------------------------------------------------------------
# Hall of Fame
# ---------------------------------------------------------------------------

func add_to_hall_of_fame(coach: CoachResource) -> void:
	hall_of_fame.append(coach)


# ---------------------------------------------------------------------------
# Evolution check
# ---------------------------------------------------------------------------

func _check_evolution() -> void:
	if current_wrestler_node == null:
		return
	var new_stage := ES.check_evolution(current_wrestler_node)
	if new_stage != "":
		emit_signal("evolution_triggered", current_wrestler_node, new_stage)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_rm_promotion(promo_id: String) -> PromotionResource:
	if promo_id == "" or not has_node("/root/RM"):
		return null
	var rm: RosterManager = get_node("/root/RM") as RosterManager
	if rm == null:
		return null
	return rm.get_promotion(promo_id)


func _absolute_week() -> int:
	return ((year - 1) * 48) + ((month - 1) * 4) + week


# ---------------------------------------------------------------------------
# Legacy shim — CalendarSystem used to call this
# ---------------------------------------------------------------------------

func retire_current_wrestler() -> void:
	die_current_wrestler()
