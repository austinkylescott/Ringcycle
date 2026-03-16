extends Node
class_name CareerSimulator

# ---------------------------------------------------------------------------
# CareerSimulator — synchronous career simulation.
# Calls GM.advance_day() exactly once per simulated day. That's it.
# GM handles lifespan, death, calendar, evolution, coaches atomically.
#
# LOG VERBOSITY — set to false to silence that category:
# ---------------------------------------------------------------------------
const LOG_DAILY_ACTION       := true
const LOG_DAILY_FATIGUE      := true
const LOG_WEEKLY_SUMMARY     := true
const LOG_WEEKLY_PRESSURE    := true
const LOG_EVOLUTION_PROGRESS := true
const LOG_NOTABLE_EVENTS     := true

const DAYS_PER_WEEK  := 7
const DAYS_PER_MONTH := 28
const DAYS_PER_YEAR  := 336   # 12 months × 4 weeks × 7 days

const REST_FATIGUE_THRESHOLD := 70
const INTENSIVE_FATIGUE_MAX  := 30
const INTENSIVE_MORALE_MIN   := 60

# Chance per sim run that the simulator plays a specialist strategy
# (drills one stat heavily, neglects others — exercises Legend B path)
const SPECIALIST_STRATEGY_CHANCE := 0.25

const STANDARD_ACTIONS := [
	"Power Drill", "Technique Practice", "Conditioning",
	"Agility Drills", "Toughness Training", "Showmanship",
]
const INTENSIVE_ACTIONS := [
	"Heavy Lifting", "Sparring", "Endurance Run",
	"Speed Work", "Iron Circuit", "Crowd Work",
]

var _ts: TrainingSystem = null
var _week_stat_gains: Dictionary = {}
var _is_running: bool = false

# Strategy for this run — set once at simulate_days() start
var _is_specialist: bool = false
var _specialist_stat: String = ""  # The stat being drilled
var _neglect_stat: String = ""     # The stat being ignored

signal simulation_completed


func _ready() -> void:
	_ts = TrainingSystem.new()
	add_child(_ts)
	# Listen to GM's week_started to notify TrainingSystem
	GM.week_started.connect(_on_week_started)


func _on_week_started(wrestler: Wrestler) -> void:
	if wrestler != null:
		_ts.on_week_start(wrestler)


# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

func simulate_weeks(num_weeks: int) -> void:
	simulate_days(num_weeks * DAYS_PER_WEEK)


func simulate_days(num_days: int) -> void:
	if _is_running:
		push_warning("CareerSimulator: already running")
		return
	_is_running = true
	_week_stat_gains.clear()

	# Roll strategy for this run
	_is_specialist = randf() < SPECIALIST_STRATEGY_CHANCE
	if _is_specialist:
		# Pick a random stat to drill and a random stat to neglect
		var stats := StatDefs.CORE.duplicate()
		stats.shuffle()
		_specialist_stat = stats[0]
		_neglect_stat    = stats[1]

	var wrestler := GM.current_wrestler_node
	SL.log_header("SIM START — %d days | %s | Stage: %s | Personality: %s | Strategy: %s" % [
		num_days,
		wrestler.get_display_name(),
		wrestler.get_stage(),
		wrestler.get_personality_display(),
		"Specialist (%s)" % _specialist_stat if _is_specialist else "Balanced",
	])

	var day_of_week := 1
	var week_number := 1

	for _day_index in range(num_days):
		if day_of_week == 1:
			SL.log_header("WEEK %d" % week_number)

		var died := _simulate_one_day(week_number, day_of_week)

		if died:
			# Wrestler died mid-week — flush partial summary and continue
			_flush_weekly_summary(week_number)
			_week_stat_gains.clear()
			# Re-roll strategy for the new wrestler
			_is_specialist = randf() < SPECIALIST_STRATEGY_CHANCE
			if _is_specialist:
				var stats := StatDefs.CORE.duplicate()
				stats.shuffle()
				_specialist_stat = stats[0]
				_neglect_stat    = stats[1]

		wrestler = GM.current_wrestler_node

		if day_of_week == DAYS_PER_WEEK:
			_flush_weekly_summary(week_number)
			_week_stat_gains.clear()
			day_of_week = 1
			week_number += 1
		else:
			day_of_week += 1

	# Flush partial week at end
	if day_of_week > 1:
		_flush_weekly_summary(week_number)

	SL.log_header("SIM END")
	_log_final_summary()

	_is_running = false
	emit_signal("simulation_completed")


# ---------------------------------------------------------------------------
# Simulate one day — returns true if the wrestler died this day
# ---------------------------------------------------------------------------

func _simulate_one_day(_week: int, day_of_week: int) -> bool:
	var wrestler := GM.current_wrestler_node
	if wrestler == null:
		return false

	var action             := _choose_action(wrestler, day_of_week)
	var stats_before       := _snapshot_stats(wrestler)
	var personality_before := wrestler.res.personality
	var stage_before       := wrestler.res.stage

	# Apply training
	_ts.apply_training(wrestler, action)

	# Advance the day — this is the ONLY call that touches calendar or lifespan
	var died := GM.advance_day()

	if died:
		if LOG_NOTABLE_EVENTS:
			SL.log_event("DEATH — %s after %d days" % [
				wrestler.get_display_name(),
				int(wrestler.get_stat("days_lived")),
			])
			_log_final_summary()
			var new_w := GM.current_wrestler_node
			if new_w != null:
				SL.log_event("NEW WRESTLER — %s | Stage: %s" % [
					new_w.get_display_name(), new_w.get_stage()
				])
		_week_stat_gains.clear()
		return true

	# Re-fetch wrestler in case evolution swapped species reference
	wrestler = GM.current_wrestler_node

	# Evolution check
	if wrestler.res.stage != stage_before and LOG_NOTABLE_EVENTS:
		SL.log_event("EVOLUTION — %s → %s" % [stage_before, wrestler.res.stage])
		_log_stat_spread(wrestler)

	# Personality shift check
	if wrestler.res.personality != personality_before and LOG_NOTABLE_EVENTS:
		SL.log_event("PERSONALITY SHIFT — %s → %s" % [
			PersonalityDefs.get_display_name(personality_before),
			wrestler.get_personality_display(),
		])

	# Fame stub — simulate doing a show on weekends (days 6-7)
	# Shows grant +3 Fame, fires show pressure events
	if GM.day in [6, 7]:
		var current_fame := int(wrestler.get_stat("fame"))
		if current_fame < 100:
			wrestler.add_to_stat("fame", 3)
			# Simulate a win ~60% of the time for realistic pressure distribution
			if randf() < 0.6:
				wrestler.trigger_event("show_win")
			else:
				wrestler.trigger_event("show_loss")

	# Log daily action
	if LOG_DAILY_ACTION:
		var changes := _diff_stats(stats_before, wrestler)
		SL.log_sim_action(day_of_week, action, changes, wrestler)

	# Accumulate weekly stat gains
	for stat in StatDefs.CORE:
		var gain: float = wrestler.get_stat(stat) - stats_before.get(stat, 0.0)
		_week_stat_gains[stat] = _week_stat_gains.get(stat, 0.0) + gain

	return false


# ---------------------------------------------------------------------------
# Action selection
# ---------------------------------------------------------------------------

func _choose_action(wrestler: Wrestler, day_of_week: int) -> String:
	var fatigue := wrestler.get_stat("fatigue")
	var morale  := wrestler.get_stat("morale")

	# Always rest if too fatigued
	if fatigue >= REST_FATIGUE_THRESHOLD:
		return "Rest"

	# On weekends the sim attends a show instead of training
	# (Fame is handled after advance_day, this just skips training that day)
	if day_of_week in [6, 7]:
		return "Rest"

	var use_intensive := fatigue <= INTENSIVE_FATIGUE_MAX and morale >= INTENSIVE_MORALE_MIN

	var pool: Array[String] = []

	if _is_specialist:
		# Specialist strategy: heavily favour the specialist stat,
		# give zero tickets to the neglected stat
		for action in STANDARD_ACTIONS:
			var stat := _action_to_stat(action)
			if stat == _neglect_stat:
				continue  # Never train the neglected stat
			elif stat == _specialist_stat:
				for _t in range(6):  # 6 tickets — strongly favoured
					pool.append(action)
			else:
				pool.append(action)  # 1 ticket — trained occasionally
	else:
		# Balanced strategy: weight toward undertrained stats
		var session_counts := wrestler.res.training_session_counts
		var sorted_stats := StatDefs.CORE.duplicate()
		sorted_stats.sort_custom(func(a, b):
			return session_counts.get(a, 0) < session_counts.get(b, 0)
		)
		for i in range(sorted_stats.size()):
			var stat: String = sorted_stats[i]
			var action := _stat_to_standard_action(stat)
			if action != "":
				var tickets := 3 if i < 3 else 1
				for _t in range(tickets):
					pool.append(action)

	if use_intensive:
		for action in INTENSIVE_ACTIONS:
			# Specialist skips intensive actions for the neglected stat
			if _is_specialist and _action_to_stat(action) == _neglect_stat:
				continue
			pool.append(action)

	if pool.is_empty():
		return "Rest"

	return pool[randi() % pool.size()]


func _stat_to_standard_action(stat: String) -> String:
	match stat:
		"power":     return "Power Drill"
		"technique": return "Technique Practice"
		"stamina":   return "Conditioning"
		"agility":   return "Agility Drills"
		"toughness": return "Toughness Training"
		"charisma":  return "Showmanship"
	return ""


func _action_to_stat(action: String) -> String:
	match action:
		"Power Drill", "Heavy Lifting":          return "power"
		"Technique Practice", "Sparring":        return "technique"
		"Conditioning", "Endurance Run":         return "stamina"
		"Agility Drills", "Speed Work":          return "agility"
		"Toughness Training", "Iron Circuit":    return "toughness"
		"Showmanship", "Crowd Work":             return "charisma"
	return ""


# ---------------------------------------------------------------------------
# Weekly summary
# ---------------------------------------------------------------------------

func _flush_weekly_summary(week: int) -> void:
	var wrestler := GM.current_wrestler_node
	if wrestler == null:
		return

	var lines: Array[String] = []

	if LOG_WEEKLY_SUMMARY:
		lines.append("── Week %d Summary ──" % week)
		for stat in StatDefs.CORE:
			var gain: float = _week_stat_gains.get(stat, 0.0)
			var current := int(wrestler.get_stat(stat))
			lines.append("  %-12s %+.0f  (now %d)" % [stat.capitalize(), gain, current])
		lines.append("  Fame: %d" % int(wrestler.get_stat("fame")))

	if LOG_WEEKLY_PRESSURE:
		var pressure := wrestler.res.personality_pressure
		if not pressure.is_empty():
			lines.append("  Personality pressure:")
			for pid in pressure.keys():
				var val: float = pressure[pid]
				if val > 0.5:
					var pct := int((val / PersonalityDefs.SHIFT_THRESHOLD) * 100.0)
					lines.append("    %-14s %.1f/%.0f (%d%%)" % [
						pid, val, PersonalityDefs.SHIFT_THRESHOLD, pct
					])

	if LOG_EVOLUTION_PROGRESS:
		lines.append_array(_build_evolution_progress_lines(wrestler))

	SL.log_weekly_block(lines)


func _build_evolution_progress_lines(wrestler: Wrestler) -> Array[String]:
	var lines: Array[String] = []
	var root: Window = Engine.get_main_loop().root
	if not root.has_node("/root/ES"):
		return lines

	var es := root.get_node("/root/ES") as EvolutionSystem
	if es == null:
		return lines

	var line := es.get_line_for_species(
		wrestler.res.species.id if wrestler.res.species != null else ""
	)
	if line == null:
		return lines

	var transitions: Array[String] = []
	match wrestler.res.stage:
		"Rookie":                                   transitions = ["rookie_to_pro"]
		"Pro":                                      transitions = ["legend_a", "legend_b", "legend_c"]
		"Legend_A", "Legend_B", "Legend_C":         transitions = []  # Max stage

	if transitions.is_empty():
		lines.append("  Evolution progress: Max stage reached (%s)" % wrestler.res.stage)
		return lines

	lines.append("  Evolution progress:")
	for transition in transitions:
		var conditions := line.get_conditions(transition)
		if conditions.is_empty():
			continue
		var passed := 0
		var details: Array[String] = []
		for c in conditions:
			var result: bool = c.evaluate(wrestler.res)
			if result:
				passed += 1
			details.append("%s:%s" % [c.describe(), "✓" if result else "✗"])
		lines.append("    [%s] %d/%d — %s" % [
			transition, passed, conditions.size(), ", ".join(details)
		])

	return lines


# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------

func _log_final_summary() -> void:
	var wrestler := GM.current_wrestler_node
	if wrestler == null:
		return
	SL.log_header("FINAL — %s | Stage: %s | Personality: %s | Days: %d" % [
		wrestler.get_display_name(),
		wrestler.get_stage(),
		wrestler.get_personality_display(),
		int(wrestler.get_stat("days_lived")),
	])
	_log_stat_spread(wrestler)
	SL.log_header("Fatigue: %d | Morale: %d | Fame: %d | Stress: %.2f | Injuries: %d" % [
		int(wrestler.get_stat("fatigue")),
		int(wrestler.get_stat("morale")),
		int(wrestler.get_stat("fame")),
		wrestler.res.career_stress_accumulated,
		wrestler.res.injuries_sustained,
	])


func _log_stat_spread(wrestler: Wrestler) -> void:
	var parts: Array[String] = []
	for stat in StatDefs.CORE:
		parts.append("%s:%d" % [stat.substr(0, 3).to_upper(), int(wrestler.get_stat(stat))])
	SL.log_header("Stats: %s" % "  ".join(parts))


# ---------------------------------------------------------------------------
# Stat helpers
# ---------------------------------------------------------------------------

func _snapshot_stats(wrestler: Wrestler) -> Dictionary:
	var snap := {}
	for stat in StatDefs.CORE:
		snap[stat] = wrestler.get_stat(stat)
	snap["fatigue"] = wrestler.get_stat("fatigue")
	snap["morale"]  = wrestler.get_stat("morale")
	return snap


func _diff_stats(before: Dictionary, wrestler: Wrestler) -> Dictionary:
	var diff := {}
	for stat in before.keys():
		var delta: float = wrestler.get_stat(stat) - before.get(stat, 0.0)
		if abs(delta) >= 0.5:
			diff[stat] = delta
	return diff
