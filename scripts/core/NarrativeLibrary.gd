class_name NarrativeLibrary

# ---------------------------------------------------------------------------
# NarrativeLibrary — parameterized narrative text for show events.
#
# Pure static data and functions. No node, no instantiation needed.
# Call NarrativeLibrary.get_match_result(params) from ShowManager.
#
# Template slots:
#   {winner}      — display name of the winner
#   {loser}       — display name of the loser
#   {champ}       — display name of the champion (title matches)
#   {challenger}  — display name of the challenger (title matches)
#   {a}           — first wrestler in a non-win/loss context
#   {b}           — second wrestler
#   {promotion}   — promotion display name
#   {title}       — championship display name
#   {move}        — finishing move name (from learned_moves, or fallback)
#
# Outcome tiers for matches:
#   "dominant"    — won decisively, score margin > 30%
#   "clean"       — won clearly, margin 15–30%
#   "close"       — narrow victory, margin < 15%
#   "upset"       — lower-ranked/lower-score wrestler won
#   "draw"        — match ended without a winner (future use)
#
# Promo outcome tiers:
#   "strong"      — charisma check passed well
#   "decent"      — charisma check passed narrowly
#   "flat"        — charisma check failed narrowly
#   "heat"        — crowd turned on the wrestler (charisma check failed badly)
#
# Segment types:
#   "ring_solo"         — promo alone in the ring
#   "ring_confrontation"— face-to-face in the ring with opponent
#   "backstage_solo"    — backstage interview or vignette
#   "backstage_duo"     — backstage with ally or rival
#   "vignette"          — pre-taped package, no live crowd reaction
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Match result templates
# ---------------------------------------------------------------------------

const MATCH_WIN_DOMINANT := [
	"{winner} dismantled {loser} from bell to bell. The crowd barely had time to react.",
	"A dominant performance from {winner} — {loser} had no answer tonight.",
	"{winner} made a statement. {loser} was outclassed in every phase of the match.",
	"Clinical, relentless, dominant. {winner} left no doubt.",
	"{loser} tried to weather the storm but {winner} was simply on another level.",
]

const MATCH_WIN_CLEAN := [
	"{winner} picked up a hard-earned victory over {loser}.",
	"After a strong back-and-forth, {winner} found the opening and capitalized.",
	"{winner} gets the win, though {loser} pushed them harder than expected.",
	"A quality match ends with {winner}'s hand raised.",
	"{winner} outworked {loser} over the course of the contest.",
]

const MATCH_WIN_CLOSE := [
	"In a match that could have gone either way, {winner} escaped with the victory.",
	"{loser} had {winner} on the ropes but couldn't close it out.",
	"A near-fall thriller — {winner} survives a gutsy performance from {loser}.",
	"The crowd was split but {winner} found one last surge when it mattered most.",
	"{winner} wins in a match worth remembering. {loser} will feel robbed.",
]

const MATCH_WIN_UPSET := [
	"Nobody saw this coming. {winner} just beat {loser} clean in the middle of the ring.",
	"An enormous upset — {winner} defeats {loser} and the crowd doesn't know how to react.",
	"{loser} came in as the heavy favourite. They're leaving with a loss thanks to {winner}.",
	"Don't look now, but {winner} just put the locker room on notice.",
	"Shocking result tonight — {winner} over {loser}. The implications are enormous.",
]

const MATCH_LOSS_DOMINANT := [
	"{loser} was overwhelmed tonight. {winner} never let them get started.",
	"A tough night for {loser} — {winner} was simply the better wrestler.",
	"{loser} couldn't find an answer. {winner} controlled every moment.",
	"Sometimes you run into someone on a different level. Tonight that was {winner}.",
]

const MATCH_LOSS_CLOSE := [
	"{loser} was this close. A heartbreaking near-fall just before the finish.",
	"So close. {loser} put in a career-level effort but it wasn't enough.",
	"{loser} can hold their head high after pushing {winner} to the absolute limit.",
	"The match of the night — and {loser} came up just short.",
]

# ---------------------------------------------------------------------------
# Title match templates
# ---------------------------------------------------------------------------

const TITLE_WIN := [
	"We have a new champion. {challenger} defeats {champ} to capture the {title}!",
	"History is made — {challenger} is your new {title} champion!",
	"The championship changes hands. {challenger} dethrones {champ}!",
	"{challenger} climbed to the top of the mountain tonight. New {title} champion!",
]

const TITLE_DEFENCE_WIN := [
	"{champ} retains the {title} against a hard challenge from {challenger}.",
	"The champion survives. {champ} holds onto the {title}.",
	"{champ} proves why they're the champion — {challenger} gave everything but came up short.",
	"The {title} stays put. {champ} retains in a match that will be talked about.",
]

const TITLE_DEFENCE_LOSS := [
	"We have a new {title} champion — {challenger} dethrones {champ}!",
	"The reign is over. {champ} loses the {title} to {challenger}.",
	"An era ends tonight as {challenger} pins {champ} for the {title}.",
]

# ---------------------------------------------------------------------------
# Promo segment templates
# ---------------------------------------------------------------------------

const PROMO_RING_SOLO_STRONG := [
	"{a} owns the ring tonight. The crowd is hanging on every word.",
	"A commanding performance on the mic from {a}. Nobody moved during that promo.",
	"{a} came to talk and delivered. The crowd responds with genuine heat and cheers.",
	"That promo just made {a} a bigger deal. Effortless.",
]

const PROMO_RING_SOLO_DECENT := [
	"{a} connects with the crowd well enough. A solid if unremarkable promo.",
	"The crowd was with {a} for most of it. Gets the point across.",
	"{a} gets through the promo. Not fireworks, but effective.",
]

const PROMO_RING_SOLO_FLAT := [
	"{a}'s promo loses the crowd halfway through. Awkward silence at the end.",
	"The crowd isn't buying what {a} is selling tonight.",
	"{a} struggles to connect. The energy just wasn't there.",
]

const PROMO_RING_SOLO_HEAT := [
	"This backfires badly. The crowd turns on {a} before they even finish.",
	"{a} somehow manages to get themselves booed by everyone in the building.",
	"A disaster on the mic. {a} might want to forget this one.",
]

const PROMO_CONFRONTATION_STRONG := [
	"{a} and {b} go face to face and the crowd erupts. This is what they came for.",
	"Electricity in the building as {a} and {b} square off verbally. Neither backs down.",
	"The tension between {a} and {b} spills over. This rivalry just got personal.",
	"{a} and {b} in the same ring, same moment — the crowd is on its feet.",
]

const PROMO_CONFRONTATION_DECENT := [
	"{a} and {b} exchange words. The crowd is engaged if not electrified.",
	"A solid back-and-forth between {a} and {b}. The story moves forward.",
	"{a} and {b} face off. Both make their points. The match is set.",
]

const PROMO_CONFRONTATION_FLAT := [
	"{a} and {b} fail to spark anything. The segment falls flat.",
	"The crowd wanted more from the {a}-{b} face-off. Disappointing.",
]

const PROMO_BACKSTAGE_SOLO := [
	"Cameras catch {a} backstage with a message. Short, sharp, to the point.",
	"A quick word from {a} in the back. Sets up what's coming later.",
	"{a} cuts a short backstage promo. The crowd appreciates the accessibility.",
]

const PROMO_BACKSTAGE_DUO_ALLY := [
	"{a} and {b} share a moment backstage. Something is being built here.",
	"Cameras spot {a} and {b} talking quietly. The alliance looks solid.",
	"{a} and {b} — together for now. What they're planning isn't clear yet.",
]

const PROMO_BACKSTAGE_DUO_HEAT := [
	"{a} and {b} nearly come to blows backstage. Officials have to step in.",
	"A heated exchange backstage between {a} and {b}. This isn't over.",
	"{b} gets in {a}'s face backstage. {a} doesn't back down.",
]

const PROMO_VIGNETTE := [
	"A vignette package airs highlighting {a}'s journey so far. Effective storytelling.",
	"We get a look at {a} in their natural environment. The crowd is warming to them.",
	"A pre-taped piece on {a}. Simple but it does the job of building interest.",
]

# ---------------------------------------------------------------------------
# Interference templates
# ---------------------------------------------------------------------------

const INTERFERENCE_FOR := [
	"{b} comes out of nowhere to help {a}! The referee is calling for the bell!",
	"Unexpected interference from {b} on behalf of {a}. The match breaks down.",
	"{b} makes the save for {a}. There's clearly something developing here.",
]

const INTERFERENCE_AGAINST := [
	"{b} interferes and costs {a} the match. The crowd is furious.",
	"Out of nowhere — {b} attacks {a}! What a coward's move.",
	"The match is thrown out after {b} gets involved. {a} is blindsided.",
]

# ---------------------------------------------------------------------------
# Show card templates — used for the show header in the log
# ---------------------------------------------------------------------------

const SHOW_OPENER := [
	"The crowd is electric as {promotion} kicks off tonight's show.",
	"The lights go down and {promotion} is live. Let's get into it.",
	"A packed house for {promotion} tonight. Something feels different.",
	"{promotion} opens to a roar from the crowd. Big night ahead.",
]

const SHOW_CLOSER := [
	"That's all from {promotion} tonight. A show worth remembering.",
	"{promotion} goes off the air. The crowd is still buzzing.",
	"Another chapter written for {promotion}. We'll see what comes next.",
	"Sign off from {promotion}. Tonight's show delivered.",
]

const SHOW_PLE_OPENER := [
	"{promotion} presents {title} — the biggest night of the month is here.",
	"All roads led to tonight. {promotion}'s {title} is underway.",
	"The atmosphere is unlike anything on a regular week. {title} begins now.",
]

# ---------------------------------------------------------------------------
# Headline templates — shorter versions for the newspaper feed
# ---------------------------------------------------------------------------

const HEADLINE_WIN_DOMINANT := [
	"{winner} DESTROYS {loser} at {promotion}",
	"DOMINANT: {winner} makes short work of {loser}",
	"{winner} sends a message with demolition of {loser}",
]

const HEADLINE_WIN_UPSET := [
	"SHOCK RESULT: {winner} defeats {loser}",
	"UPSET ALERT — {winner} pins {loser} clean",
	"Nobody saw it coming: {winner} over {loser}",
]

const HEADLINE_TITLE_CHANGE := [
	"NEW CHAMPION: {challenger} captures {title}",
	"TITLE CHANGE at {promotion} — {challenger} dethrones {champ}",
	"THE TITLE HAS A NEW HOME — {challenger} is champion",
]

const HEADLINE_TITLE_RETAINED := [
	"{champ} retains {title} in hard-fought defence",
	"The champion holds on — {champ} survives {challenger}",
]

const HEADLINE_NPC_DEATH := [
	"The wrestling world mourns the passing of {a}",
	"A sad day — {a} has passed away. Remembered as a {rank} legend.",
	"End of an era: {a} is gone",
]

const HEADLINE_PROMOTION := [
	"{a} signs with {promotion}",
	"BREAKING: {a} is headed to {promotion}",
	"{promotion} acquires {a}",
]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# Returns a filled match result string.
# params keys: winner, loser, outcome_tier, move (optional)
static func get_match_result(params: Dictionary) -> String:
	var tier: String = params.get("outcome_tier", "clean")
	var pool: Array  = _match_pool_for_tier(tier, params.get("player_won", true))
	return _fill(pool[randi() % pool.size()], params)


# Returns a filled title match string.
# params keys: champ, challenger, title, new_champion (bool)
static func get_title_result(params: Dictionary) -> String:
	var pool: Array
	if params.get("new_champion", false):
		pool = TITLE_WIN
	else:
		pool = TITLE_DEFENCE_WIN
	return _fill(pool[randi() % pool.size()], params)


# Returns a filled promo segment string.
# params keys: a, b (optional), segment_type, outcome_tier, relationship_type (optional)
static func get_promo_result(params: Dictionary) -> String:
	var seg_type: String     = params.get("segment_type", "ring_solo")
	var tier: String         = params.get("outcome_tier", "decent")
	var rel_type: String     = params.get("relationship_type", "")
	var pool: Array          = _promo_pool_for_type(seg_type, tier, rel_type)
	return _fill(pool[randi() % pool.size()], params)


# Returns a filled interference string.
# params keys: a (victim), b (interferer), helped (bool)
static func get_interference(params: Dictionary) -> String:
	var pool: Array = INTERFERENCE_FOR if params.get("helped", false) else INTERFERENCE_AGAINST
	return _fill(pool[randi() % pool.size()], params)


# Returns a filled show opener or closer string.
# params keys: promotion, title (for PLE), is_ple (bool), is_opener (bool)
static func get_show_frame(params: Dictionary) -> String:
	var is_ple:    bool = params.get("is_ple", false)
	var is_opener: bool = params.get("is_opener", true)
	var pool: Array
	if is_ple and is_opener:
		pool = SHOW_PLE_OPENER
	elif is_opener:
		pool = SHOW_OPENER
	else:
		pool = SHOW_CLOSER
	return _fill(pool[randi() % pool.size()], params)


# Returns a filled headline string.
# params keys: winner/loser/champ/challenger/a/b/promotion/title/rank as needed
# headline_type: "win_dominant" | "win_upset" | "title_change" |
#                "title_retained" | "npc_death" | "promotion"
static func get_headline(headline_type: String, params: Dictionary) -> String:
	var pool: Array = _headline_pool(headline_type)
	if pool.is_empty():
		return ""
	return _fill(pool[randi() % pool.size()], params)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _match_pool_for_tier(tier: String, player_won: bool) -> Array:
	match tier:
		"dominant": return MATCH_WIN_DOMINANT if player_won else MATCH_LOSS_DOMINANT
		"clean":    return MATCH_WIN_CLEAN
		"close":    return MATCH_WIN_CLOSE if player_won else MATCH_LOSS_CLOSE
		"upset":    return MATCH_WIN_UPSET
	return MATCH_WIN_CLEAN


static func _promo_pool_for_type(
	seg_type: String,
	tier: String,
	rel_type: String
) -> Array:
	match seg_type:
		"ring_solo":
			match tier:
				"strong": return PROMO_RING_SOLO_STRONG
				"decent": return PROMO_RING_SOLO_DECENT
				"flat":   return PROMO_RING_SOLO_FLAT
				"heat":   return PROMO_RING_SOLO_HEAT
		"ring_confrontation":
			match tier:
				"strong": return PROMO_CONFRONTATION_STRONG
				"decent": return PROMO_CONFRONTATION_DECENT
				_:        return PROMO_CONFRONTATION_FLAT
		"backstage_solo":
			return PROMO_BACKSTAGE_SOLO
		"backstage_duo":
			if rel_type in RelationshipRecord.HEAT_TYPES:
				return PROMO_BACKSTAGE_DUO_HEAT
			return PROMO_BACKSTAGE_DUO_ALLY
		"vignette":
			return PROMO_VIGNETTE
	return PROMO_RING_SOLO_DECENT


static func _headline_pool(headline_type: String) -> Array:
	match headline_type:
		"win_dominant":   return HEADLINE_WIN_DOMINANT
		"win_upset":      return HEADLINE_WIN_UPSET
		"title_change":   return HEADLINE_TITLE_CHANGE
		"title_retained": return HEADLINE_TITLE_RETAINED
		"npc_death":      return HEADLINE_NPC_DEATH
		"promotion":      return HEADLINE_PROMOTION
	return []


# Fills template slots in a string with values from params dict.
static func _fill(template: String, params: Dictionary) -> String:
	var result := template
	for key in params.keys():
		var val = params[key]
		if val is String:
			result = result.replace("{%s}" % key, val)
	return result
