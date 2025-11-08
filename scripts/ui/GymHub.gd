extends Control

@onready var train_button: Button = $Actions/TrainButton
@onready var modal_layer: Control = $ModalLayer

@onready var training_sys: Node = $TrainingSystem
@onready var calendar_sys: Node = $CalendarSystem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	train_button.pressed.connect(_on_train_pressed)
	_refresh_ui()
	
func _refresh_ui() -> void:
	var wrestler = GM.current_wrestler_node
	$TopBar/Label.text = "Week %d Day %d -%s (%s)" % [
		GM.week,
		GM.day,
		wrestler.res.display_name,
		wrestler.res.stage
	]

func _on_train_pressed() -> void:
	#Instance TrainMenu
	var train_menu_scene = preload("res://scenes/menus/TrainMenu.tscn")
	var menu = train_menu_scene.instantiate()
	
	#add as child to ModalLayer
	modal_layer.add_child(menu)
	
	#Signal to gymhub handlers
	menu.training_selected.connect(_on_training_selected)
	menu.cancelled.connect(_on_training_cancelled)

func _on_training_selected(action_name: String) -> void:
	print("Training selected: ", action_name)
	var wrestler = GM.current_wrestler_node
	
	# Training System
	training_sys.do_training(wrestler, action_name)
	
	# Advance day
	calendar_sys.after_action_advance()
	
	# Check evo requirements
	#
	print("New STR:", wrestler.res.strength, " Fatigue:", wrestler.res.fatigue, " Day:", GM.day)

	_refresh_ui()
	_close_menus()

func _on_training_cancelled() -> void:
	_close_menus()
	
func _close_menus() -> void:
	for child in modal_layer.get_children():
		child.queue_free()
