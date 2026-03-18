extends Resource
class_name ShowSegment

# ---------------------------------------------------------------------------
# ShowSegment — one event on a show card.
# Produced by ShowManager, collected into ShowResult, consumed by ShowScreen.
#
# Kept as a standalone Resource so ShowManager and ShowScreen can both
# reference the type directly without inner class scope issues.
# ---------------------------------------------------------------------------

# Segment type
# "match"        — a wrestling match
# "promo"        — a promo or interview segment
# "show_frame"   — show opener or closer narrative line
# "interference" — run-in that affects another segment's outcome
@export var type: String = "match"

# Whether the player wrestler is involved in this segment.
@export var is_player: bool = false

# Display names of participants.
@export var participant_a: String = ""   # player wrestler or NPC A
@export var participant_b: String = ""   # opponent or NPC B (empty for solo)

# Outcome tier.
# Match:  "dominant" | "clean" | "close" | "upset"
# Promo:  "strong" | "decent" | "flat" | "heat"
@export var outcome_tier: String = ""

# Whether the player (or participant_a in background segments) won.
@export var player_won: bool = false

# Fame delta applied to the player this segment. 0 for non-player segments.
@export var fame_delta: float = 0.0

# Relationship event type recorded this segment.
# e.g. "match_win", "promo_confrontation", "interference_against"
@export var relationship_event: String = ""

# Title match fields.
@export var is_title_match: bool  = false
@export var title_name: String    = ""
@export var title_changed: bool   = false

# The narrative text line shown to the player.
@export var narrative: String = ""
