extends Control

# ---------------------------------------------------------------------------
# GymHub is the main gameplay screen.
# It owns TrainingSystem and CalendarSystem as child nodes, and connects
# them to the active wrestler via GameManager (GM autoload).
#
# Signals listened to:
#   GM.evolution_triggered  — show evolution screen / notification
#   GM.coach_died           — notify player a coach slot opened
#   GM.day_advanced         — refresh UI
# ---------------------------------------------------------------------------

@onready var train_button:   Button  = $Actions/TrainButton
@onready var rest_button:    Button  = $Actions/RestButton
@onready var show_button:    Button  = $Actions/ShowButton
@onready var tour_button:    Button  = $Actions/TourButton
@onready var modal_layer:    Control = $ModalLayer
@onready var training_sys:   TrainingSystem  = $TrainingSystem
@onready var calendar_sys:   CalendarSystem  = $CalendarSystem


func _ready() -> void:
	train_button.pressed.connect(_on_train_pressed)
	rest_button.pressed.connect(_on_rest_pressed)

	# Connect GM signals
	GM.evolution_triggered.connect(_on_evolution_triggered)
	GM.coach_died.connect(_on_coach_died)
	GM.day_advanced.connect(_on_day_advanced)

	_refresh_ui()


# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------

func _refresh_ui() -> void:
	var wrestler := GM.current_wrestler_node
	if wrestler == null:
		return

	var parts: Array[String] = []
	for key in StatDefs.CORE:
		parts.append("%s: %d" % [key.capitalize(), int(wrestler.get_stat(key))])

	var fatigue     := int(wrestler.get_stat("fatigue"))
	var morale      := int(wrestler.get_stat("morale"))
	var personality := wrestler.get_personality_display()
	var lifespan    := int(wrestler.get_stat("lifespan_days"))

	$TopBar/Label.text = (
		"Yr %d Mo %d Wk %d Day %d | %s (%s) | %s | Fatigue: %d | Morale: %d | Days left: %d | Mood: %s"
		% [
			GM.year, GM.month, GM.week, GM.day,
			wrestler.get_display_name(),
			wrestler.get_stage(),
			", ".join(parts),
			fatigue,
			morale,
			lifespan,
			personality,
		]
	)


# ---------------------------------------------------------------------------
# Action handlers
# ---------------------------------------------------------------------------

func _on_train_pressed() -> void:
	var train_menu_scene := preload("res://scenes/menus/TrainMenu.tscn")
	var menu := train_menu_scene.instantiate()
	modal_layer.add_child(menu)
	menu.training_selected.connect(_on_training_selected)
	menu.cancelled.connect(_on_training_cancelled)


func _on_rest_pressed() -> void:
	var wrestler := GM.current_wrestler_node
	training_sys.apply_training(wrestler, "Rest")
	calendar_sys.after_action_advance()
	_refresh_ui()


func _on_training_selected(action_name: String) -> void:
	var wrestler := GM.current_wrestler_node
	training_sys.apply_training(wrestler, action_name)
	calendar_sys.after_action_advance()
	_refresh_ui()
	_close_menus()


func _on_training_cancelled() -> void:
	_close_menus()


# ---------------------------------------------------------------------------
# GM signal handlers
# ---------------------------------------------------------------------------

func _on_day_advanced(_day: int, _week: int, _month: int, _year: int) -> void:
	_refresh_ui()


func _on_evolution_triggered(wrestler: Wrestler, new_stage: String) -> void:
	# Placeholder — Phase 3 will add a proper evolution cutscene / notification
	print("[GymHub] Evolution! %s is now %s" % [wrestler.get_display_name(), new_stage])
	_refresh_ui()


func _on_coach_died(coach: CoachResource, slot: String) -> void:
	# Placeholder — Phase 3 will show a notification and open the market
	print("[GymHub] Coach %s has passed away (%s slot is now open)" % [coach.display_name, slot])
	_refresh_ui()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _close_menus() -> void:
	for child in modal_layer.get_children():
		child.queue_free()
