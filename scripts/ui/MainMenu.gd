extends Control

@onready var newGameButton: Button = $MenuContainer/NewGameButton
@onready var continueButton: Button = $MenuContainer/ContinueButton
@onready var quitButton: Button = $MenuContainer/QuitButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	newGameButton.pressed.connect(_onNewGamePressed)
	continueButton.disabled = true
	quitButton.pressed.connect(_onQuitPressed)

func _onNewGamePressed() -> void:
	# Later: init GameManager, load starting wrestler, etc.
	get_tree().change_scene_to_file("res://scenes/GymHub.tscn")

func _onQuitPressed() -> void:
	get_tree().quit()
