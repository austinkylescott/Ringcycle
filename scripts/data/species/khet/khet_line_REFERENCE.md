# khet_line — EvolutionLineResource
# Create in Godot: right-click scripts/data/species/khet/ -> New Resource -> EvolutionLineResource
# Save as: khet_line.tres
#
# -----------------------------------------------------------------------
# IDENTITY
# -----------------------------------------------------------------------
# line_id:      "khet"
# display_name: "Khet"
#
# -----------------------------------------------------------------------
# FORMS  (drag the .tres files into each slot)
# -----------------------------------------------------------------------
# form_rookie:   khet_rookie.tres
# form_pro:      khet_pro.tres
# form_legend_a: khet_legend_a.tres
# form_legend_b: khet_legend_b.tres
# form_legend_c: khet_legend_c.tres
#
# -----------------------------------------------------------------------
# LEGEND PRIORITY
# -----------------------------------------------------------------------
# legend_priority: ["legend_c", "legend_b", "legend_a"]
#
# -----------------------------------------------------------------------
# HINT REVEAL LEVELS
# -----------------------------------------------------------------------
# legend_a_hint_level: "vague"
# legend_b_hint_level: "vague"
# legend_c_hint_level: "none"
#
# -----------------------------------------------------------------------
# CONDITIONS — conditions_rookie_to_pro
# Add 2 EvolutionCondition items inline in the inspector array:
#
#   [0] type: AGE_MIN
#       days: 365
#
#   [1] type: STAGE_IS
#       stage: "Rookie"
#
#   [2] type: STAT_MIN
#       stat: "toughness"
#       value: 100
#
# -----------------------------------------------------------------------
# CONDITIONS — conditions_legend_a  (Nesut / Pharaoh)
# Natural path — balanced stats + fame
#
#   [0] type: STAGE_IS
#       stage: "Pro"
#
#   [1] type: STAT_MIN
#       stat:  "power"
#       value: 300
#       hint_vague: "Needs strong Power..."
#       hint_full:  "Needs 300 Power"
#
#   [2] type: STAT_MIN
#       stat:  "technique"
#       value: 300
#       hint_vague: "Needs refined Technique..."
#       hint_full:  "Needs 300 Technique"
#
#   [3] type: STAT_MIN
#       stat:  "toughness"
#       value: 320
#       hint_vague: "Needs solid Toughness..."
#       hint_full:  "Needs 320 Toughness"
#
#   [4] type: STAT_MIN
#       stat:  "stamina"
#       value: 320
#       hint_vague: "Needs enduring Stamina..."
#       hint_full:  "Needs 320 Stamina"
#
#   [5] type: STAT_MIN
#       stat:  "charisma"
#       value: 280
#       hint_vague: "Needs commanding Charisma..."
#       hint_full:  "Needs 280 Charisma"
#
#   [6] type: FAME_MIN
#       value: 50
#       hint_vague: "Needs a certain fame..."
#       hint_full:  "Needs 50 Fame"
#
# -----------------------------------------------------------------------
# CONDITIONS — conditions_legend_b  (Mesu-Bathu / Revenant)
# Specialist path — heavy Power + low Charisma
#
#   [0] type: STAGE_IS
#       stage: "Pro"
#
#   [1] type: TRAINING_MIN
#       stat:     "power"
#       sessions: 40
#       hint_vague: "Seems to respond to repeated Power training..."
#       hint_full:  "Needs 40 Power training sessions"
#
#   [2] type: STAT_MIN
#       stat:  "power"
#       value: 400
#       hint_vague: "Needs very high Power..."
#       hint_full:  "Needs 400 Power"
#
#   [3] type: STAT_MAX
#       stat:  "charisma"
#       value: 200
#       hint_vague: "Something happens when the crowd doesn't warm to them..."
#       hint_full:  "Needs Charisma below 200"
#
# -----------------------------------------------------------------------
# CONDITIONS — conditions_legend_c  (Aten-Ka / God-King)
# Against-grain path — all six stats above threshold simultaneously
# hint_vague is "???" intentionally — this path is hidden
#
#   [0] type: STAGE_IS
#       stage: "Pro"
#
#   [1] type: STAT_MIN
#       stat: "power",     value: 350
#       hint_vague: "???"  hint_full: "Needs 350 Power"
#
#   [2] type: STAT_MIN
#       stat: "technique"  value: 350
#       hint_vague: "???"  hint_full: "Needs 350 Technique"
#
#   [3] type: STAT_MIN
#       stat: "agility"    value: 320
#       hint_vague: "???"  hint_full: "Needs 320 Agility"
#
#   [4] type: STAT_MIN
#       stat: "toughness"  value: 350
#       hint_vague: "???"  hint_full: "Needs 350 Toughness"
#
#   [5] type: STAT_MIN
#       stat: "stamina"    value: 350
#       hint_vague: "???"  hint_full: "Needs 350 Stamina"
#
#   [6] type: STAT_MIN
#       stat: "charisma"   value: 320
#       hint_vague: "???"  hint_full: "Needs 320 Charisma"
