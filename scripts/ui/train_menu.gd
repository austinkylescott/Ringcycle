extends Control

signal training_selected(action_name: String)
signal cancelled()

# Standard and intensive action lists mirror TrainingSystem exactly.
# Grouped here for display purposes — intensive actions shown separately
# with a visual separator to signal higher cost.
const STANDARD_ACTIONS := [
	"Power Drill",
	"Technique Practice",
	"Conditioning",
	"Agility Drills",
	"Toughness Training",
	"Showmanship",
]

const INTENSIVE_ACTIONS := [
	"Heavy Lifting",
	"Sparring",
	"Endurance Run",
	"Speed Work",
	"Iron Circuit",
	"Crowd Work",
]

@onready var action_list:     VBoxContainer = $PanelContainer/VBoxContainer/ActionList
@onready var selected_label:  Label         = $PanelContainer/VBoxContainer/SelectedLabel
@onready var confirm_btn:     Button        = $PanelContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn:      Button        = $PanelContainer/VBoxContainer/HBoxContainer/CancelButton

var _pending_choice: String = ""


func _ready() -> void:
	confirm_btn.disabled = true
	selected_label.text  = "Selected: (none)"

	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)

	_build_action_list()


func _build_action_list() -> void:
	# Standard actions
	var standard_header := Label.new()
	standard_header.text = "— Standard —"
	standard_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_list.add_child(standard_header)

	for action in STANDARD_ACTIONS:
		var btn := Button.new()
		btn.text = _format_label(action)
		btn.pressed.connect(func(): _set_choice(action))
		action_list.add_child(btn)

	# Separator
	var sep := HSeparator.new()
	action_list.add_child(sep)

	# Intensive actions
	var intensive_header := Label.new()
	intensive_header.text = "— Intensive (high fatigue) —"
	intensive_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_list.add_child(intensive_header)

	for action in INTENSIVE_ACTIONS:
		var btn := Button.new()
		btn.text = _format_label(action)
		btn.pressed.connect(func(): _set_choice(action))
		action_list.add_child(btn)


# Appends the stat gains from TrainingSystem base delta to the button label.
# e.g. "Power Drill" -> "Power Drill  (+POW)"
func _format_label(action: String) -> String:
	var ts := TrainingSystem.new()
	var base := ts.get_base_delta(action)
	ts.free()

	var gains: Array[String] = []
	for key in base.keys():
		var val: int = int(base[key])
		if val > 0 and key in StatDefs.CORE:
			gains.append("+%s" % key.substr(0, 3).to_upper())

	if gains.is_empty():
		return action
	return "%s  (%s)" % [action, ", ".join(gains)]


func _set_choice(choice: String) -> void:
	_pending_choice = choice
	selected_label.text = "Selected: %s" % choice
	confirm_btn.disabled = false


func _on_confirm_pressed() -> void:
	if _pending_choice == "":
		return
	training_selected.emit(_pending_choice)


func _on_cancel_pressed() -> void:
	cancelled.emit()
