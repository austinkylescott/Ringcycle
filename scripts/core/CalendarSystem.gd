extends Node
class_name CalendarSystem

# ---------------------------------------------------------------------------
# CalendarSystem advances the in-game clock after each player action.
# It is a scene node (not an autoload) owned by GymHub.
#
# after_action_advance() is the single entry point — call it after every
# action (training, rest, show, tour day, etc.).
# ---------------------------------------------------------------------------

signal special_event(day: int, week: int, month: int, year: int)

# Reference to TrainingSystem — set by GymHub after instantiation
# so CalendarSystem can call on_week_start() at the week boundary.
@export var training_system_path: NodePath

@onready var _training_sys: TrainingSystem = get_node_or_null(training_system_path)


func after_action_advance() -> void:
	var wrestler := GM.current_wrestler_node
	if wrestler == null:
		return

	# Age the wrestler one day
	wrestler.age_one_day()

	# Check death
	if wrestler.is_dead():
		# Handled by GymHub listening to this signal or a dedicated death signal
		# For now just advance — Phase 3 UI will handle the retirement flow
		pass

	# Capture week before advancing so we know if it just rolled over
	var prev_week := GM.week

	# Advance the calendar
	GM.advance_day()

	# Week boundary — fire on_week_start if week rolled over
	if GM.week != prev_week:
		if _training_sys != null:
			_training_sys.on_week_start(wrestler)

	# Weekend shows and monthly beats
	if GM.day in [6, 7]:
		emit_signal("special_event", GM.day, GM.week, GM.month, GM.year)
