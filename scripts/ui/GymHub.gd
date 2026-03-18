extends Control

# ---------------------------------------------------------------------------
# GymHub — main gameplay screen.
# ---------------------------------------------------------------------------

@onready var train_button:     Button          = $Actions/TrainButton
@onready var rest_button:      Button          = $Actions/RestButton
@onready var show_button:      Button          = $Actions/ShowButton
@onready var headlines_button: Button          = $Actions/HeadlinesButton
@onready var tour_button:      Button          = $Actions/TourButton
@onready var retire_button:    Button          = $Actions/RetireButton
@onready var modal_layer:      Control         = $ModalLayer
@onready var training_sys:     TrainingSystem  = $TrainingSystem
@onready var calendar_sys:     CalendarSystem  = $CalendarSystem
@onready var sim_1w_button:    Button          = $SimBar/Sim1WButton
@onready var sim_2w_button:    Button          = $SimBar/Sim2WButton
@onready var sim_3w_button:    Button          = $SimBar/Sim3WButton
@onready var sim_4w_button:    Button          = $SimBar/Sim4WButton
@onready var sim_1y_button:    Button          = $SimBar/Sim1YButton
@onready var log_panel:        RichTextLabel   = $LogPanel
@onready var career_sim:       CareerSimulator = $CareerSimulator
@onready var contract_label:   Label           = $ContractBar/ContractLabel

var _stats_snapshot: Dictionary = {}
var _retire_first_confirmation_shown: bool = false


# ---------------------------------------------------------------------------
# Autoload accessors — resolved at runtime to avoid parse-time errors
# ---------------------------------------------------------------------------

func _sm() -> ShowManager:
	return get_node("/root/SM") as ShowManager


# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	train_button.pressed.connect(_on_train_pressed)
	rest_button.pressed.connect(_on_rest_pressed)
	show_button.pressed.connect(_on_show_pressed)
	headlines_button.pressed.connect(_on_headlines_pressed)

	tour_button.disabled = true
	tour_button.text     = "Tour (Soon)"

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
	GM.contract_offered.connect(_on_contract_offered)
	GM.contract_signed.connect(_on_contract_signed)
	GM.contract_released.connect(_on_contract_released)

	var sm: ShowManager = _sm()
	if sm != null:
		sm.show_completed.connect(_on_show_completed)

	_refresh_ui()


# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------

func _refresh_ui() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler == null:
		return

	var parts: Array[String] = []
	for key in StatDefs.CORE:
		parts.append("%s: %d" % [key.capitalize(), int(wrestler.get_stat(key))])

	var days_lived: int  = int(wrestler.get_stat("days_lived"))
	var lifespan: int    = int(wrestler.get_stat("lifespan_days"))
	var original: int    = days_lived + lifespan
	var pct_lived: int   = int((float(days_lived) / float(original)) * 100.0) if original > 0 else 0

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

	retire_button.visible = GM.retire_option_unlocked
	_refresh_contract_label()
	_refresh_show_button()


func _refresh_contract_label() -> void:
	if GM.is_contracted():
		var promo: PromotionResource = GM.get_contracted_promotion()
		contract_label.text = "Contract: %s (%s rank)" % [
			promo.display_name if promo != null else GM.contracted_promotion_id,
			promo.rank if promo != null else "?",
		]
	else:
		contract_label.text = "Contract: None (Indie)"


func _refresh_show_button() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler == null:
		show_button.disabled = true
		show_button.text     = "Attend Show"
		return

	show_button.disabled = false
	var fatigue: int = int(wrestler.get_stat("fatigue"))
	if fatigue >= 70:
		show_button.text = "Attend Show (Fatigued!)"
	else:
		show_button.text = "Attend Show"


# ---------------------------------------------------------------------------
# Action handlers
# ---------------------------------------------------------------------------

func _on_train_pressed() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler != null:
		_stats_snapshot = _snapshot_wrestler_stats(wrestler)

	var menu := preload("res://scenes/menus/TrainMenu.tscn").instantiate()
	modal_layer.add_child(menu)
	menu.training_selected.connect(_on_training_selected)
	menu.cancelled.connect(_on_training_cancelled)


func _on_rest_pressed() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	training_sys.apply_training(wrestler, "Rest")
	calendar_sys.after_action_advance()
	_refresh_ui()


func _on_training_selected(action_name: String) -> void:
	_close_menus()

	var wrestler: Wrestler = GM.current_wrestler_node
	training_sys.apply_training(wrestler, action_name)
	calendar_sys.after_action_advance()
	_refresh_ui()

	var changes: Dictionary = _diff_stats(_stats_snapshot, wrestler)
	SL.log_player_action(action_name, changes, wrestler)

	_show_training_result(action_name, wrestler)


func _on_training_cancelled() -> void:
	_close_menus()


# ---------------------------------------------------------------------------
# Show
# ---------------------------------------------------------------------------

func _on_show_pressed() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler != null:
		_stats_snapshot = _snapshot_wrestler_stats(wrestler)

	_set_action_buttons_disabled(true)

	var sm: ShowManager = _sm()
	if sm == null:
		push_warning("GymHub: ShowManager not found at /root/SM")
		_set_action_buttons_disabled(false)
		return

	var result: ShowResult = sm.run_show()

	if result == null:
		_set_action_buttons_disabled(false)
		return

	calendar_sys.after_action_advance()
	_set_action_buttons_disabled(false)
	_show_show_result(result)
	_refresh_ui()


func _show_show_result(result: ShowResult) -> void:
	var screen: ShowScreen = preload(
		"res://scenes/menus/ShowScreen.tscn"
	).instantiate()
	modal_layer.add_child(screen)
	screen.dismissed.connect(_on_show_screen_dismissed)
	screen.present(result)


func _on_show_screen_dismissed() -> void:
	_close_menus()
	_refresh_ui()


func _on_show_completed(result: ShowResult) -> void:
	if result.title_changed:
		_log_to_panel("★ Title change at %s!" % result.show_name)
	if result.player_match_won:
		_log_to_panel("✓ Won at %s (+%.0f fame)" % [
			result.show_name, result.total_fame_delta
		])
	else:
		_log_to_panel("✗ Lost at %s (%.0f fame)" % [
			result.show_name, result.total_fame_delta
		])


# ---------------------------------------------------------------------------
# Headlines
# ---------------------------------------------------------------------------

func _on_headlines_pressed() -> void:
	var screen: HeadlinesScreen = preload(
		"res://scenes/menus/HeadlinesScreen.tscn"
	).instantiate()
	modal_layer.add_child(screen)
	screen.dismissed.connect(_close_menus)
	screen.present()


# ---------------------------------------------------------------------------
# Contract handlers
# ---------------------------------------------------------------------------

func _on_contract_offered(promotion: PromotionResource) -> void:
	_show_contract_offer_dialog(promotion)


func _show_contract_offer_dialog(promotion: PromotionResource) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Contract Offer"
	dialog.dialog_text = (
		"%s is offering you a contract!\n\n"
		+ "Rank: %s\n"
		+ "Shows: %d per week + monthly PLE\n"
		+ "Prestige: %.1fx fame multiplier\n\n"
		+ "%s\n\n"
		+ "Sign with them? You can decline and wait for other offers."
	) % [
		promotion.display_name,
		promotion.rank,
		promotion.weekly_show_count,
		promotion.prestige,
		promotion.description,
	]
	dialog.ok_button_text     = "Sign"
	dialog.cancel_button_text = "Decline"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): GM.sign_contract(promotion.id))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _on_contract_signed(promotion: PromotionResource) -> void:
	_log_to_panel("✦ Signed with %s" % promotion.display_name)
	_refresh_ui()


func _on_contract_released(_promotion_id: String) -> void:
	_log_to_panel("Contract released.")
	_refresh_ui()


# ---------------------------------------------------------------------------
# Retire
# ---------------------------------------------------------------------------

func _on_retire_available() -> void:
	_refresh_ui()
	if not _retire_first_confirmation_shown:
		_retire_first_confirmation_shown = true
		_show_retire_confirmation_dialog()


func _show_retire_confirmation_dialog() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler == null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Retirement Available"
	dialog.dialog_text = (
		"%s has reached the halfway point of their career.\n\n"
		+ "You can now retire them at any time to convert them into a coach.\n\n"
		+ "A Retire option has been added to your actions.\n\n"
		+ "Remember: if they die before retiring, no coaching bonus is earned."
	) % wrestler.get_display_name()
	dialog.ok_button_text     = "Understood"
	dialog.cancel_button_text = ""
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _on_retire_pressed() -> void:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler == null:
		return

	var days_left: int  = int(wrestler.get_stat("lifespan_days"))
	var stage: String   = wrestler.get_stage()
	var preview: CoachResource = _get_retire_preview(wrestler)

	var dialog := ConfirmationDialog.new()
	dialog.title = "Retire %s?" % wrestler.get_display_name()
	dialog.dialog_text = (
		"Retire %s now?\n\n"
		+ "Stage: %s\n"
		+ "Days remaining as coach: ~%d\n"
		+ "Estimated coaching bonus: %s +%d\n\n"
		+ "This cannot be undone."
	) % [
		wrestler.get_display_name(),
		stage,
		days_left,
		preview.bonus_stat,
		preview.bonus_value,
	]
	dialog.ok_button_text     = "Retire"
	dialog.cancel_button_text = "Keep Training"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(_confirm_retire)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _confirm_retire() -> void:
	GM.voluntary_retire()
	_retire_first_confirmation_shown = false
	_refresh_ui()


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


func _run_simulation_days(days: int) -> void:
	_set_action_buttons_disabled(true)
	_log_to_panel("── Simulating %d days..." % days)
	career_sim.simulate_days(days)


func _on_simulation_completed() -> void:
	_set_action_buttons_disabled(false)
	_log_to_panel("── Simulation complete.")
	_refresh_ui()


func _set_action_buttons_disabled(disabled: bool) -> void:
	train_button.disabled     = disabled
	rest_button.disabled      = disabled
	show_button.disabled      = disabled
	headlines_button.disabled = disabled
	sim_1w_button.disabled    = disabled
	sim_2w_button.disabled    = disabled
	sim_3w_button.disabled    = disabled
	sim_4w_button.disabled    = disabled
	sim_1y_button.disabled    = disabled


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
	var msg: String = "★ Evolution! %s → %s" % [wrestler.get_display_name(), new_stage]
	SL.log_event(msg)
	_log_to_panel(msg)
	_refresh_ui()


func _on_coach_died(coach: CoachResource, slot: int) -> void:
	var msg: String = "Coach %s passed away (slot %d now open)" % [coach.display_name, slot]
	SL.log_event(msg)
	_log_to_panel(msg)
	_refresh_ui()


func _on_wrestler_died(wrestler: Wrestler) -> void:
	var msg: String = "☠ %s died with no retirement — coaching bonus lost" % wrestler.get_display_name()
	SL.log_event(msg)
	_log_to_panel(msg)


func _on_wrestler_retired(wrestler: Wrestler, coach: CoachResource) -> void:
	var msg: String = "✦ %s retired → Coach (%s +%d, %d days) | HoF: %d" % [
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
	var snap: Dictionary = {}
	for stat in StatDefs.CORE:
		snap[stat] = wrestler.get_stat(stat)
	snap["fatigue"] = wrestler.get_stat("fatigue")
	snap["morale"]  = wrestler.get_stat("morale")
	return snap


func _diff_stats(before: Dictionary, wrestler: Wrestler) -> Dictionary:
	var diff: Dictionary = {}
	for stat in before.keys():
		var delta: float = wrestler.get_stat(stat) - before.get(stat, 0.0)
		if abs(delta) >= 0.5:
			diff[stat] = delta
	return diff


func _close_menus() -> void:
	for child in modal_layer.get_children():
		child.queue_free()
