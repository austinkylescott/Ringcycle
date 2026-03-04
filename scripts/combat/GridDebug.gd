extends MeshInstance3D
class_name GridDebug

@export var line_height: float = 0.02
@export var line_color: Color = Color(0.25, 0.9, 0.25, 0.9)

func refresh(grid: Grid5x5) -> void:
	# Build a simple line mesh that outlines each grid cell so you can see movement.
	if grid == null:
		mesh = null
		return

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = line_color

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var start := grid.origin
	var cell := grid.cell_size
	var width_world := float(grid.width) * cell
	var height_world := float(grid.height) * cell

	for x in range(grid.width + 1):
		var wx := start.x + x * cell
		im.surface_add_vertex(Vector3(wx, line_height, start.z))
		im.surface_add_vertex(Vector3(wx, line_height, start.z + height_world))

	for y in range(grid.height + 1):
		var wz := start.z + y * cell
		im.surface_add_vertex(Vector3(start.x, line_height, wz))
		im.surface_add_vertex(Vector3(start.x + width_world, line_height, wz))

	im.surface_end()
	mesh = im
