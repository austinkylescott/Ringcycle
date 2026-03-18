extends Resource
class_name PromotionResource

# ---------------------------------------------------------------------------
# PromotionResource — one wrestling promotion / company.
#
# Promotions are the organizational layer between rank tiers and individual
# shows. A wrestler signs with a promotion and is then obligated to attend
# their weekly show(s) and monthly PLE.
#
# Phase 1: one promotion per rank tier, auto-generated at game start.
# Phase 2+: multiple promotions per tier, contract negotiation, draft events,
#            inter-promotional feuds and crossover shows.
#
# The booker is an NPC id — the behind-the-scenes relationship contact.
# Keeping the booker happy affects card placement and championship access.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
@export var id: String = ""              # unique, e.g. "promo_e_001"
@export var display_name: String = ""    # e.g. "Irongate Wrestling"
@export var short_name: String = ""      # e.g. "IGW" — used in headlines

# Rank tier this promotion operates at.
# Valid: "E", "D", "C", "B", "A", "S"
@export var rank: String = "E"

# Prestige affects fame delta from wins here.
# 0.5 = backyard show, 1.0 = standard, 1.5 = major national, 2.0 = world stage
@export var prestige: float = 1.0

# Flavour description shown when a contract offer arrives.
@export var description: String = ""


# ---------------------------------------------------------------------------
# Roster
# Array of NPC ids signed to this promotion.
# Player wrestler id is NOT stored here — contract state lives on GameManager.
# ---------------------------------------------------------------------------
@export var roster_ids: Array[String] = []

# Maximum roster size before the promotion stops signing new talent.
@export var roster_cap: int = 12

# Booker NPC id. Empty = no active booker (promotion is in chaos).
@export var booker_npc_id: String = ""


# ---------------------------------------------------------------------------
# Show schedule
# Promotions run a fixed number of weekly shows and one monthly PLE.
#
# weekly_show_count: how many shows per week (1 = one weekly, 2 = Raw+SD)
# ple_week: which week of the month the PLE falls on (1–4)
# show_day: which day of the week the primary show runs (1=Mon … 7=Sun)
# ple_name: display name for the monthly PLE
# ---------------------------------------------------------------------------
@export var weekly_show_count: int = 1
@export var ple_week: int          = 4   # last week of month by default
@export var show_day: int          = 6   # Saturday by default
@export var ple_name: String       = ""  # e.g. "Night of Champions"


# ---------------------------------------------------------------------------
# Championships
# Array of ChampionshipRecord — defined inline here for Phase 1 simplicity.
# Promoted to its own resource in Phase 2 if needed.
# ---------------------------------------------------------------------------

class ChampionshipRecord:
	var id: String          = ""   # e.g. "igw_heavyweight"
	var display_name: String = ""  # e.g. "IGW Heavyweight Championship"
	var champion_id: String  = ""  # NPC id or player wrestler id. Empty = vacant.
	var reign_days: int      = 0   # days the current champion has held the title

@export var championships: Array = []  # Array[ChampionshipRecord]


# ---------------------------------------------------------------------------
# Reputation — player's standing with this promotion
# Affects contract offers, card placement, championship opportunities.
#
# 0–100 scale:
#   0–25:  unknown / unwelcome
#   26–50: on the radar
#   51–75: respected performer
#   76–90: featured act
#   91–100: cornerstone of the promotion
# ---------------------------------------------------------------------------
@export var player_reputation: float = 0.0

# How many shows the player has attended here total.
@export var player_appearances: int = 0


# ---------------------------------------------------------------------------
# Booker relationship quality — separate from general reputation.
# Affects which program beats the booker assigns the player.
# 0–100: 0 = buried, 50 = neutral, 100 = golden boy
# ---------------------------------------------------------------------------
@export var booker_relationship: float = 50.0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Returns true if the given NPC id is on this promotion's roster.
func has_npc(npc_id: String) -> bool:
	return npc_id in roster_ids


# Returns true if the promotion can sign more talent.
func has_roster_space() -> bool:
	return roster_ids.size() < roster_cap


# Adds an NPC to the roster. Returns false if at capacity.
func sign_npc(npc_id: String) -> bool:
	if not has_roster_space():
		return false
	if npc_id in roster_ids:
		return false
	roster_ids.append(npc_id)
	return true


# Removes an NPC from the roster (death, release, rank-up departure).
func release_npc(npc_id: String) -> void:
	roster_ids.erase(npc_id)


# Returns true if this week (given week-of-month 1–4) is a PLE week.
func is_ple_week(week_of_month: int) -> bool:
	return week_of_month == ple_week


# Returns the show name for a given week.
func get_show_name(week_of_month: int) -> String:
	if is_ple_week(week_of_month):
		return ple_name if ple_name != "" else ("%s PLE" % display_name)
	return display_name


# Returns the championship record for a given id, or null.
func get_championship(champ_id: String):
	for c in championships:
		if c.id == champ_id:
			return c
	return null


# Updates the champion for a given championship.
# Pass empty string to vacate.
func set_champion(champ_id: String, new_champion_id: String) -> void:
	for c in championships:
		if c.id == champ_id:
			c.champion_id = new_champion_id
			c.reign_days   = 0
			return
	push_warning("PromotionResource.set_champion: championship '%s' not found" % champ_id)


# Ticks reign_days for all championships. Call once per show day.
func tick_championship_reigns() -> void:
	for c in championships:
		if c.champion_id != "":
			c.reign_days += 1


# ---------------------------------------------------------------------------
# Prestige-scaled fame delta
# How much fame a win here is worth, before match-margin scaling.
# ---------------------------------------------------------------------------
func get_base_fame_delta(won: bool) -> float:
	if won:
		return 3.0 * prestige
	return -1.0 * prestige
