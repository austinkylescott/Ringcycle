# Species data folder

This folder contains the game's species data files and documentation. The project uses a simple SpeciesRegistry autoload to discover species and wrestler templates at runtime.

## Location

All species and templates live under:

```
res://scripts/data/species/
```

## File types

- WrestlerSpeciesResource (`WrestlerSpeciesResource`): canonical species files. These define an `id`, `display_name`, `base_stats`, `growth_profile`, `move_pool`, and optional portrait/sprite resources. Files should be `.tres` or `.res` exported from Godot and use the `WrestlerSpeciesResource` script (`scripts/data/WrestlerSpeciesResource.gd`).
- WrestlerResource templates (`WrestlerResource`) — deprecated: simple saved `WrestlerResource` templates. Use species files where possible. If present, the registry will detect them as templates, but prefer converting them to `WrestlerSpeciesResource`.

## SpeciesRegistry behavior

- On project start `SpeciesRegistry` (autoload `SR`) scans `res://scripts/data/species` for `.tres` and `.res` files.
- It registers any `WrestlerSpeciesResource` by `id` (if `id` is blank, the file basename is used).
- It also registers `WrestlerResource` objects as named templates (by file basename).
- API (available globally as the autoload `SR` or `SpeciesRegistry`):
  - `get_species(id)` -> `WrestlerSpeciesResource` or `null`
  - `get_all_species()` -> Array of species resources
  - `get_template(name)` -> `WrestlerResource` template or `null`
  - `has_template(name)` -> bool
  - `get_any_species()` -> first species found or `null`

## How GameManager uses species

- `GameManager._ready()` prefers `SR.get_species("rookie")` (the autoload instance) to construct the initial wrestler.
- If that species is not present, it falls back to the first available species and finally to an in-memory default `WrestlerResource` as a safe fallback.
- To create new wrestler instances from species use `GameManager.create_wrestler_from_species(species)`.

## Creating a new species (recommended)

1. In Godot, right-click the `scripts/data` folder and choose "New Resource".
2. Select `WrestlerSpeciesResource` (backed by `scripts/data/WrestlerSpeciesResource.gd`).
3. Fill fields:
   - `id` (unique string, e.g. `rookie`)
   - `display_name` (human readable)
   - `base_stats` (dictionary of core stats)
   - `growth_profile` (optional multipliers)
   - `move_pool` (array of move ids)
   - `portrait` / `body_sprite` (optional textures)
4. Save the file into `res://scripts/data/species/`.

Example minimal species (conceptual):

```gdscript
# WrestlerSpeciesResource fields (concept only)
id = "rookie"
display_name = "Rookie"
base_stats = {"strength":50, "technique":45, "agility":35, "toughness":40, "stamina":60, "charisma":55}
growth_profile = {"strength":1.1, "stamina":0.95}
move_pool = []
```

## Migration guidance (templates -> species)

If you have `.tres` `WrestlerResource` templates, convert them to `WrestlerSpeciesResource` by:

1. Creating a new `WrestlerSpeciesResource` as above.
2. Copy sensible fields from the template into `base_stats` and `growth_profile`.
3. Save and verify that `SR.get_species(id)` returns the new species.
4. Update code that explicitly loaded old template paths to instead use the `SR` autoload APIs:

```gdscript
# Use species
var s = SR.get_species("rookie")
var wr = GameManager.create_wrestler_from_species(s)

# Or, if you intentionally want a template instance
var tmpl = SR.get_template("rookie_generic")
if tmpl:
    # clone or use directly
```

## Testing / Smoke checks

1. Run the project in Godot.
2. Confirm `SR` (SpeciesRegistry) is autoloaded in the Project Settings -> Autoloads (alias `SR`).
3. At startup, verify `GameManager` creates `current_wrestler_node` (previous behavior) and that no hard-coded `res://scripts/data/wrestlers/...` path is required.
4. From the remote inspector or a debug script, call:

```gdscript
print(SR.get_all_species())
print(SR.get_template("rookie_generic"))
```

## Best practices and recommendations

- Prefer `WrestlerSpeciesResource` for all canonical species. Use unique IDs.
- Keep per-instance templates out of the `species` folder (use `res://scripts/data/templates/` if you need templates) — the registry expects species files here.
- Add a small `tool` script or editor utility to bulk-convert templates if you have many.
- Document new species when adding them (add an entry to this README or a changelog).

If you want, I can add a small `tool` conversion script to batch-upgrade templates into species files, or remove the deprecated template marker files from the repo cleanly.
