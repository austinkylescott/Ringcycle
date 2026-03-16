extends Node
class_name CalendarSystem

# ---------------------------------------------------------------------------
# CalendarSystem — player-side day advance.
# Calls GM.advance_day() exactly once per player action.
# GM.advance_day() handles lifespan, calendar, death, evolution, coaches.
# This class handles: TrainingSystem week boundary and special event signals.
# ---------------------------------------------------------------------------

signal special_event(day: int, week: int, month: int, year: int)

@export var training_system_path: NodePath

@onready var _training_sys: TrainingSystem = get_node_or_null(training_system_path)


func _ready() -> void:
	# Listen to GM's week_started signal to notify TrainingSystem
	GM.week_started.connect(_on_week_started)


func after_action_advance() -> void:
	var prev_day := GM.day

	# GM.advance_day() handles everything: lifespan, death, calendar, evolution
	var died := GM.advance_day()

	if died:
		# Wrestler died — GM already swapped in a new one. Nothing more to do.
		return

	# Weekend show/tour event trigger
	if GM.day in [6, 7] and GM.day != prev_day:
		emit_signal("special_event", GM.day, GM.week, GM.month, GM.year)


func _on_week_started(wrestler: Wrestler) -> void:
	if _training_sys != null and wrestler != null:
		_training_sys.on_week_start(wrestler)
