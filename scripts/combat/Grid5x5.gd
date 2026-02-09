extends Node
class_name Grid5x5

@export var cell_size: float = 1.5
@export var origin: Vector3 = Vector3.ZERO
@export var width: int = 5
@export var height: int = 5

func to_world(cell: Vector2i) -> Vector3:
	return origin + Vector3(cell.x * cell_size, 0, cell.y * cell_size)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 && cell.x < width && cell.y >= 0 && cell.y < height
