extends Node
class_name HeadlineLog

# ---------------------------------------------------------------------------
# HeadlineLog — autoload alias "HL"
#
# Append-only log of significant world events expressed as headlines.
# Written by ShowManager as a byproduct of show resolution.
# Read by the newspaper/headlines UI screen.
#
# Add to project.godot autoloads:
#   HL="*res://scripts/core/HeadlineLog.gd"
#
# Each entry is a Dictionary:
#   {
#     "text":  String,   — the headline text
#     "week":  int,      — GM.week when it was written
#     "month": int,      — GM.month
#     "year":  int,      — GM.year
#     "type":  String,   — headline type for filtering/styling
#   }
#
# Headlines older than MAX_AGE_WEEKS are pruned automatically on each
# new week to prevent unbounded growth.
# ---------------------------------------------------------------------------

const MAX_AGE_WEEKS := 12   # keep ~3 months of headlines
const MAX_ENTRIES   := 200  # hard cap regardless of age

var _entries: Array = []   # Array[Dictionary]

signal headline_added(entry: Dictionary)


# ---------------------------------------------------------------------------
# Write API — called by ShowManager
# ---------------------------------------------------------------------------

static func add(text: String, type: String = "general") -> void:
	# Static call forwards to the autoload instance
	var hl: HeadlineLog = _get_instance()
	if hl == null:
		return
	hl._add_entry(text, type)


func _add_entry(text: String, type: String) -> void:
	if text == "":
		return

	var entry := {
		"text":  text,
		"week":  GM.week,
		"month": GM.month,
		"year":  GM.year,
		"type":  type,
		"absolute_week": _absolute_week(),
	}
	_entries.append(entry)

	# Prune if over hard cap
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()

	emit_signal("headline_added", entry)


# ---------------------------------------------------------------------------
# Prune — call on week boundary
# ---------------------------------------------------------------------------

func prune_old_headlines() -> void:
	var current_week: int = _absolute_week()
	_entries = _entries.filter(func(e: Dictionary):
		return (current_week - e.get("absolute_week", 0)) <= MAX_AGE_WEEKS
	)


# ---------------------------------------------------------------------------
# Read API — used by UI
# ---------------------------------------------------------------------------

# Returns all headlines, newest first.
func get_all() -> Array:
	var result: Array = _entries.duplicate()
	result.reverse()
	return result


# Returns headlines from the current week only.
func get_this_week() -> Array:
	var aw: int = _absolute_week()
	return _entries.filter(
		func(e: Dictionary): return e.get("absolute_week", 0) == aw
	)


# Returns headlines from the last N weeks, newest first.
func get_recent(num_weeks: int = 4) -> Array:
	var aw: int = _absolute_week()
	var result := _entries.filter(func(e: Dictionary):
		return (aw - e.get("absolute_week", 0)) <= num_weeks
	)
	result.reverse()
	return result


# Returns headlines of a specific type.
func get_by_type(type: String) -> Array:
	return _entries.filter(
		func(e: Dictionary): return e.get("type", "") == type
	)


# Returns headlines for a specific in-game month/year.
func get_for_month(month: int, year: int) -> Array:
	return _entries.filter(func(e: Dictionary):
		return e.get("month", 0) == month and e.get("year", 0) == year
	)


# Returns the most recent N headlines regardless of age.
func get_latest(count: int = 5) -> Array:
	var result: Array = _entries.duplicate()
	result.reverse()
	return result.slice(0, count)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _absolute_week() -> int:
	return ((GM.year - 1) * 48) + ((GM.month - 1) * 4) + GM.week


static func _get_instance() -> HeadlineLog:
	var tree := Engine.get_main_loop()
	if tree == null:
		return null
	var root := (tree as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null("/root/HL") as HeadlineLog
