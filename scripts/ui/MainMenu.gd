extends Control

@onready var newGameButton: Button = $MenuContainer/NewGameButton
@onready var continueButton: Button = $MenuContainer/ContinueButton
@onready var quitButton: Button = $MenuContainer/QuitButton
@onready var runTestButton: Button = $MenuContainer/RunSpeciesSmokeTest


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	newGameButton.pressed.connect(_onNewGamePressed)
	continueButton.disabled = true
	quitButton.pressed.connect(_onQuitPressed)

	# Show this button only in debug builds
	runTestButton.visible = OS.is_debug_build()
	if runTestButton.visible:
		runTestButton.pressed.connect(_onRunSpeciesSmokeTestPressed)

func _onNewGamePressed() -> void:
	# Later: init GameManager, load starting wrestler, etc.
	get_tree().change_scene_to_file("res://scenes/GymHub.tscn")

func _onQuitPressed() -> void:
	get_tree().quit()


func _onRunSpeciesSmokeTestPressed() -> void:
	# Guard: only allow in debug builds
	if not OS.is_debug_build():
		return
	get_tree().change_scene_to_file("res://scenes/tests/SpeciesSmokeTest.tscn")
