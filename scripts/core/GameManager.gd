extends Node
class_name GameManager

var current_wrestler_res : WrestlerResource
var current_wrestler_node : Wrestler
var day:int = 1
var month:int = 1
var week:int = 1
var year:int = 1

signal day_advanced(day:int, week:int, year:int)
signal wrestler_changed(wrestler:Wrestler)
#signal evolution_triggered()
#signal retired(wrestler:Wrestler)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_new_wrestler("res://scripts/data/wrestlers/rookie_generic.tres")

func load_new_wrestler(path:String) -> void:
	current_wrestler_res = load(path)
	if is_instance_valid(current_wrestler_node):
		current_wrestler_node.queue_free()
	current_wrestler_node = Wrestler.new()
	current_wrestler_node.apply_resource(current_wrestler_res)
	emit_signal("wrestler_changed", current_wrestler_node)
	
func advance_day() -> void:
	day +=1
	if day > 7:
		day = 1
		week += 1
		if week > 52:
			week = 1
			year += 1
	emit_signal("day_advanced", day, week, year)
