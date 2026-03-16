extends Node
class_name SessionLogger

# ---------------------------------------------------------------------------
# SessionLogger — single file per session, appended throughout.
# Console output is LIMITED to [EVT] and headers to avoid print overflow.
# Full detail ([SIM], [WEK], [PLY]) goes to file only.
# ---------------------------------------------------------------------------

var _file: FileAccess = null
var _file_path: String = ""


func _ready() -> void:
	_open_session()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close_session()


# ---------------------------------------------------------------------------
# Session open / close
# ---------------------------------------------------------------------------

func _open_session() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_file_path = "user://session_%s.txt" % timestamp
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	if _file == null:
		push_warning("SessionLogger: could not open log file at %s" % _file_path)
		return

	var header := "[SES] SESSION START — %s" % Time.get_datetime_string_from_system()
	_file_write("═══════════════════════════════════════════════════════")
	_file_write(header)
	_file_write("═══════════════════════════════════════════════════════")
	print("[SessionLogger] %s" % header)
	print("[SessionLogger] Writing to: %s" % ProjectSettings.globalize_path(_file_path))


func _close_session() -> void:
	if _file == null:
		return
	_file_write("═══════════════════════════════════════════════════════")
	_file_write("[SES] SESSION END — %s" % Time.get_datetime_string_from_system())
	_file_write("═══════════════════════════════════════════════════════")
	_file.close()
	_file = null


# ---------------------------------------------------------------------------
# Public write API
# ---------------------------------------------------------------------------

# Player action — file only (no console spam)
func log_player_action(action_name: String, stat_changes: Dictionary, wrestler: Wrestler) -> void:
	_file_write("[PLY] %s | %-22s | %s" % [
		_calendar_stamp(), action_name, _format_changes(stat_changes)
	])
	_file_write("       Fatigue: %d  Morale: %d  Days left: %d  Mood: %s" % [
		int(wrestler.get_stat("fatigue")),
		int(wrestler.get_stat("morale")),
		int(wrestler.get_stat("lifespan_days")),
		wrestler.get_personality_display(),
	])


# Simulator action — file only
func log_sim_action(
	day_of_week: int,
	action_name: String,
	stat_changes: Dictionary,
	wrestler: Wrestler
) -> void:
	_file_write("[SIM] %s | Day %d  %-22s | %s" % [
		_calendar_stamp(), day_of_week, action_name, _format_changes(stat_changes)
	])
	_file_write("       Fatigue: %d  Morale: %d  Days left: %d  Mood: %s" % [
		int(wrestler.get_stat("fatigue")),
		int(wrestler.get_stat("morale")),
		int(wrestler.get_stat("lifespan_days")),
		wrestler.get_personality_display(),
	])


# Notable event — console + file
func log_event(message: String) -> void:
	var line := "[EVT] %s | %s" % [_calendar_stamp(), message]
	print(line)
	_file_write(line)


# Weekly block — file only
func log_weekly_block(lines: Array[String]) -> void:
	for line in lines:
		_file_write("[WEK] %s" % line)


# Header / section marker — console + file
func log_header(text: String) -> void:
	var line := "─── %s" % text
	print(line)
	_file_write(line)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _calendar_stamp() -> String:
	return "Yr%d Mo%d Wk%d Day%d" % [GM.year, GM.month, GM.week, GM.day]


func _format_changes(changes: Dictionary) -> String:
	if changes.is_empty():
		return "(no change)"
	var parts: Array[String] = []
	for stat in changes.keys():
		var val: float = changes[stat]
		if abs(val) >= 0.5:
			parts.append("%s %+.0f" % [stat.substr(0, 3).to_upper(), val])
	return "  ".join(parts) if not parts.is_empty() else "(no change)"


func _file_write(line: String) -> void:
	if _file == null:
		return
	_file.store_line(line)
	_file.flush()
