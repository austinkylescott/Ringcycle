extends Control
class_name ShowScreen

# ---------------------------------------------------------------------------
# ShowScreen — displays a completed ShowResult as a play-by-play card.
# ---------------------------------------------------------------------------

signal dismissed()

const SEGMENT_REVEAL_DELAY := 0.6

const COLOR_WIN          := Color(0.3, 0.9, 0.4)
const COLOR_LOSS         := Color(1.0, 0.4, 0.4)
const COLOR_NEUTRAL      := Color(0.8, 0.8, 0.8)
const COLOR_TITLE        := Color(1.0, 0.85, 0.2)
const COLOR_FRAME        := Color(0.5, 0.5, 0.5)
const COLOR_PROMO_STRONG := Color(0.4, 0.8, 1.0)
const COLOR_PROMO_HEAT   := Color(1.0, 0.6, 0.2)

@onready var show_title_label: Label           = $Panel/VBox/ShowTitleLabel
@onready var show_meta_label:  Label           = $Panel/VBox/ShowMetaLabel
@onready var segment_list:     VBoxContainer   = $Panel/VBox/ScrollContainer/SegmentList
@onready var summary_label:    Label           = $Panel/VBox/SummaryLabel
@onready var close_button:     Button          = $Panel/VBox/CloseButton
@onready var scroll_container: ScrollContainer = $Panel/VBox/ScrollContainer

var _result: ShowResult = null


func _ready() -> void:
	close_button.disabled = true
	close_button.pressed.connect(_on_close_pressed)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func present(result: ShowResult) -> void:
	_result = result

	show_title_label.text = result.show_name
	show_meta_label.text  = "Yr %d  Mo %d  Wk %d  |  %s%s" % [
		result.year,
		result.month,
		result.week,
		result.promotion_name,
		"  —  PLE" if result.is_ple else "",
	]

	_reveal_segments()


# ---------------------------------------------------------------------------
# Segment reveal
# ---------------------------------------------------------------------------

func _reveal_segments() -> void:
	close_button.disabled = true

	for seg in _result.segments:
		await get_tree().create_timer(SEGMENT_REVEAL_DELAY).timeout
		_add_segment_row(seg)
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(
			scroll_container.get_v_scroll_bar().max_value
		)

	await get_tree().create_timer(SEGMENT_REVEAL_DELAY).timeout
	_build_summary()
	close_button.disabled = false


# ---------------------------------------------------------------------------
# Build one segment row
# ---------------------------------------------------------------------------

func _add_segment_row(seg: ShowSegment) -> void:
	if seg.type == "show_frame":
		var lbl := Label.new()
		lbl.text          = seg.narrative
		lbl.modulate      = COLOR_FRAME
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		segment_list.add_child(lbl)
		_add_divider()
		return

	var block := VBoxContainer.new()

	# Header row
	var header := HBoxContainer.new()

	var type_badge := Label.new()
	var badge_text: String = ""
	match seg.type:
		"match":        badge_text = "[MATCH]"
		"promo":        badge_text = "[PROMO]"
		"interference": badge_text = "[RUN-IN]"
	type_badge.text              = badge_text
	type_badge.custom_minimum_size = Vector2(80, 0)
	type_badge.modulate          = _badge_color(seg)
	header.add_child(type_badge)

	var participants := Label.new()
	if seg.participant_b != "":
		participants.text = "%s  vs.  %s" % [seg.participant_a, seg.participant_b]
	else:
		participants.text = seg.participant_a
	participants.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(participants)

	if seg.type in ["match", "promo"] and seg.is_player:
		var outcome_lbl := Label.new()
		outcome_lbl.text     = _outcome_display(seg)
		outcome_lbl.modulate = _outcome_color(seg)
		header.add_child(outcome_lbl)

	block.add_child(header)

	if seg.is_title_match:
		var title_lbl := Label.new()
		title_lbl.text     = "  ★ %s" % seg.title_name
		title_lbl.modulate = COLOR_TITLE
		block.add_child(title_lbl)

	var narrative_lbl := Label.new()
	narrative_lbl.text          = "  %s" % seg.narrative
	narrative_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_lbl.modulate      = COLOR_NEUTRAL
	block.add_child(narrative_lbl)

	if seg.is_player and abs(seg.fame_delta) >= 0.5:
		var fame_lbl := Label.new()
		fame_lbl.text    = "  Fame: %+.0f" % seg.fame_delta
		fame_lbl.modulate = COLOR_WIN if seg.fame_delta > 0.0 else COLOR_LOSS
		block.add_child(fame_lbl)

	segment_list.add_child(block)
	_add_divider()


func _add_divider() -> void:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.2)
	segment_list.add_child(sep)


# ---------------------------------------------------------------------------
# Summary block
# ---------------------------------------------------------------------------

func _build_summary() -> void:
	if _result == null:
		return

	var parts: Array[String] = []

	if _result.player_match_won:
		parts.append("Won their match")
	else:
		parts.append("Lost their match")

	var fame: float = _result.total_fame_delta
	if abs(fame) >= 0.5:
		parts.append("Fame %+.0f" % fame)

	if _result.title_changed:
		parts.append("★ Title changed hands")

	summary_label.text     = " · ".join(parts)
	summary_label.modulate = COLOR_WIN if _result.player_match_won else COLOR_LOSS


# ---------------------------------------------------------------------------
# Color / display helpers
# ---------------------------------------------------------------------------

func _badge_color(seg: ShowSegment) -> Color:
	if seg.type == "match":
		if not seg.is_player:
			return COLOR_NEUTRAL
		return COLOR_WIN if seg.player_won else COLOR_LOSS
	if seg.type == "promo":
		match seg.outcome_tier:
			"strong": return COLOR_PROMO_STRONG
			"heat":   return COLOR_PROMO_HEAT
		return COLOR_NEUTRAL
	return COLOR_NEUTRAL


func _outcome_display(seg: ShowSegment) -> String:
	if seg.type == "match":
		var tier: String = seg.outcome_tier.capitalize()
		return "WIN (%s)" % tier if seg.player_won else "LOSS (%s)" % tier
	if seg.type == "promo":
		return seg.outcome_tier.capitalize()
	return ""


func _outcome_color(seg: ShowSegment) -> Color:
	if seg.type == "match":
		return COLOR_WIN if seg.player_won else COLOR_LOSS
	if seg.type == "promo":
		match seg.outcome_tier:
			"strong": return COLOR_PROMO_STRONG
			"heat":   return COLOR_PROMO_HEAT
			"flat":   return COLOR_LOSS
		return COLOR_NEUTRAL
	return COLOR_NEUTRAL


# ---------------------------------------------------------------------------
# Close
# ---------------------------------------------------------------------------

func _on_close_pressed() -> void:
	emit_signal("dismissed")
	queue_free()
