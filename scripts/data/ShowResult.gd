extends Resource
class_name ShowResult

# ---------------------------------------------------------------------------
# ShowResult — the complete record of one show.
# Produced by ShowManager.run_show() and consumed by ShowScreen.
# ---------------------------------------------------------------------------

@export var promotion_name: String = ""
@export var show_name:      String = ""
@export var is_ple:         bool   = false
@export var week:           int    = 0
@export var month:          int    = 0
@export var year:           int    = 0

# Ordered list of ShowSegment resources.
@export var segments: Array[ShowSegment] = []

# Net fame delta for the player across all segments this show.
@export var total_fame_delta: float = 0.0

# Whether the player won their match this show.
@export var player_match_won: bool = false

# Whether a title changed hands on this show (player or NPC).
@export var title_changed: bool = false


func add_segment(seg: ShowSegment) -> void:
	if seg == null:
		return
	segments.append(seg)
	if seg.is_player:
		total_fame_delta += seg.fame_delta
		if seg.type == "match":
			player_match_won = seg.player_won
		if seg.title_changed:
			title_changed = true


# Returns only the player's segments.
func get_player_segments() -> Array[ShowSegment]:
	var result: Array[ShowSegment] = []
	for seg in segments:
		if seg.is_player:
			result.append(seg)
	return result


# Returns a flat string of all narrative lines for logging.
func get_full_log() -> String:
	var lines: Array[String] = []
	lines.append("=== %s ===" % show_name)
	for seg in segments:
		lines.append(seg.narrative)
	return "\n".join(lines)
