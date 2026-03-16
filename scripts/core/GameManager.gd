extends Node
class_name GameManager

# ---------------------------------------------------------------------------
# GameManager — central game state autoload (GM).
#
# SINGLE SOURCE OF TRUTH FOR TIME:
#   advance_day(wrestler) — the ONE function that advances both the world
#   calendar and the wrestler's lifespan. Called exactly once per in-game day
#   by either CalendarSystem (player) or CareerSimulator (sim). Nothing else
#   should ever call advance_day() or wrestler.age_one_day() directly.
#
# Calendar: tracks world timeline continuously, never resets.
# Lifespan: tracked on WrestlerResource (days_lived / lifespan_days).
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

signal day_advanced(day: int, week: int, month: int, year: int)
signal wrestler_changed(wrestler: Wrestler)
signal evolution_triggered(wrestler: Wrestler, new_stage: String)
signal coach_died(coach: CoachResource, slot: int)
signal coach_assigned(coach: CoachResource, slot: int)
signal wrestler_retired(wrestler: Wrestler, coach: CoachResource)
signal wrestler_died(wrestler: Wrestler)
signal retire_available()
# Fired when the week rolls over — used by CalendarSystem and CareerSimulator
# to call TrainingSystem.on_week_start()
signal week_started(wrestler: Wrestler)


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
	var wrestler := current_wrestler_node
	if wrestler == null:
		return false

	# 1. Age the wrestler exactly once
	wrestler.age_one_day()

	# 2. Death check — if dead, retire and return true so caller can react
	if wrestler.is_dead():
		die_current_wrestler()
		return true

	# 3. Advance world calendar
	var prev_week := week
	_tick_calendar()

	# 4. Tick coaches
	_tick_coaches()

	# 5. Check evolution
	_check_evolution()

	# 6. Check retire threshold
	_check_retire_threshold()

	# 7. Week boundary signal
	if week != prev_week:
		emit_signal("week_started", current_wrestler_node)

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
	_start_new_wrestler()


func die_current_wrestler() -> void:
	if current_wrestler_node == null:
		return

	SL.log_event("DIED — %s | Stage: %s | No coach created" % [
		current_wrestler_node.get_display_name(),
		current_wrestler_node.get_stage(),
	])

	emit_signal("wrestler_died", current_wrestler_node)
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
# Legacy shim — CalendarSystem used to call this
# ---------------------------------------------------------------------------

func retire_current_wrestler() -> void:
	die_current_wrestler()
