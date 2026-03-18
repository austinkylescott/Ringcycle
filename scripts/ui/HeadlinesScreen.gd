extends Control
class_name HeadlinesScreen

# ---------------------------------------------------------------------------
# HeadlinesScreen — scrollable newspaper-style headlines feed.
# Reads from HeadlineLog via get_node("/root/HL") to avoid parse-time
# autoload resolution issues.
# ---------------------------------------------------------------------------

signal dismissed()

const FILTER_ALL       := "all"
const FILTER_THIS_WEEK := "this_week"
const FILTER_RECENT    := "recent"

const COLOR_TITLE_CHANGE := Color(1.0, 0.85, 0.2)
const COLOR_UPSET        := Color(0.8, 0.4, 1.0)
const COLOR_DOMINANT     := Color(0.3, 0.9, 0.4)
const COLOR_DEATH        := Color(0.6, 0.6, 0.6)
const COLOR_PROMOTION    := Color(0.4, 0.8, 1.0)
const COLOR_DEFAULT      := Color(0.9, 0.9, 0.9)
const COLOR_DATE         := Color(0.5, 0.5, 0.5)

@onready var headline_list:        VBoxContainer  = $Panel/VBox/ScrollContainer/HeadlineList
@onready var empty_label:          Label          = $Panel/VBox/EmptyLabel
@onready var close_button:         Button         = $Panel/VBox/CloseButton
@onready var filter_all_button:    Button         = $Panel/VBox/FilterBar/FilterAllButton
@onready var filter_week_button:   Button         = $Panel/VBox/FilterBar/FilterThisWeekButton
@onready var filter_recent_button: Button         = $Panel/VBox/FilterBar/FilterRecentButton

var _current_filter: String = FILTER_ALL


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	filter_all_button.pressed.connect(func(): _set_filter(FILTER_ALL))
	filter_week_button.pressed.connect(func(): _set_filter(FILTER_THIS_WEEK))
	filter_recent_button.pressed.connect(func(): _set_filter(FILTER_RECENT))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func present() -> void:
	_build_list()


# ---------------------------------------------------------------------------
# HeadlineLog accessor — safe get_node call
# ---------------------------------------------------------------------------

func _hl() -> HeadlineLog:
	return get_node("/root/HL") as HeadlineLog


# ---------------------------------------------------------------------------
# List building
# ---------------------------------------------------------------------------

func _build_list() -> void:
	for child in headline_list.get_children():
		child.queue_free()

	var hl: HeadlineLog = _hl()
	if hl == null:
		empty_label.visible = true
		return

	var entries: Array = _get_filtered_entries(hl)
	empty_label.visible = entries.is_empty()

	if entries.is_empty():
		return

	var current_stamp: String = ""
	for entry in entries:
		var stamp: String = _date_stamp(entry)
		if stamp != current_stamp:
			current_stamp = stamp
			_add_date_header(stamp)
		_add_headline_row(entry)


func _get_filtered_entries(hl: HeadlineLog) -> Array:
	match _current_filter:
		FILTER_THIS_WEEK: return hl.get_this_week()
		FILTER_RECENT:    return hl.get_recent(4)
		_:                return hl.get_all()


func _set_filter(filter: String) -> void:
	_current_filter = filter
	filter_all_button.button_pressed    = filter == FILTER_ALL
	filter_week_button.button_pressed   = filter == FILTER_THIS_WEEK
	filter_recent_button.button_pressed = filter == FILTER_RECENT
	_build_list()


# ---------------------------------------------------------------------------
# Row builders
# ---------------------------------------------------------------------------

func _add_date_header(stamp: String) -> void:
	var lbl := Label.new()
	lbl.text                 = "── %s ──" % stamp
	lbl.modulate             = COLOR_DATE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline_list.add_child(lbl)


func _add_headline_row(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)

	var bullet := Label.new()
	bullet.text                = "•"
	bullet.custom_minimum_size = Vector2(20, 0)
	bullet.modulate            = _headline_color(entry)
	row.add_child(bullet)

	var lbl := Label.new()
	lbl.text                  = entry.get("text", "")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate              = _headline_color(entry)
	row.add_child(lbl)

	headline_list.add_child(row)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _date_stamp(entry: Dictionary) -> String:
	return "Year %d  Month %d  Week %d" % [
		entry.get("year", 0),
		entry.get("month", 0),
		entry.get("week", 0),
	]


func _headline_color(entry: Dictionary) -> Color:
	match entry.get("type", "general"):
		"title_change":  return COLOR_TITLE_CHANGE
		"win_upset":     return COLOR_UPSET
		"win_dominant":  return COLOR_DOMINANT
		"npc_death":     return COLOR_DEATH
		"promotion":     return COLOR_PROMOTION
	return COLOR_DEFAULT


# ---------------------------------------------------------------------------
# Close
# ---------------------------------------------------------------------------

func _on_close_pressed() -> void:
	emit_signal("dismissed")
	queue_free()
