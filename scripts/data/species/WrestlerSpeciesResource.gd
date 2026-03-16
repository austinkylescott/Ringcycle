extends Resource
class_name WrestlerSpeciesResource

# ---------------------------------------------------------------------------
# Represents ONE form in a species line (Rookie, Pro, or a Legend variant).
# Evolution logic and line structure live in EvolutionLineResource.
#
# One file per form on disk:
#   species/brick_rookie.tres
#   species/brick_pro.tres
#   species/brick_legend_a.tres  etc.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
@export var id: String           # e.g. "brick_rookie" — unique across all forms
@export var display_name: String # e.g. "Brick" — shown to player
@export var stage: String        # "Rookie", "Pro", "Legend_A", "Legend_B", "Legend_C"

# ---------------------------------------------------------------------------
# Base stats
# Starting values for a fresh instance of this form.
# GameManager.create_wrestler_from_species() adds randi_range(-5, 5) variance.
# When a monster evolves, their CURRENT stats are kept and grown from —
# base_stats here are only used at birth (Rookie form).
# ---------------------------------------------------------------------------
@export var base_stats := {
	"power":     50,
	"technique": 40,
	"agility":   40,
	"toughness": 40,
	"stamina":   40,
	"charisma":  40,
}

# ---------------------------------------------------------------------------
# Growth profile
# Per-stat training multipliers for this form. 1.0 = normal gain rate.
# Stats not listed default to 1.0.
# Hidden from the player — they see letter grades, not numbers.
#
# A Rookie and their Pro form can have different growth profiles,
# letting a species feel different to train at different career stages.
# ---------------------------------------------------------------------------
@export var growth_profile := {
	"power":     1.0,
	"technique": 1.0,
	"agility":   1.0,
	"toughness": 1.0,
	"stamina":   1.0,
	"charisma":  1.0,
}

# ---------------------------------------------------------------------------
# Soft cap thresholds
# Above these values, training gains taper off via a global curve in
# TrainingSystem. Per-species taper rates are a future feature — for now
# the threshold defines WHERE tapering begins, not how steeply.
#
# Set a stat's threshold high to make it easy to keep growing.
# Set it low to make that stat feel expensive to push past its natural ceiling.
#
# Stats not listed have no soft cap.
# ---------------------------------------------------------------------------
@export var soft_caps := {
	"power":     500,
	"technique": 500,
	"agility":   500,
	"toughness": 500,
	"stamina":   500,
	"charisma":  500,
}

# ---------------------------------------------------------------------------
# Lifespan (Rookie form only — ignored on Pro and Legend forms)
# Pro and Legend forms inherit the lifespan rolled at birth.
#
# lifespan_base     — median lifespan in days
# lifespan_variance — max deviation: final = base + randi_range(-variance, +variance)
# lifespan_min      — floor regardless of roll
#
# Design guide:
#   Easy species (The Brick):    base=2190 (6yr), variance=365, min=730
#   Medium species (Showboat):   base=1825 (5yr), variance=365, min=547
#   Hard species (The Prodigy):  base=1095 (3yr), variance=365, min=365
# ---------------------------------------------------------------------------
@export var lifespan_base: int     = 1825
@export var lifespan_variance: int = 365
@export var lifespan_min: int      = 365

# ---------------------------------------------------------------------------
# Move pool
# Available move ids for this form. The move learn system samples from this
# pool weighted by current stats and active coach move bias.
# A Pro or Legend form's move pool should be a superset of its Rookie pool,
# so learned moves stay relevant after evolution.
# ---------------------------------------------------------------------------
@export var move_pool: Array[String] = []

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------
@export var portrait: Texture2D
@export var body_sprite: Texture2D
