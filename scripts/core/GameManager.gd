extends Node
class_name GameManager

@onready var current_wrestler_res : WrestlerResource
@onready var current_wrestler_node : Wrestler
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
	# Prefer a proper species resource (id="rookie") from SpeciesRegistry.
	# If not present, fall back to any available species. Avoid hard-coded legacy paths.
	# Access the autoload singleton named `SR` (configured in project.godot).
 	# Avoid calling methods on the SpeciesRegistry class directly — use the autoload instance.
	var sr: SpeciesRegistry = null
	if has_node("/root/SR"):
		sr = get_node("/root/SR")
	# If the autoload wasn't registered under the alias SR, try the instance under /root/SpeciesRegistry
	elif has_node("/root/SpeciesRegistry"):
		sr = get_node("/root/SpeciesRegistry")

	if sr != null:
		var species := sr.get_species("rookie")
		if species != null:
			var wr = create_wrestler_from_species(species)
			_load_wrestler_from_resource(wr)
			return
		# no explicit rookie species - try any available species
		var any = sr.get_any_species()
		if any != null:
			var wr2 = create_wrestler_from_species(any)
			_load_wrestler_from_resource(wr2)
			return

	# As a final fallback, create a default WrestlerResource in memory
	var default_wr := WrestlerResource.new()
	default_wr.display_name = "Rookie"
	default_wr.stage = "Rookie"
	current_wrestler_res = default_wr
	if is_instance_valid(current_wrestler_node):
		current_wrestler_node.queue_free()
	current_wrestler_node = Wrestler.new()
	current_wrestler_node.apply_resource(current_wrestler_res)
	emit_signal("wrestler_changed", current_wrestler_node)


func create_wrestler_from_species(species: WrestlerSpeciesResource) -> WrestlerResource:
	var wr := WrestlerResource.new()
	wr.species = species

	for key in StatDefs.CORE:
		var base = species.base_stats.get(key, 40)
		var variance = randi_range(-5,5) # or % based
		wr.set(key, base + variance)

	return	wr


func load_new_wrestler(path:String) -> void:
	current_wrestler_res = load(path)
	if is_instance_valid(current_wrestler_node):
		current_wrestler_node.queue_free()
	current_wrestler_node = Wrestler.new()
	current_wrestler_node.apply_resource(current_wrestler_res)
	emit_signal("wrestler_changed", current_wrestler_node)


func _load_wrestler_from_resource(res: WrestlerResource) -> void:
	current_wrestler_res = res
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
