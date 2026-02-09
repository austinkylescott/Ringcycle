extends Node
class_name CombatManager

@export var grid_path: NodePath
@export var player_path: NodePath
@export var enemy_path: NodePath

@export var move_cooldown_seconds: float = 0.15

var grid: Grid5x5
var player: Fighter
var enemy: Fighter

func _ready() -> void:
	grid = get_node(grid_path) as Grid5x5
	player = get_node(player_path) as Fighter
	enemy = get_node(enemy_path) as Fighter

	grid.origin = Vector3(-grid.cell_size * (grid.width - 1) / 2.0, 0, -grid.cell_size * (grid.height - 1) / 2.0)

	player.set_cell(Vector2i(1, 2), grid)
	enemy.set_cell(Vector2i(1, 2), grid)

func _process(delta: float) -> void:
	player.tick_cd(delta)
	enemy.tick_cd(delta)
	_handle_player_input()

func _handle_player_input() -> void:
	if player == null or enemy == null or grid == null:
		return
	if not player.can_move():
		return

	var dir := Vector2i.ZERO

	if Input.is_action_just_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("ui_right"):
		dir = Vector2i(1, 0)
	elif Input.is_action_just_pressed("ui_up"):
		dir = Vector2i(0, -1)
	elif Input.is_action_just_pressed("ui_down"):
		dir = Vector2i(0, 1)

	if dir == Vector2i.ZERO:
		return

	var target:= player.cell + dir

	if not grid.in_bounds(target):
		return

	if target == enemy.cell:
		return

	player.set_cell(target, grid)
	player.move_cooldown = move_cooldown_seconds
