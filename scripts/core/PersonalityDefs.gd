class_name PersonalityDefs

# ---------------------------------------------------------------------------
# Modifier scale (applied to the LIVING monster's training gains)
#   2  = strong bonus  (++)
#   1  = minor bonus   (+)
#   0  = no effect     (omitted from modifiers dict for brevity)
#  -1  = minor detriment (-)
#  -2  = strong detriment (--)
#
# Personalities are NOT carried into retirement.
# Retired monsters become Coaches — their coaching bonus is derived solely
# from their dominant stat value at retirement (see CoachResource).
# ---------------------------------------------------------------------------

# How much accumulated pressure triggers a personality shift.
# Calibrated to ~1 natural shift per 13-week season under consistent behavior.
# Tune this during playtesting — it's the primary balancing lever for the system.
const SHIFT_THRESHOLD := 25.0

# ---------------------------------------------------------------------------
# Personality definitions
# ---------------------------------------------------------------------------
const PERSONALITIES := {

	# --- Positive / driven states ---

	"determined": {
		"display_name": "Determined",
		"description": "Locks in when it matters. Trains with singular focus.",
		"modifiers": { "power": 2, "technique": 1, "stamina": -1 },
	},
	"inspired": {
		"display_name": "Inspired",
		"description": "A well-managed career shows in everything they do.",
		"modifiers": { "power": 1, "technique": 1, "agility": 1, "toughness": 1, "stamina": 1, "charisma": 1 },
	},
	"passionate": {
		"display_name": "Passionate",
		"description": "Pours everything into the performance. Crowds feel it.",
		"modifiers": { "charisma": 2, "power": 1, "stamina": -1 },
	},
	"focused": {
		"display_name": "Focused",
		"description": "Blocks out the noise. Every session counts.",
		"modifiers": { "technique": 2, "agility": 1, "charisma": -1 },
	},
	"confident": {
		"display_name": "Confident",
		"description": "Carries themselves like a champion. Others take notice.",
		"modifiers": { "charisma": 2, "technique": 1, "toughness": 1 },
	},
	"ambitious": {
		"display_name": "Ambitious",
		"description": "Always chasing the next milestone. Never satisfied.",
		"modifiers": { "power": 1, "technique": 1, "agility": 1, "morale": -1 },
	},

	# --- Physical / instinctive states ---

	"fierce": {
		"display_name": "Fierce",
		"description": "Attacks everything full throttle. Defense suffers for it.",
		"modifiers": { "power": 2, "toughness": -2 },
	},
	"gritty": {
		"display_name": "Gritty",
		"description": "Injury-hardened survivor. Built to take a beating.",
		"modifiers": { "toughness": 2, "power": 1, "agility": -1 },
	},
	"resilient": {
		"display_name": "Resilient",
		"description": "Bounces back from anything. Stamina is their superpower.",
		"modifiers": { "stamina": 2, "toughness": 1, "agility": -1 },
	},
	"reckless": {
		"display_name": "Reckless",
		"description": "High risk, high reward. Defense is an afterthought.",
		"modifiers": { "power": 1, "agility": 2, "toughness": -2 },
	},
	"lethargic": {
		"display_name": "Lethargic",
		"description": "Hard to motivate. When they finally get going, watch out.",
		"modifiers": { "power": 1, "agility": -2, "stamina": -1 },
	},
	"hyperactive": {
		"display_name": "Hyperactive",
		"description": "Constant motion. Burns bright but burns fast.",
		"modifiers": { "agility": 2, "stamina": -2, "technique": -1 },
	},

	# --- Methodical / mental states ---

	"patient": {
		"display_name": "Patient",
		"description": "Methodical and unhurried. Gets the most out of slow burns.",
		"modifiers": { "technique": 2, "stamina": 1, "power": -1 },
	},
	"disciplined": {
		"display_name": "Disciplined",
		"description": "Consistent, low variance. Never peaks, never collapses.",
		"modifiers": { "technique": 1, "stamina": 2, "charisma": -1 },
	},
	"cunning": {
		"display_name": "Cunning",
		"description": "Reads opponents and crowds alike. Always a step ahead.",
		"modifiers": { "technique": 2, "charisma": 1, "power": -1 },
	},
	"obsessive": {
		"display_name": "Obsessive",
		"description": "Fixates on one thing completely. Everything else falls away.",
		"modifiers": { "technique": 2, "power": 2, "charisma": -2, "stamina": -1 },
	},

	# --- Emotional / crowd-facing states ---

	"showman": {
		"display_name": "Showman",
		"description": "Lives for the crowd. Fame comes naturally.",
		"modifiers": { "charisma": 2, "agility": 1, "toughness": -1 },
	},
	"carefree": {
		"display_name": "Carefree",
		"description": "Enjoys the ride. Nothing sticks — good or bad.",
		"modifiers": { "charisma": 1, "agility": 1, "technique": -1, "power": -1 },
	},
	"anxious": {
		"display_name": "Anxious",
		"description": "Overthinks everything. Nerves cost them in the clutch.",
		"modifiers": { "technique": 1, "stamina": -1, "charisma": -2 },
	},
	"proud": {
		"display_name": "Proud",
		"description": "Won't back down, won't ask for help. Pride drives them.",
		"modifiers": { "power": 1, "toughness": 1, "charisma": 1, "stamina": -1 },
	},

	# --- Negative / worn states ---

	"bitter": {
		"display_name": "Bitter",
		"description": "Worn down by a hard road. Difficult to work with.",
		"modifiers": { "power": -1, "agility": -1, "charisma": -2, "technique": 1 },
	},
	"melancholy": {
		"display_name": "Melancholy",
		"description": "Going through the motions. The spark just isn't there.",
		"modifiers": { "power": -1, "technique": -1, "charisma": -1, "toughness": 1 },
	},
	"volatile": {
		"display_name": "Volatile",
		"description": "Unpredictable. Great highs, terrible lows.",
		"modifiers": { "power": 2, "charisma": 1, "technique": -2, "toughness": -1 },
	},

	# --- Pinnacle state (dramatic flip only) ---

	"legendary": {
		"display_name": "Legendary",
		"description": "Only reached through the hardest paths. The rarest of all.",
		"modifiers": { "power": 2, "technique": 2, "agility": 2, "toughness": 2, "stamina": 2, "charisma": 2 },
	},
}


# ---------------------------------------------------------------------------
# Pressure event table
# Each event maps to personality_id -> pressure weight.
# Positive weight fills that personality's bucket.
# Negative weight drains it (counters an existing drift).
# When any bucket crosses SHIFT_THRESHOLD the wrestler shifts to that
# personality and all buckets reset (handled in Wrestler.gd).
# ---------------------------------------------------------------------------
const PRESSURE_EVENTS := {

	# --- Training actions ---
	"train_power": {
		"determined": 1.5, "fierce": 1.0, "reckless": 0.5, "obsessive": 0.5,
	},
	"train_technique": {
		"focused": 1.5, "disciplined": 1.0, "patient": 1.0, "cunning": 0.5, "obsessive": 0.5,
	},
	"train_agility": {
		"hyperactive": 1.5, "reckless": 1.0, "showman": 0.5,
	},
	"train_toughness": {
		"resilient": 1.5, "gritty": 1.0, "disciplined": 0.5,
	},
	"train_stamina": {
		"disciplined": 1.5, "resilient": 1.0, "patient": 0.5,
	},
	"train_charisma": {
		"showman": 2.0, "passionate": 1.5, "confident": 0.5, "cunning": 0.5,
	},
	"train_varied": {
		# Multiple different stats trained in the same week
		"inspired": 1.5, "disciplined": 1.0, "ambitious": 0.5,
	},
	"train_same_repeatedly": {
		# Same stat drilled many sessions in a row
		"obsessive": 2.0, "determined": 1.0, "lethargic": -1.0,
	},

	# --- Rest and recovery ---
	"rest_week": {
		"patient": 1.5, "inspired": 1.0, "carefree": 0.5,
		"lethargic": 0.5, "ambitious": -0.5,
	},
	"vacation": {
		"carefree": 2.0, "patient": 1.5, "inspired": 1.0,
		"lethargic": 1.0, "ambitious": -1.0,
	},
	"forced_rest_injury": {
		# Resting due to injury, not choice
		"melancholy": 1.5, "bitter": 1.0, "resilient": 0.5, "anxious": 1.0,
	},

	# --- Shows and competition ---
	"show_win": {
		"confident": 1.5, "showman": 1.0, "passionate": 1.0,
		"proud": 0.5, "anxious": -1.0,
	},
	"show_loss": {
		"gritty": 1.0, "determined": 0.5, "melancholy": 0.5,
		"bitter": 0.5, "resilient": 0.5, "anxious": 0.5,
	},
	"show_loss_streak": {
		# Multiple consecutive losses
		"bitter": 2.0, "melancholy": 1.5, "volatile": 1.0,
		"anxious": 1.0, "determined": 0.5, "confident": -1.5,
	},
	"show_overwork": {
		# Too many shows without adequate rest
		"bitter": 2.0, "volatile": 1.5, "lethargic": 1.0,
		"reckless": 0.5, "inspired": -1.0,
	},
	"championship_won": {
		"confident": 2.0, "proud": 1.5, "inspired": 1.0,
		"passionate": 1.0, "determined": 0.5, "anxious": -1.5,
	},
	"championship_lost_close": {
		# Lost a title match narrowly
		"determined": 2.0, "anxious": 1.0, "bitter": 0.5, "volatile": 0.5,
	},

	# --- Tours / errantry ---
	"tour_completed": {
		"fierce": 1.5, "cunning": 1.0, "determined": 0.5, "resilient": 0.5,
	},
	"tour_abandoned": {
		# Left a tour early by choice
		"carefree": 1.0, "bitter": 0.5, "melancholy": 0.5, "anxious": 0.5,
	},
	"tour_failed": {
		# Tour ended badly — injury or poor results
		"bitter": 2.0, "melancholy": 1.0, "volatile": 1.0, "anxious": 0.5,
	},

	# --- Injuries ---
	"injury_minor": {
		"gritty": 1.0, "resilient": 0.5, "anxious": 0.5,
	},
	"injury_severe": {
		"gritty": 1.5, "bitter": 1.5, "resilient": 1.0,
		"melancholy": 1.0, "anxious": 1.0, "confident": -1.0,
	},
	"injury_repeated": {
		# Multiple injuries in the same career phase
		"bitter": 2.0, "melancholy": 1.5, "volatile": 1.0,
		"gritty": 1.0, "anxious": 1.0,
	},
	"injury_recovery_success": {
		# Came back strong from a serious injury
		"resilient": 2.0, "determined": 1.5, "inspired": 0.5, "anxious": -1.5,
	},

	# --- Items ---
	"item_food": {
		"carefree": 1.0, "inspired": 0.5, "lethargic": 0.5,
	},
	"item_training_aid": {
		"determined": 1.0, "disciplined": 0.5, "obsessive": 0.5,
	},
	"item_medicine": {
		"resilient": 1.0, "anxious": -1.0,
	},

	# --- Crowd and fame ---
	"crowd_loved": {
		"showman": 1.5, "confident": 1.0, "passionate": 1.0, "anxious": -1.0,
	},
	"crowd_ignored": {
		"melancholy": 1.0, "anxious": 1.0, "bitter": 0.5, "carefree": 0.5,
	},
	"fame_milestone": {
		"confident": 1.5, "ambitious": 1.0, "proud": 1.0, "showman": 0.5,
	},

	# --- Late career ---
	"lifespan_critical": {
		# Entered the final stage of natural lifespan
		"melancholy": 1.5, "bitter": 1.0, "gritty": 1.0, "proud": 0.5,
	},
	"pushed_past_prime": {
		# Competing heavily after the Legend prime window has closed
		"bitter": 2.0, "volatile": 1.0, "lethargic": 1.5, "inspired": -1.5,
	},
}


# ---------------------------------------------------------------------------
# Dramatic flip table
# These events bypass accumulation entirely and set personality immediately.
# All accumulation buckets are cleared after a dramatic flip.
# ---------------------------------------------------------------------------
const DRAMATIC_FLIPS := {
	"world_championship_won": "legendary",
	"career_ending_injury":   "bitter",
	"overwork_collapse":      "bitter",
	"remarkable_comeback":    "resilient",
	"crowd_turns_on_monster": "volatile",
	"perfect_season":         "inspired",
}


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

static func get_display_name(personality_id: String) -> String:
	if PERSONALITIES.has(personality_id):
		return PERSONALITIES[personality_id]["display_name"]
	return personality_id


# Returns the modifier int for a specific stat under a given personality.
# Returns 0 if the personality doesn't affect that stat.
static func get_modifier(personality_id: String, stat: String) -> int:
	if not PERSONALITIES.has(personality_id):
		return 0
	var mods: Dictionary = PERSONALITIES[personality_id]["modifiers"]
	return mods.get(stat, 0)


# Returns the full modifier dictionary for a personality.
static func get_modifiers(personality_id: String) -> Dictionary:
	if not PERSONALITIES.has(personality_id):
		return {}
	return PERSONALITIES[personality_id]["modifiers"]


# Returns pressure weights for an event toward all personalities.
static func get_pressure(event_id: String) -> Dictionary:
	return PRESSURE_EVENTS.get(event_id, {})


# Returns all valid personality ids.
static func all_ids() -> Array:
	return PERSONALITIES.keys()


static func is_valid(personality_id: String) -> bool:
	return PERSONALITIES.has(personality_id)
