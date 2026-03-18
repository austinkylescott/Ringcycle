extends Node
class_name ShowManager

# ---------------------------------------------------------------------------
# ShowManager — autoload alias "SM"
# Books and resolves one show per call to run_show().
# ---------------------------------------------------------------------------

signal show_completed(result: ShowResult)

const RANK_ADVANTAGE_PER_TIER := 15.0
const MATCH_ROLL_RANGE        := 40.0
const PROMO_ROLL_RANGE        := 0.25

const FAME_WIN_DOMINANT  :=  5.0
const FAME_WIN_CLEAN     :=  3.0
const FAME_WIN_CLOSE     :=  2.0
const FAME_WIN_UPSET     :=  8.0
const FAME_LOSS_DOMINANT := -2.0
const FAME_LOSS_CLOSE    :=  1.0
const FAME_PROMO_STRONG  :=  3.0
const FAME_PROMO_DECENT  :=  1.0
const FAME_PROMO_FLAT    :=  0.0
const FAME_PROMO_HEAT    := -1.0

const SHOW_FATIGUE_COST  := 15.0
const SHOW_STRESS_COST   := 0.02


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

func run_show() -> ShowResult:
	var wrestler: Wrestler = GM.current_wrestler_node
	if wrestler == null:
		push_warning("ShowManager.run_show: no active wrestler")
		return null

	var rank: String             = GM.get_player_rank()
	var promo: PromotionResource = _get_show_promotion(rank)
	var is_ple: bool             = promo != null and promo.is_ple_week(GM.week)
	var result: ShowResult       = ShowResult.new()

	result.promotion_name = promo.display_name if promo != null else "Indie Circuit"
	result.show_name      = promo.get_show_name(GM.week) if promo != null else "Indie Show"
	result.is_ple         = is_ple
	result.week           = GM.week
	result.month          = GM.month
	result.year           = GM.year

	result.add_segment(_build_show_opener(result, promo))
	result.add_segment(_resolve_player_promo(wrestler, rank, promo))
	result.add_segment(_resolve_player_match(wrestler, rank, promo, is_ple))

	var bg_count: int = 2 if is_ple else 1
	for _i in range(bg_count):
		var bg_seg: ShowSegment = _resolve_background_segment(rank, promo)
		if bg_seg != null:
			result.add_segment(bg_seg)

	result.add_segment(_build_show_closer(result, promo))

	wrestler.add_to_stat("fatigue", SHOW_FATIGUE_COST)
	wrestler.apply_stress(SHOW_STRESS_COST)

	if GM.is_contracted():
		GM.contract_shows_attended += 1

	SL.log_event("SHOW — %s | %s | Yr%d Mo%d Wk%d" % [
		result.show_name, result.promotion_name,
		result.year, result.month, result.week,
	])
	for seg in result.segments:
		SL.log_event("  %s" % seg.narrative)

	emit_signal("show_completed", result)
	return result


# ---------------------------------------------------------------------------
# Show opener / closer
# ---------------------------------------------------------------------------

func _build_show_opener(result: ShowResult, promo: PromotionResource) -> ShowSegment:
	var seg: ShowSegment = ShowSegment.new()
	seg.type      = "show_frame"
	seg.is_player = false

	var champ_name: String = ""
	if promo != null and not promo.championships.is_empty():
		champ_name = promo.championships[0].display_name

	seg.narrative = NarrativeLibrary.get_show_frame({
		"promotion": result.promotion_name,
		"title":     champ_name,
		"is_ple":    result.is_ple,
		"is_opener": true,
	})
	return seg


func _build_show_closer(result: ShowResult, promo: PromotionResource) -> ShowSegment:
	var seg: ShowSegment = ShowSegment.new()
	seg.type      = "show_frame"
	seg.is_player = false
	seg.narrative = NarrativeLibrary.get_show_frame({
		"promotion": result.promotion_name,
		"is_ple":    result.is_ple,
		"is_opener": false,
	})
	return seg


# ---------------------------------------------------------------------------
# Player promo resolution
# ---------------------------------------------------------------------------

func _resolve_player_promo(
	wrestler: Wrestler,
	rank: String,
	promo: PromotionResource
) -> ShowSegment:
	var seg: ShowSegment  = ShowSegment.new()
	seg.type              = "promo"
	seg.is_player         = true
	seg.participant_a     = wrestler.get_display_name()

	var seg_type: String        = "ring_solo"
	var partner_npc: NPCResource = null
	var rel_type: String        = ""

	var hot_rel: RelationshipRecord = _get_hottest_player_relationship(rank)
	if hot_rel != null:
		var rm: RosterManager = get_node("/root/RM")
		var npc: NPCResource  = rm.get_npc(hot_rel.other_id)
		if npc != null:
			partner_npc       = npc
			seg.participant_b = npc.display_name
			rel_type          = hot_rel.type
			if hot_rel.has_heat():
				seg_type = "ring_confrontation"
			else:
				seg_type = "backstage_duo"

	var base_score: float  = _player_promo_score(wrestler)
	var roll: float        = (randf() * PROMO_ROLL_RANGE) - (PROMO_ROLL_RANGE * 0.5)
	var final_score: float = clamp(base_score + roll, 0.0, 1.0)

	var outcome_tier: String = _promo_tier_from_score(final_score)
	seg.outcome_tier         = outcome_tier

	var fame_delta: float = _promo_fame_delta(outcome_tier)
	if promo != null:
		fame_delta *= promo.prestige
	wrestler.add_to_stat("fame", fame_delta)
	seg.fame_delta = fame_delta

	if partner_npc != null:
		var event_type: String = "promo_confrontation" if hot_rel.has_heat() else "promo_ally"
		GM.record_player_interaction(partner_npc.id, event_type)
		_record_npc_interaction(partner_npc, "player", event_type)
		seg.relationship_event = event_type

	seg.narrative = NarrativeLibrary.get_promo_result({
		"a":                wrestler.get_display_name(),
		"b":                seg.participant_b,
		"segment_type":     seg_type,
		"outcome_tier":     outcome_tier,
		"relationship_type": rel_type,
		"promotion":        promo.display_name if promo != null else "",
	})

	if outcome_tier == "strong":
		wrestler.trigger_event("crowd_loved")
	elif outcome_tier == "heat":
		wrestler.trigger_event("crowd_ignored")

	if outcome_tier in ["strong", "heat"]:
		_add_headline("win_dominant", {
			"a":         wrestler.get_display_name(),
			"promotion": promo.display_name if promo != null else "Indie Circuit",
		})

	return seg


# ---------------------------------------------------------------------------
# Player match resolution
# ---------------------------------------------------------------------------

func _resolve_player_match(
	wrestler: Wrestler,
	rank: String,
	promo: PromotionResource,
	is_ple: bool
) -> ShowSegment:
	var seg: ShowSegment  = ShowSegment.new()
	seg.type              = "match"
	seg.is_player         = true
	seg.participant_a     = wrestler.get_display_name()

	var rm: RosterManager       = get_node("/root/RM")
	var opponent: NPCResource   = _pick_opponent(rank, wrestler)
	seg.participant_b           = opponent.display_name

	var is_title_match: bool = is_ple and int(wrestler.get_stat("fame")) >= 50
	var title_name: String   = ""
	if is_title_match and promo != null and not promo.championships.is_empty():
		title_name         = promo.championships[0].display_name
		seg.is_title_match = true
		seg.title_name     = title_name

	var player_score: float   = _player_combat_score(wrestler)
	var opponent_score: float = opponent.get_combat_score()

	var rank_diff: int = _rank_diff(rank, opponent.rank)
	player_score += float(rank_diff) * RANK_ADVANTAGE_PER_TIER

	var player_roll: float   = (randf() + randf()) * 0.5 * MATCH_ROLL_RANGE
	var opponent_roll: float = (randf() + randf()) * 0.5 * MATCH_ROLL_RANGE

	var player_final: float   = player_score   + player_roll
	var opponent_final: float = opponent_score + opponent_roll

	var player_won: bool  = player_final >= opponent_final
	var margin_pct: float = abs(player_final - opponent_final) / max(player_final, opponent_final)
	var was_upset: bool   = player_won and opponent_score > player_score * 1.2

	var outcome_tier: String = _match_outcome_tier(player_won, margin_pct, was_upset)
	seg.outcome_tier         = outcome_tier
	seg.player_won           = player_won

	var prestige: float   = promo.prestige if promo != null else 1.0
	var fame_delta: float = _match_fame_delta(outcome_tier, player_won) * prestige
	wrestler.add_to_stat("fame", fame_delta)
	seg.fame_delta = fame_delta

	if player_won:
		opponent.losses += 1
		wrestler.trigger_event("show_win")
	else:
		opponent.wins += 1
		wrestler.trigger_event("show_loss")

	if is_title_match and promo != null:
		_resolve_title_match(wrestler, opponent, promo, player_won, seg)

	var match_event: String = "match_win" if player_won else "match_loss"
	GM.record_player_interaction(opponent.id, match_event)
	_record_npc_interaction(opponent, "player", "match_loss" if player_won else "match_win")
	seg.relationship_event = match_event

	opponent.add_to_stat("fatigue", 10.0)

	var move: String = _get_finish_move(wrestler)
	if is_title_match:
		seg.narrative = NarrativeLibrary.get_title_result({
			"champ":        opponent.display_name if player_won else wrestler.get_display_name(),
			"challenger":   wrestler.get_display_name() if player_won else opponent.display_name,
			"title":        title_name,
			"new_champion": player_won,
		})
	else:
		seg.narrative = NarrativeLibrary.get_match_result({
			"winner":       wrestler.get_display_name() if player_won else opponent.display_name,
			"loser":        opponent.display_name if player_won else wrestler.get_display_name(),
			"outcome_tier": outcome_tier,
			"player_won":   player_won,
			"move":         move,
		})

	var headline_type: String = ""
	if was_upset:
		headline_type = "win_upset"
	elif is_title_match:
		headline_type = "title_change" if player_won else "title_retained"
	elif outcome_tier == "dominant" and player_won:
		headline_type = "win_dominant"

	if headline_type != "":
		_add_headline(headline_type, {
			"winner":     wrestler.get_display_name() if player_won else opponent.display_name,
			"loser":      opponent.display_name if player_won else wrestler.get_display_name(),
			"champ":      opponent.display_name if player_won else wrestler.get_display_name(),
			"challenger": wrestler.get_display_name() if player_won else opponent.display_name,
			"title":      title_name,
			"promotion":  promo.display_name if promo != null else "Indie Circuit",
		})

	return seg


# ---------------------------------------------------------------------------
# Title match resolution
# ---------------------------------------------------------------------------

func _resolve_title_match(
	wrestler: Wrestler,
	opponent: NPCResource,
	promo: PromotionResource,
	player_won: bool,
	seg: ShowSegment
) -> void:
	if promo.championships.is_empty():
		return

	var champ: PromotionResource.ChampionshipRecord = promo.championships[0]

	if player_won:
		promo.set_champion(champ.id, "player")
		wrestler.record_championship(champ.id)
		seg.title_changed = true
		SL.log_event("TITLE WON — %s captures %s" % [
			wrestler.get_display_name(), champ.display_name
		])
	else:
		if champ.champion_id == "player":
			promo.set_champion(champ.id, opponent.id)
			opponent.championships_held.append(champ.id)
			seg.title_changed = true
			SL.log_event("TITLE LOST — %s loses %s to %s" % [
				wrestler.get_display_name(), champ.display_name, opponent.display_name
			])


# ---------------------------------------------------------------------------
# Background NPC segment
# ---------------------------------------------------------------------------

func _resolve_background_segment(rank: String, _promo: PromotionResource) -> ShowSegment:
	var rm: RosterManager       = get_node("/root/RM")
	var npcs_at_rank: Array     = rm.get_npcs_at_rank(rank)
	if npcs_at_rank.size() < 2:
		return null

	npcs_at_rank.shuffle()
	var npc_a: NPCResource = npcs_at_rank[0]
	var npc_b: NPCResource = npcs_at_rank[1]

	var seg: ShowSegment  = ShowSegment.new()
	seg.type              = "match"
	seg.is_player         = false
	seg.participant_a     = npc_a.display_name
	seg.participant_b     = npc_b.display_name

	var a_score: float = npc_a.get_combat_score() + randf() * MATCH_ROLL_RANGE
	var b_score: float = npc_b.get_combat_score() + randf() * MATCH_ROLL_RANGE
	var a_won: bool    = a_score >= b_score
	var margin: float  = abs(a_score - b_score) / max(a_score, b_score)
	var tier: String   = _match_outcome_tier(true, margin, false)

	seg.outcome_tier = tier
	seg.player_won   = false

	if a_won:
		npc_a.wins   += 1
		npc_b.losses += 1
		npc_a.add_to_stat("fame", 1.0)
	else:
		npc_b.wins   += 1
		npc_a.losses += 1
		npc_b.add_to_stat("fame", 1.0)

	_record_npc_interaction(npc_a, npc_b.id, "match_win" if a_won else "match_loss")
	_record_npc_interaction(npc_b, npc_a.id, "match_loss" if a_won else "match_win")

	seg.narrative = NarrativeLibrary.get_match_result({
		"winner":       npc_a.display_name if a_won else npc_b.display_name,
		"loser":        npc_b.display_name if a_won else npc_a.display_name,
		"outcome_tier": tier,
		"player_won":   false,
	})

	return seg


# ---------------------------------------------------------------------------
# Opponent selection
# ---------------------------------------------------------------------------

func _pick_opponent(rank: String, _wrestler: Wrestler) -> NPCResource:
	var rivals: Array  = GM.get_player_relationships_of_type(RelationshipRecord.TYPE_RIVAL)
	var enemies: Array = GM.get_player_relationships_of_type(RelationshipRecord.TYPE_ENEMY)
	var hot_rels: Array = rivals + enemies

	var rm: RosterManager = get_node("/root/RM")
	for rel in hot_rels:
		var r: RelationshipRecord = rel as RelationshipRecord
		var npc: NPCResource      = rm.get_npc(r.other_id)
		if npc != null and npc.rank == rank:
			return npc

	return rm.get_random_opponent(rank, "")


# ---------------------------------------------------------------------------
# Score helpers
# ---------------------------------------------------------------------------

func _player_combat_score(wrestler: Wrestler) -> float:
	var base: float = (
		wrestler.get_stat("technique") * 0.25 +
		wrestler.get_stat("power")     * 0.25 +
		wrestler.get_stat("stamina")   * 0.20 +
		wrestler.get_stat("toughness") * 0.15 +
		wrestler.get_stat("agility")   * 0.10 +
		wrestler.get_stat("charisma")  * 0.05
	)

	var personality_bonus: float = 0.0
	for stat in StatDefs.CORE:
		personality_bonus += float(PersonalityDefs.get_modifier(
			wrestler.res.personality, stat
		))
	personality_bonus /= float(StatDefs.CORE.size())
	base *= (1.0 + personality_bonus * 0.1)

	var fatigue_factor: float = lerp(1.0, 0.3, wrestler.get_stat("fatigue") / 100.0)
	base *= fatigue_factor

	return base


func _player_promo_score(wrestler: Wrestler) -> float:
	var fame_factor: float    = wrestler.get_stat("fame") / 100.0
	var morale_factor: float  = lerp(0.8, 1.1, wrestler.get_stat("morale") / 100.0)
	var personality_mod: float = _player_promo_personality_mod(wrestler.res.personality)
	return clamp(fame_factor * morale_factor + personality_mod, 0.0, 1.0)


func _player_promo_personality_mod(personality: String) -> float:
	match personality:
		"showman":    return  0.20
		"passionate": return  0.15
		"confident":  return  0.15
		"cunning":    return  0.10
		"proud":      return  0.05
		"anxious":    return -0.15
		"melancholy": return -0.10
		"bitter":     return -0.10
		"lethargic":  return -0.05
	return 0.0


func _rank_diff(player_rank: String, opponent_rank: String) -> int:
	var order: Array = RosterManager.RANK_ORDER
	return order.find(player_rank) - order.find(opponent_rank)


# ---------------------------------------------------------------------------
# Outcome tier helpers
# ---------------------------------------------------------------------------

func _match_outcome_tier(won: bool, margin_pct: float, was_upset: bool) -> String:
	if was_upset:
		return "upset"
	if not won:
		return "dominant" if margin_pct > 0.30 else "close"
	if margin_pct > 0.30:
		return "dominant"
	if margin_pct > 0.15:
		return "clean"
	return "close"


func _promo_tier_from_score(score: float) -> String:
	if score >= 0.75: return "strong"
	if score >= 0.50: return "decent"
	if score >= 0.25: return "flat"
	return "heat"


# ---------------------------------------------------------------------------
# Fame delta helpers
# ---------------------------------------------------------------------------

func _match_fame_delta(outcome_tier: String, player_won: bool) -> float:
	if player_won:
		match outcome_tier:
			"dominant": return FAME_WIN_DOMINANT
			"clean":    return FAME_WIN_CLEAN
			"close":    return FAME_WIN_CLOSE
			"upset":    return FAME_WIN_UPSET
	else:
		match outcome_tier:
			"dominant": return FAME_LOSS_DOMINANT
			"close":    return FAME_LOSS_CLOSE
	return 0.0


func _promo_fame_delta(outcome_tier: String) -> float:
	match outcome_tier:
		"strong": return FAME_PROMO_STRONG
		"decent": return FAME_PROMO_DECENT
		"flat":   return FAME_PROMO_FLAT
		"heat":   return FAME_PROMO_HEAT
	return 0.0


# ---------------------------------------------------------------------------
# Relationship helpers
# ---------------------------------------------------------------------------

func _get_hottest_player_relationship(rank: String) -> RelationshipRecord:
	var rels: Array = GM.get_player_relationships_sorted()
	var rm: RosterManager = get_node("/root/RM")
	for rel in rels:
		var r: RelationshipRecord = rel as RelationshipRecord
		if r == null or not r.is_program_eligible():
			continue
		var npc: NPCResource = rm.get_npc(r.other_id)
		if npc != null and npc.rank == rank:
			return r
	return null


func _record_npc_interaction(
	npc: NPCResource,
	other_id: String,
	event_type: String
) -> void:
	if not npc.relationships.has(other_id):
		var other_name: String = ""
		if other_id == "player":
			other_name = GM.current_wrestler_node.get_display_name() \
				if GM.current_wrestler_node != null else "Player"
		else:
			var rm: RosterManager    = get_node("/root/RM")
			var other_npc: NPCResource = rm.get_npc(other_id)
			other_name = other_npc.display_name if other_npc != null else other_id
		npc.relationships[other_id] = RelationshipRecord.create(
			other_id, other_name, _absolute_week()
		)
	var rel: RelationshipRecord = npc.relationships[other_id]
	rel.record_interaction(event_type, _absolute_week())


# ---------------------------------------------------------------------------
# Promotion helper
# ---------------------------------------------------------------------------

func _get_show_promotion(rank: String) -> PromotionResource:
	if GM.is_contracted():
		return GM.get_contracted_promotion()
	var rm: RosterManager = get_node("/root/RM")
	return rm.get_promotion_for_rank(rank)


# ---------------------------------------------------------------------------
# Headline helper — routes through HL autoload safely
# ---------------------------------------------------------------------------

func _add_headline(headline_type: String, params: Dictionary) -> void:
	var text: String = NarrativeLibrary.get_headline(headline_type, params)
	if text == "":
		return
	if has_node("/root/HL"):
		var hl: HeadlineLog = get_node("/root/HL")
		hl._add_entry(text, headline_type)


# ---------------------------------------------------------------------------
# Misc helpers
# ---------------------------------------------------------------------------

func _get_finish_move(wrestler: Wrestler) -> String:
	if wrestler.res != null and not wrestler.res.learned_moves.is_empty():
		return wrestler.res.learned_moves[randi() % wrestler.res.learned_moves.size()]
	return "signature move"


func _absolute_week() -> int:
	return ((GM.year - 1) * 48) + ((GM.month - 1) * 4) + GM.week
