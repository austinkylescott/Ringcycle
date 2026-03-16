extends Resource
class_name WrestlerResource

# ---------------------------------------------------------------------------
# WrestlerResource is the live save state for one monster.
# It is NOT a template — it represents a specific individual during their
# career. Created at birth via GameManager.create_wrestler_from_species(),
# mutated continuously by TrainingSystem, CalendarSystem, and EvolutionSystem,
# and eventually frozen into a CoachResource at retirement.
#
# The Wrestler node wraps this resource and provides the stat access API.
# Never mutate this resource directly from UI code — go through Wrestler.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
@export var display_name: String = "Rookie"

# Current stage — drives growth profile lookup and evolution gating.
# Valid values: "Rookie", "Pro", "Legend_A", "Legend_B", "Legend_C"
@export var stage: String = "Rookie"

# Reference to the current form's species resource.
# Swapped out by EvolutionSystem when the monster evolves.
@export var species: WrestlerSpeciesResource


# ---------------------------------------------------------------------------
# Core stats (0 – 999, soft cap per species)
# ---------------------------------------------------------------------------
@export var power: int      = 50
@export var technique: int  = 45
@export var agility: int    = 35
@export var toughness: int  = 40
@export var stamina: int    = 60
@export var charisma: int   = 55


# ---------------------------------------------------------------------------
# Support stats
# ---------------------------------------------------------------------------
@export var fatigue: int   = 0     # 0–100, reduces training efficiency
@export var morale: int    = 50    # 0–100, multiplies training efficiency
@export var momentum: int  = 0     # 0–100, in-match resource
@export var fame: int      = 0     # 0–100, unlocks shows / market tiers


# ---------------------------------------------------------------------------
# Lifecycle
# lifespan_days is rolled at birth from species lifespan_base +/- variance.
# It counts down each day. At 0 the monster dies.
# days_lived counts up — used for age display and evolution age gates.
# ---------------------------------------------------------------------------
@export var lifespan_days: int = 1825   # overwritten at birth by GameManager
@export var days_lived: int    = 0


# ---------------------------------------------------------------------------
# Personality
# personality        — current named state, id from PersonalityDefs
# personality_pressure — hidden accumulation buckets, personality_id -> float
#                        cleared on every shift. Never shown to player directly.
# ---------------------------------------------------------------------------
@export var personality: String = "determined"
@export var personality_pressure: Dictionary = {}


# ---------------------------------------------------------------------------
# Career tracking
# These fields are written during gameplay and read by:
#   - EvolutionSystem  (condition evaluation)
#   - CoachResource    (quality calculation at retirement)
#
# training_session_counts  — how many times each stat was trained this career
#                            e.g. {"power": 12, "technique": 8}
# events_triggered         — list of named career event ids that have fired
#                            e.g. ["won_regional_championship", "crowd_loves_you"]
# items_consumed           — list of item ids used during career
#                            e.g. ["iron_plate", "energy_drink"]
# championships_held       — list of championship ids won
#                            e.g. ["regional_title", "world_title"]
# career_stress_accumulated — running float stress score, fed by overtraining,
#                             injuries, overwork. Higher = worse coach quality.
# injuries_sustained       — total count of injury events, any severity
# ---------------------------------------------------------------------------
@export var training_session_counts: Dictionary  = {}
@export var events_triggered: Array[String]      = []
@export var items_consumed: Array[String]         = []
@export var championships_held: Array[String]     = []
@export var career_stress_accumulated: float      = 0.0
@export var injuries_sustained: int               = 0


# ---------------------------------------------------------------------------
# Learned moves
# Move ids the monster has learned. Populated by the move learn system
# after eligible events (shows, tours, training sessions).
# ---------------------------------------------------------------------------
@export var learned_moves: Array[String] = []


# ---------------------------------------------------------------------------
# Active effects
# Ongoing StatEffects currently applied to this monster.
# Checked each day by Wrestler.on_day_passed() for expiry.
# ---------------------------------------------------------------------------
@export var active_effects: Array[StatEffect] = []
