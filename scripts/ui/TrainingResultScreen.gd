extends Control
class_name TrainingResultScreen

# ---------------------------------------------------------------------------
# TrainingResultScreen — Monster Rancher-style post-training result display.
# Shows before/after bars for all affected stats with animated gains/losses.
#
# Usage:
#   var screen = preload("res://scenes/menus/TrainingResultScreen.tscn").instantiate()
#   add_child(screen)
#   screen.present(action_name, stats_before, wrestler)
#   screen.dismissed.connect(_on_result_dismissed)
# ---------------------------------------------------------------------------

signal dismissed()

const STAT_DISPLAY_ORDER := [
	"power", "technique", "agility", "toughness", "stamina", "charisma",
	"fatigue", "morale",
]

const STAT_MAX := {
	"power": 999.0, "technique": 999.0, "agility": 999.0,
	"toughness": 999.0, "stamina": 999.0, "charisma": 999.0,
	"fatigue": 100.0, "morale": 100.0,
}

# Bar colors — core stats use accent, fatigue uses warning, morale uses positive
const COLOR_CORE    := Color(0.3, 0.7, 1.0)
const COLOR_FATIGUE := Color(1.0, 0.5, 0.2)
const COLOR_MORALE  := Color(0.3, 0.9, 0.4)
const COLOR_GAIN    := Color(0.4, 1.0, 0.5)
const COLOR_LOSS    := Color(1.0, 0.4, 0.4)

const ANIM_DURATION := 0.6   # seconds for bar to animate to new value
const FLOAT_DURATION := 1.2  # seconds for +N label to float and fade

@onready var title_label:   Label        = $Panel/VBox/TitleLabel
@onready var stat_rows:     VBoxContainer = $Panel/VBox/StatRows
@onready var confirm_btn:   Button        = $Panel/VBox/ConfirmButton

var _wrestler: Wrestler
var _stats_before: Dictionary
var _stats_after: Dictionary
var _row_refs: Dictionary = {}   # stat -> { bar_fill, value_label }


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm_pressed)
	confirm_btn.disabled = true


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

func present(action_name: String, stats_before: Dictionary, wrestler: Wrestler) -> void:
	_wrestler   = wrestler
	_stats_before = stats_before
	_stats_after  = {}
	for stat in STAT_DISPLAY_ORDER:
		_stats_after[stat] = wrestler.get_stat(stat)

	title_label.text = action_name

	_build_rows()
	await get_tree().process_frame
	await _animate_rows()

	confirm_btn.disabled = false


# ---------------------------------------------------------------------------
# Build stat rows
# ---------------------------------------------------------------------------

func _build_rows() -> void:
	for child in stat_rows.get_children():
		child.queue_free()
	_row_refs.clear()

	for stat in STAT_DISPLAY_ORDER:
		var before: float = _stats_before.get(stat, 0.0)
		var after: float  = _stats_after.get(stat, 0.0)
		var max_val: float = STAT_MAX.get(stat, 999.0)

		# Row container
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)

		# Stat name label
		var name_lbl := Label.new()
		name_lbl.text = stat.capitalize()
		name_lbl.custom_minimum_size = Vector2(90, 0)
		row.add_child(name_lbl)

		# Bar background
		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(200, 16)
		bar_bg.color = Color(0.15, 0.15, 0.15)

		# Bar fill — starts at before value
		var bar_fill := ColorRect.new()
		bar_fill.custom_minimum_size = Vector2(0, 16)
		bar_fill.size_flags_vertical = Control.SIZE_FILL
		bar_fill.color = _bar_color(stat)
		bar_fill.size = Vector2((before / max_val) * 200.0, 16)

		bar_bg.add_child(bar_fill)
		row.add_child(bar_bg)

		# Value label — shows current value
		var val_lbl := Label.new()
		val_lbl.text = "%d" % int(before)
		val_lbl.custom_minimum_size = Vector2(50, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)

		stat_rows.add_child(row)
		_row_refs[stat] = { "bar_fill": bar_fill, "value_label": val_lbl, "bar_bg": bar_bg }


# ---------------------------------------------------------------------------
# Animate rows from before to after values
# ---------------------------------------------------------------------------

func _animate_rows() -> void:
	var tweens: Array = []

	for stat in STAT_DISPLAY_ORDER:
		var before: float = _stats_before.get(stat, 0.0)
		var after: float  = _stats_after.get(stat, 0.0)
		var delta := after - before

		if abs(delta) < 0.5:
			continue

		var refs: Dictionary = _row_refs[stat]
		var bar_fill: ColorRect = refs["bar_fill"]
		var val_lbl: Label      = refs["value_label"]
		var max_val: float      = STAT_MAX.get(stat, 999.0)

		var target_width := (after / max_val) * 200.0

		# Tween bar width
		var tw := create_tween()
		tw.tween_property(bar_fill, "size:x", target_width, ANIM_DURATION).set_ease(Tween.EASE_OUT)
		tweens.append(tw)

		# Tween value label
		var tw2 := create_tween()
		tw2.tween_method(
			func(v: float): val_lbl.text = "%d" % int(v),
			before, after, ANIM_DURATION
		).set_ease(Tween.EASE_OUT)
		tweens.append(tw2)

		# Spawn floating +N / -N label
		_spawn_float_label(refs["bar_bg"], delta)

	# Wait for the longest animation
	if not tweens.is_empty():
		await get_tree().create_timer(ANIM_DURATION + 0.1).timeout


# ---------------------------------------------------------------------------
# Floating delta label
# ---------------------------------------------------------------------------

func _spawn_float_label(anchor: Control, delta: float) -> void:
	var lbl := Label.new()
	lbl.text = "%+.0f" % delta
	lbl.modulate = COLOR_GAIN if delta > 0 else COLOR_LOSS
	lbl.position = Vector2(anchor.size.x * 0.5, 0)

	# Add to the bar background so it floats over the bar
	anchor.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", -24.0, FLOAT_DURATION).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, FLOAT_DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _bar_color(stat: String) -> Color:
	match stat:
		"fatigue": return COLOR_FATIGUE
		"morale":  return COLOR_MORALE
		_:         return COLOR_CORE


func _on_confirm_pressed() -> void:
	emit_signal("dismissed")
	queue_free()
