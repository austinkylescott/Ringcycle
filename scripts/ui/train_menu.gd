extends Control

signal training_selected(action_name: String)
signal cancelled()

@onready var strength_btn: Button = $PanelContainer/VBoxContainer/StrengthButton
@onready var tech_btn: Button = $PanelContainer/VBoxContainer/TechniqueButton
@onready var cond_btn: Button = $PanelContainer/VBoxContainer/ConditioningButton
@onready var showmanship_btn: Button = $PanelContainer/VBoxContainer/ShowmanshipButton

@onready var selected_label: Label = $PanelContainer/VBoxContainer/SelectedLabel
@onready var confirm_btn: Button = $PanelContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn: Button = $PanelContainer/VBoxContainer/HBoxContainer/CancelButton

var _pending_choice: String =""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	strength_btn.pressed.connect(func(): _set_choice("Strength Drill"))
	tech_btn.pressed.connect(func(): _set_choice("Technique Practice"))
	cond_btn.pressed.connect(func(): _set_choice("Conditioning"))
	showmanship_btn.pressed.connect(func():_set_choice("Showmanship"))

	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)

	confirm_btn.disabled = true;
	selected_label.text = "Selected: (none)"

func _set_choice(choice: String) -> void:
	_pending_choice = choice
	selected_label.text = "Selected: %s" % choice
	confirm_btn.disabled = false

func _on_confirm_pressed() -> void:
	if _pending_choice == "":
		return
	# Emit signal for GymHub
	training_selected.emit(_pending_choice)

func _on_cancel_pressed() -> void:
	cancelled.emit()
