extends Node
class_name SpeciesRegistry

# Singleton that loads species and wrestler templates from res://scripts/data/species
# Usage:
#  - SpeciesRegistry.get_species(id)
#  - SpeciesRegistry.get_all_species()
#  - SpeciesRegistry.get_template(name)

var _species := {} # id -> WrestlerSpeciesResource
var _templates := {} # name -> WrestlerResource

func _ready() -> void:
	_load_species_folder("res://scripts/data/species")
	# Startup log: show how many species and templates were discovered
	print("[SpeciesRegistry] loaded %d species and %d templates: %s" % [_species.size(), _templates.size(), _species.keys()])

func _load_species_folder(path:String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		# skip hidden / parent entries
		if fname.begins_with("."):
			fname = dir.get_next()
			continue
		var full = "%s/%s" % [path, fname]
		# only handle resource files
		if fname.to_lower().ends_with(".tres") or fname.to_lower().ends_with(".res"):
			var res = ResourceLoader.load(full)
			if res:
				# register species resources by their id
				if res is WrestlerSpeciesResource:
					var sid = res.id
					if sid == null or sid == "":
						sid = fname.get_basename()
						res.id = sid
					_species[sid] = res
				elif res is WrestlerResource:
					_templates[fname.get_basename()] = res
		fname = dir.get_next()
	dir.list_dir_end()

func get_species(id:String) -> WrestlerSpeciesResource:
	return _species.get(id, null)

func get_all_species() -> Array:
	return _species.values()

func has_template(template_name:String) -> bool:
	return _templates.has(template_name)

func get_template(template_name:String) -> WrestlerResource:
	return _templates.get(template_name, null)

func get_any_species() -> WrestlerSpeciesResource:
	for s in _species.values():
		return s
	return null
