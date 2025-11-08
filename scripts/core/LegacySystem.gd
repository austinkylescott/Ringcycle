extends Node
class_name DialogueManager

signal say(text:String)
func speak(line:String) -> void:
	emit_signal("say", line)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
