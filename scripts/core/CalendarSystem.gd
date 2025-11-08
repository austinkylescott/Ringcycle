extends Node
class_name CalendarSystem

signal special_event(day:int, week:int, year:int)

func after_action_advance() -> void:
	GM.current_wrestler_node.age_one_day()
	GM.advance_day()

	# weekend shows (Sat = 6, Sun = 7), monthly beats, etc.
	if GM.day in [6,7]:
		emit_signal("special_event", GM.day, GM.week, GM.year)
