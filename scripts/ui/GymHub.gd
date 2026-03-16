extends Control

# ---------------------------------------------------------------------------
# GymHub — main gameplay screen.
# ---------------------------------------------------------------------------

@onready var train_button:   Button          = $Actions/TrainButton
@onready var rest_button:    Button          = $Actions/RestButton
@onready var show_button:    Button          = $Actions/ShowButton
@onready var tour_button:    Button          = $Actions/TourButton
@onready var retire_button:  Button          = $Actions/RetireButton
@onready var modal_layer:    Control         = $ModalLayer
@onready var training_sys:   TrainingSystem  = $TrainingSystem
@onready var calendar_sys:   CalendarSystem  = $CalendarSystem
@onready var sim_1w_button:  Button          = $SimBar/Sim1WButton
@onready var sim_2w_button:  Button          = $SimBar/Sim2WButton
@onready var sim_3w_button:  Button          = $SimBar/Sim3WButton
@onready var sim_4w_button:  Button          = $SimBar/Sim4WButton
@onready var sim_1y_button:  Button          = $SimBar/Sim1YButton
@onready var log_panel:      RichTextLabel   = $LogPanel
@onready var career_sim:     CareerSimulator = $CareerSimulator

var _stats_snapshot: Dictionary = {}
var _retire_first_confirmation_shown: bool = false


func _ready() -> void:
	train_button.pressed.connect(_on_train_pressed)
	rest_button.pressed.connect(_on_rest_pressed)

	show_button.disabled = true
	show_button.text = "Show (Soon)"
	tour_button.disabled = true
	tour_button.text = "Tour (Soon)"

	# Retire button — hidden until threshold is reached
	retire_button.visible = false
	retire_button.pressed.connect(_on_retire_pressed)

	sim_1w_button.pressed.connect(func(): _run_simulation_weeks(1))
	sim_2w_button.pressed.connect(func(): _run_simulation_weeks(2))
	sim_3w_button.pressed.connect(func(): _run_simulation_weeks(3))
	sim_4w_button.pressed.connect(func(): _run_simulation_weeks(4))
	sim_1y_button.pressed.connect(func(): _run_simulation_days(CareerSimulator.DAYS_PER_YEAR))

	career_sim.simulation_completed.connect(_on_simulation_completed)

	GM.evolution_triggered.connect(_on_evolution_triggered)
	GM.coach_died.connect(_on_coach_died)
	GM.day_advanced.connect(_on_day_advanced)
	GM.wrestler_died.connect(_on_wrestler_died)
	GM.wrestler_retired.connect(_on_wrestler_retired)
	GM.wrestler_changed.connect(_on_wrestler_changed)
	GM.retire_available.connect(_on_retire_available)

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

	var days_lived   := int(wrestler.get_stat("days_lived"))
	var lifespan     := int(wrestler.get_stat("lifespan_days"))
	var original     := days_lived + lifespan
	var pct_lived    := int((float(days_lived) / float(original)) * 100.0) if original > 0 else 0

	$TopBar/Label.text = (
		"Yr %d Mo %d Wk %d Day %d | %s (%s) | %s | Fatigue: %d | Morale: %d | Fame: %d | Life: %d%% (%d days left) | Mood: %s"
		% [
			GM.year, GM.month, GM.week, GM.day,
			wrestler.get_display_name(),
			wrestler.get_stage(),
			", ".join(parts),
			int(wrestler.get_stat("fatigue")),
			int(wrestler.get_stat("morale")),
			int(wrestler.get_stat("fame")),
			pct_lived,
			lifespan,
			wrestler.get_personality_display(),
		]
	)

	# Show retire button only once threshold has been crossed
	retire_button.visible = GM.retire_option_unlocked


# ---------------------------------------------------------------------------
# Action handlers
# ---------------------------------------------------------------------------

func _on_train_pressed() -> void:
	var wrestler := GM.current_wrestler_node
	if wrestler != null:
		_stats_snapshot = _snapshot_wrestler_stats(wrestler)

	var menu := preload("res://scenes/menus/TrainMenu.tscn").instantiate()
	modal_layer.add_child(menu)
	menu.training_selected.connect(_on_training_selected)
	menu.cancelled.connect(_on_training_cancelled)


func _on_rest_pressed() -> void:
	var wrestler := GM.current_wrestler_node
	training_sys.apply_training(wrestler, "Rest")
	calendar_sys.after_action_advance()
	_refresh_ui()


func _on_training_selected(action_name: String) -> void:
	_close_menus()

	var wrestler := GM.current_wrestler_node
	training_sys.apply_training(wrestler, action_name)
	calendar_sys.after_action_advance()
	_refresh_ui()

	var changes := _diff_stats(_stats_snapshot, wrestler)
	SL.log_player_action(action_name, changes, wrestler)

	_show_training_result(action_name, wrestler)


func _on_training_cancelled() -> void:
	_close_menus()


# ---------------------------------------------------------------------------
# Retire
# ---------------------------------------------------------------------------

func _on_retire_available() -> void:
	_refresh_ui()
	# Show first-time confirmation only once per wrestler
	if not _retire_first_confirmation_shown:
		_retire_first_confirmation_shown = true
		_show_retire_confirmation_dialog()


func _show_retire_confirmation_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Retirement Available"
	dialog.dialog_text = (
		"%s has reached the halfway point of their career.\n\n" +
		"You can now retire them at any time to convert them into a coach.\n\n" +
		"A Retire option has been added to your actions.\n\n" +
		"Remember: if they die before retiring, no coaching bonus is earned."
	) % GM.current_wrestler_node.get_display_name()
	dialog.ok_button_text = "Understood"
	dialog.cancel_button_text = ""
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _on_retire_pressed() -> void:
	var wrestler := GM.current_wrestler_node
	if wrestler == null:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Retire %s?" % wrestler.get_display_name()

	var days_left := int(wrestler.get_stat("lifespan_days"))
	var stage     := wrestler.get_stage()
	var preview   := _get_retire_preview(wrestler)

	dialog.dialog_text = (
		"Retire %s now?\n\n" +
		"Stage: %s\n" +
		"Days remaining as coach: ~%d\n" +
		"Estimated coaching bonus: %s +%d\n\n" +
		"This cannot be undone."
	) % [
		wrestler.get_display_name(),
		stage,
		days_left,
		preview.bonus_stat,
		preview.bonus_value,
	]
	dialog.ok_button_text = "Retire"
	dialog.cancel_button_text = "Keep Training"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(_confirm_retire)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _confirm_retire() -> void:
	GM.voluntary_retire()
	_retire_first_confirmation_shown = false  # Reset for next wrestler
	_refresh_ui()


# Returns a preview CoachResource without actually retiring
func _get_retire_preview(wrestler: Wrestler) -> CoachResource:
	return CoachResource.from_wrestler(wrestler)


# ---------------------------------------------------------------------------
# Training result screen
# ---------------------------------------------------------------------------

func _show_training_result(action_name: String, wrestler: Wrestler) -> void:
	var screen: TrainingResultScreen = preload(
		"res://scenes/menus/TrainingResultScreen.tscn"
	).instantiate()
	modal_layer.add_child(screen)
	screen.dismissed.connect(_on_result_dismissed)
	screen.present(action_name, _stats_snapshot, wrestler)


func _on_result_dismissed() -> void:
	pass


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _run_simulation_weeks(weeks: int) -> void:
	_set_action_buttons_disabled(true)
	_log_to_panel("── Simulating %d week(s)..." % weeks)
	career_sim.simulate_weeks(weeks)
	_on_simulation_completed()


func _run_simulation_days(days: int) -> void:
	_set_action_buttons_disabled(true)
	_log_to_panel("── Simulating %d days..." % days)
	career_sim.simulate_days(days)
	_on_simulation_completed()


func _on_simulation_completed() -> void:
	_set_action_buttons_disabled(false)
	_log_to_panel("── Simulation complete.")
	_refresh_ui()


func _set_action_buttons_disabled(disabled: bool) -> void:
	train_button.disabled  = disabled
	rest_button.disabled   = disabled
	sim_1w_button.disabled = disabled
	sim_2w_button.disabled = disabled
	sim_3w_button.disabled = disabled
	sim_4w_button.disabled = disabled
	sim_1y_button.disabled = disabled


# ---------------------------------------------------------------------------
# Log panel
# ---------------------------------------------------------------------------

func _log_to_panel(text: String) -> void:
	if log_panel == null:
		return
	log_panel.append_text(text + "\n")


# ---------------------------------------------------------------------------
# GM signal handlers
# ---------------------------------------------------------------------------

func _on_day_advanced(_day: int, _week: int, _month: int, _year: int) -> void:
	_refresh_ui()


func _on_wrestler_changed(_wrestler: Wrestler) -> void:
	_retire_first_confirmation_shown = false
	_refresh_ui()


func _on_evolution_triggered(wrestler: Wrestler, new_stage: String) -> void:
	var msg := "★ Evolution! %s → %s" % [wrestler.get_display_name(), new_stage]
	SL.log_event(msg)
	_log_to_panel(msg)
	_refresh_ui()


func _on_coach_died(coach: CoachResource, slot: int) -> void:
	var msg := "Coach %s passed away (slot %d now open)" % [coach.display_name, slot]
	SL.log_event(msg)
	_log_to_panel(msg)
	_refresh_ui()


func _on_wrestler_died(wrestler: Wrestler) -> void:
	var msg := "☠ %s died with no retirement — coaching bonus lost" % wrestler.get_display_name()
	SL.log_event(msg)
	_log_to_panel(msg)


func _on_wrestler_retired(wrestler: Wrestler, coach: CoachResource) -> void:
	var msg := "✦ %s retired → Coach (%s +%d, %d days) | HoF: %d" % [
		wrestler.get_display_name(),
		coach.bonus_stat, coach.bonus_value,
		coach.days_remaining,
		GM.hall_of_fame.size(),
	]
	SL.log_event(msg)
	_log_to_panel(msg)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _snapshot_wrestler_stats(wrestler: Wrestler) -> Dictionary:
	var snap := {}
	for stat in StatDefs.CORE:
		snap[stat] = wrestler.get_stat(stat)
	snap["fatigue"] = wrestler.get_stat("fatigue")
	snap["morale"]  = wrestler.get_stat("morale")
	return snap


func _diff_stats(before: Dictionary, wrestler: Wrestler) -> Dictionary:
	var diff := {}
	for stat in before.keys():
		var delta: float = wrestler.get_stat(stat) - before.get(stat, 0.0)
		if abs(delta) >= 0.5:
			diff[stat] = delta
	return diff


func _close_menus() -> void:
	for child in modal_layer.get_children():
		child.queue_free()
