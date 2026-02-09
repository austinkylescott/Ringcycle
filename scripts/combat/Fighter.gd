extends CharacterBody3D
class_name Fighter

@export var wrestler:WrestlerResource
var cell: Vector2i = Vector2i.ZERO
var move_cooldown: float = 0.0

enum State {
	NEUTRAL,
	MOVING,
	ACTING,
	GRAPPLING,
	CLIMBING,
	DOWNED,
}

var state := State.NEUTRAL

func set_cell(new_cell: Vector2i, grid: Grid5x5) -> void:
	cell = new_cell
	global_position = grid.to_world(cell)

func can_move() -> bool:
	return move_cooldown <= 0.0 and state == State.NEUTRAL

func tick_cd(delta: float) -> void:
	move_cooldown = max(0.0, move_cooldown - delta)
