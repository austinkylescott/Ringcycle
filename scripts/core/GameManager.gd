extends Node
class_name GameManager

# ---------------------------------------------------------------------------
# GameManager is the central game state autoload (alias: GM).
# It owns the active wrestler, coaching staff, calendar, and Hall of Fame.
#
# Other systems access it via the GM autoload:
#   GM.current_wrestler_node
#   GM.primary_coach / GM.secondary_coach
#   GM.day / GM.week / GM.month / GM.year
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Active wrestler
# ---------------------------------------------------------------------------
var current_wrestler_res:  WrestlerResource
var current_wrestler_node: Wrestler


# ---------------------------------------------------------------------------
# Calendar
# day   1–7   (1 = Monday)
# week  1–4   (weeks within the current month)
# month 1–12
# year  1+
# ---------------------------------------------------------------------------
var day:   int = 1
var week:  int = 1
var month: int = 1
var year:  int = 1


# ---------------------------------------------------------------------------
# Coaching staff
# Two permanent slots. Null means the slot is vacant.
# ---------------------------------------------------------------------------
var primary_coach:   CoachResource = null
var secondary_coach: CoachResource = null


# ---------------------------------------------------------------------------
# Hall of Fame
# All retired monsters — whether assigned as coaches or not.
# Never cleared during a playthrough.
# ---------------------------------------------------------------------------
var hall_of_fame: Array[CoachResource] = []


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal day_advanced(day: int, week: int, month: int, year: int)
signal wrestler_changed(wrestler: Wrestler)
signal evolution_triggered(wrestler: Wrestler, new_stage: String)
signal coach_died(coach: CoachResource, slot: String)
signal coach_assigned(coach: CoachResource, slot: String)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

func _ready() -> void:
	var sr: SpeciesRegistry = _get_species_registry()

	if sr != null:
		var species := sr.get_species("rookie")
		if species != null:
			var wr := create_wrestler_from_species(species)
			_load_wrestler_from_resource(wr)
			return

		var any := sr.get_any_species()
		if any != null:
			var wr2 := create_wrestler_from_species(any)
			_load_wrestler_from_resource(wr2)
			return

	# Final fallback — in-memory default
	var default_wr        := WrestlerResource.new()
	default_wr.display_name = "Rookie"
	default_wr.stage        = "Rookie"
	default_wr.lifespan_days = 1825
	_load_wrestler_from_resource(default_wr)


# ---------------------------------------------------------------------------
# Wrestler creation
# ---------------------------------------------------------------------------

func create_wrestler_from_species(species: WrestlerSpeciesResource) -> WrestlerResource:
	var wr      := WrestlerResource.new()
	wr.species   = species
	wr.stage     = "Rookie"

	# Apply base stats with small random variance
	for key in StatDefs.CORE:
		var base: int = species.base_stats.get(key, 40)
		wr.set(key, base + randi_range(-5, 5))

	# Roll lifespan from species distribution
	wr.lifespan_days = _roll_lifespan(species)

	# Assign a random starting personality
	var all_personalities := PersonalityDefs.all_ids()
	# Exclude pinnacle state — Legendary is earn-only
	var eligible := all_personalities.filter(func(p): return p != "legendary")
	wr.personality = eligible[randi() % eligible.size()]

	# Initialise empty career tracking dictionaries
	wr.training_session_counts = {}
	wr.personality_pressure    = {}
	wr.events_triggered        = []
	wr.items_consumed          = []
	wr.championships_held      = []

	return wr


func _roll_lifespan(species: WrestlerSpeciesResource) -> int:
	var roll := randi_range(-species.lifespan_variance, species.lifespan_variance)
	return max(species.lifespan_min, species.lifespan_base + roll)


# ---------------------------------------------------------------------------
# Wrestler loading
# ---------------------------------------------------------------------------

func load_new_wrestler(path: String) -> void:
	var res := load(path) as WrestlerResource
	if res == null:
		push_warning("GameManager.load_new_wrestler: failed to load '%s'" % path)
		return
	_load_wrestler_from_resource(res)


func _load_wrestler_from_resource(res: WrestlerResource) -> void:
	current_wrestler_res = res
	if is_instance_valid(current_wrestler_node):
		current_wrestler_node.queue_free()
	current_wrestler_node = Wrestler.new()
	current_wrestler_node.apply_resource(res)
	emit_signal("wrestler_changed", current_wrestler_node)


# ---------------------------------------------------------------------------
# Daily advance
# Called by CalendarSystem.after_action_advance() each in-game day.
# Handles calendar rollover, coach aging, and evolution checks.
# ---------------------------------------------------------------------------

func advance_day() -> void:
	# Advance calendar
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

	# Tick coach lifespans
	_tick_coaches()

	# Check evolution after every day
	_check_evolution()

	emit_signal("day_advanced", day, week, month, year)


# ---------------------------------------------------------------------------
# Coach management
# ---------------------------------------------------------------------------

# Assigns a coach to the primary or secondary slot.
# slot: "primary" or "secondary"
func assign_coach(coach: CoachResource, slot: String) -> void:
	if slot == "primary":
		primary_coach = coach
	elif slot == "secondary":
		secondary_coach = coach
	else:
		push_warning("GameManager.assign_coach: invalid slot '%s'" % slot)
		return
	emit_signal("coach_assigned", coach, slot)


# Releases a coach from their slot. The slot becomes null (vacant).
# The coach is not removed from the Hall of Fame.
func release_coach(slot: String) -> void:
	if slot == "primary":
		primary_coach = null
	elif slot == "secondary":
		secondary_coach = null
	else:
		push_warning("GameManager.release_coach: invalid slot '%s'" % slot)


# Adds a retired wrestler to the Hall of Fame.
# Call this at retirement regardless of whether they become a coach.
func add_to_hall_of_fame(coach: CoachResource) -> void:
	hall_of_fame.append(coach)


# Returns both active coaches as an array, filtering null slots.
func get_active_coaches() -> Array[CoachResource]:
	var result: Array[CoachResource] = []
	if primary_coach != null:
		result.append(primary_coach)
	if secondary_coach != null:
		result.append(secondary_coach)
	return result


# Ticks coach lifespan each day. Removes coaches who have died.
func _tick_coaches() -> void:
	if primary_coach != null:
		primary_coach.days_remaining -= 1
		if primary_coach.days_remaining <= 0:
			emit_signal("coach_died", primary_coach, "primary")
			primary_coach = null

	if secondary_coach != null:
		secondary_coach.days_remaining -= 1
		if secondary_coach.days_remaining <= 0:
			emit_signal("coach_died", secondary_coach, "secondary")
			secondary_coach = null


# ---------------------------------------------------------------------------
# Evolution check
# Delegates to EvolutionSystem autoload if available.
# ---------------------------------------------------------------------------

func _check_evolution() -> void:
	if current_wrestler_node == null:
		return
	if not has_node("/root/ES"):
		return

	var es := get_node("/root/ES") as EvolutionSystem
	if es == null:
		return

	var new_stage := es.check_evolution(current_wrestler_node)
	if new_stage != "":
		emit_signal("evolution_triggered", current_wrestler_node, new_stage)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_species_registry() -> SpeciesRegistry:
	if has_node("/root/SR"):
		return get_node("/root/SR") as SpeciesRegistry
	if has_node("/root/SpeciesRegistry"):
		return get_node("/root/SpeciesRegistry") as SpeciesRegistry
	return null
