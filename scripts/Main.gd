extends Control

signal _modifier_picked(id: String)

const PAD_COUNT := 8
const PAD_WIDTH := 70.0
const PAD_HEIGHT := 170.0
const BASE_RADIUS := 60.0
const RING_CENTER := Vector2(400.0, 400.0)

const MODIFIER_ROUND_INTERVAL := 3

# Wave-reset scoring escalation, player-triggered version: unlike the design
# doc's original forced-cap-at-a-climbing-ceiling shape, there is no forced
# reset - the player decides when to cash out a growing sequence/phrase for
# a bonus (deliberately rejected the forced version: interrupting a player's
# groove mid-sequence read as jarring rather than tense). The bonus scales
# quadratically with how long the current streak has run - risk of a miss
# (which forfeits the unbanked bonus, not the run or its already-earned
# score) is what discourages riding forever, not an artificial cutoff.
# Applies identically to Normal, Chaos, and Duet.
const CASHOUT_QUADRATIC_K := 2.0
const WAVE_RESET_LENGTH := 0

# Music Mode: rhythm generated as a Euclidean pattern (Bjorklund's algorithm)
# over a fixed 16-step bar, re-rolled each phrase for variety.
const MUSIC_RHYTHM_STEPS := 16
const MUSIC_PULSES_MIN := 5
const MUSIC_PULSES_MAX := 9
# Scales with a half-step or tritone in them - capped to a smaller max leap
# than the (dissonance-proof) pentatonic scales to avoid the harshest jumps.
const MUSIC_NARROW_LEAP_SCALES := ["d_minor", "c_major_diatonic", "chromatic_run"]
const MUSIC_PENTATONIC_MAX_LEAP := 4
const MUSIC_NARROW_MAX_LEAP := 3
const MUSIC_PHRASE_BARS := 4
# The 30% flat "repeat" chance in the walk, combined with edges clamping a
# blocked step back onto the same degree, can otherwise chain into long
# runs of the identical note - hard-cap it instead of leaving it to chance.
const BASE_REPEAT_CHANCE := 0.30
const REPEAT_DECAY := 0.4
const STEP_TO_NON_REPEAT_RATIO := 0.55 / 0.70
# Normal Mode's sequence is one continuous, ever-growing phrase with no bar
# structure to hang periodic tonic resolution off of (unlike Music/Duet's
# 4-bar phrases) - so it gets its own note-count-based phrase length instead.
const NORMAL_PHRASE_LENGTH := 8
# Duet Mode timing-accuracy tiers, scored on top of note-identity correctness
# (see docs/game-modes.md) - tight/good/late affect points only, never
# pass/fail. DUET_NOTE_GRACE_SEC is a flat, generous per-note deadline
# (unrelated to the rhythmic grid) so a miss reflects real inattention
# rather than reaction-time pressure.
const DUET_TIGHT_WINDOW := 0.06
const DUET_GOOD_WINDOW := 0.15
const DUET_TIGHT_MULT := 1.5
const DUET_GOOD_MULT := 1.0
const DUET_LATE_MULT := 0.5
const DUET_NOTE_GRACE_SEC := 1.2
# Tempo ramps with round count, same capped-ramp idea as Chaos Mode's speed
# increase (see docs/game-modes.md) - starts modest, never runs away.
const DUET_BPM_BASE_MIN := 88.0
const DUET_BPM_BASE_MAX := 100.0
const DUET_BPM_RAMP_PER_ROUND := 2.5
const DUET_BPM_CAP := 150.0
# Randomized once per Music Mode session (not per phrase) so tempo doesn't
# jitter bar-to-bar.
const MUSIC_BPM_MIN := 55.0
const MUSIC_BPM_MAX := 85.0
const MUSIC_FLASH_FRACTION := 0.7
const MUSIC_FLASH_MAX := 0.35
# Faster decay than the default 3.2 (used for slow, one-note-at-a-time
# sequence recall) - at Music Mode's note spacing, the default's ~1.4s
# audible tail overlaps several notes at once and blurs the rhythm.
const MUSIC_DECAY_RATE := 8.0
const MUSIC_VOLUME := 0.4
# The Euclidean generator always places an onset at step 0 of the pattern,
# so accenting step 0 accents the bar's downbeat.
const MUSIC_ACCENT_DECAY := 5.0
const MUSIC_ACCENT_VOLUME := 0.55
const MODIFIERS := [
	{"id": "sharper_ear", "icon": "♪", "title": "Sharper Ear", "desc": "Combo multiplier grows faster per hit"},
	{"id": "safety_net", "icon": "❖", "title": "Safety Net", "desc": "Forgive your next mistake and show the correct pad (stacks)"},
	{"id": "golden_step", "icon": "★", "title": "Golden Step", "desc": "One extra step per round is worth 3x points"},
	{"id": "steady_hands", "icon": "⏱", "title": "Steady Hands", "desc": "Sequence plays back 15% slower"},
	{"id": "resonance", "icon": "♦", "title": "Resonance", "desc": "+10% score on all hits"},
]

const SCALES := [
	{"id": "d_minor_pentatonic", "name": "D Minor\nPentatonic", "tones": [146.83, 174.61, 196.0, 220.0, 261.63, 293.66, 349.23, 440.0], "notes": ["D", "F", "G", "A", "C", "D", "F", "A"], "ring_order": [0, 2, 4, 1, 6, 3, 7, 5]},
	{"id": "c_major_pentatonic", "name": "C Major\nPentatonic", "tones": [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25], "notes": ["C", "D", "E", "G", "A", "C", "D", "E"], "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "d_akebono", "name": "D Akebono", "tones": [293.66, 329.63, 349.23, 440.0, 466.16, 587.33, 659.25, 698.46], "notes": ["D", "E", "F", "A", "Bb", "D", "E", "F"], "ring_order": [0, 1, 6, 3, 2, 7, 4, 5]},
	{"id": "d_minor", "name": "D Minor\nDiatonic", "tones": [146.83, 164.81, 174.61, 196.0, 220.0, 233.08, 261.63, 293.66], "notes": ["D", "E", "F", "G", "A", "Bb", "C", "D"], "unlock": {"type": "round", "value": 10}, "ring_order": [0, 3, 5, 2, 6, 1, 4, 7]},
	{"id": "e_minor_pentatonic", "name": "E Minor\nPentatonic", "tones": [164.81, 196.0, 220.0, 246.94, 293.66, 329.63, 392.0, 440.0], "notes": ["E", "G", "A", "B", "D", "E", "G", "A"], "unlock": {"type": "round", "value": 5}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "g_major_pentatonic", "name": "G Major\nPentatonic", "tones": [196.0, 220.0, 246.94, 293.66, 329.63, 392.0, 440.0, 493.88], "notes": ["G", "A", "B", "D", "E", "G", "A", "B"], "unlock": {"type": "score", "value": 500}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "c_major_diatonic", "name": "C Major\nDiatonic", "tones": [130.81, 146.83, 164.81, 174.61, 196.0, 220.0, 246.94, 261.63], "notes": ["C", "D", "E", "F", "G", "A", "B", "C"], "unlock": {"type": "combo", "value": 15}, "ring_order": [0, 3, 1, 5, 2, 6, 4, 7]},
	{"id": "chromatic_run", "name": "Chromatic\nRun", "tones": [130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.0, 196.0], "notes": ["C", "C#", "D", "D#", "E", "F", "F#", "G"], "unlock": {"type": "round", "value": 15}, "ring_order": [0, 4, 1, 6, 3, 7, 2, 5]},
	{"id": "a_minor_pentatonic", "name": "A Minor\nPentatonic", "tones": [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33], "notes": ["A", "C", "D", "E", "G", "A", "C", "D"], "unlock": {"type": "round", "value": 25}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "a_akebono_pentatonic", "name": "A Akebono\nPentatonic", "tones": [220.0, 246.94, 261.63, 329.63, 349.23, 440.0, 493.88, 523.25], "notes": ["A", "B", "C", "E", "F", "A", "B", "C"], "unlock": {"type": "score", "value": 3000}, "ring_order": [0, 1, 6, 3, 2, 7, 4, 5]},
	{"id": "e_major_pentatonic", "name": "E Major\nPentatonic", "tones": [164.81, 185.0, 207.65, 246.94, 277.18, 329.63, 369.99, 415.3], "notes": ["E", "F#", "G#", "B", "C#", "E", "F#", "G#"], "unlock": {"type": "combo", "value": 25}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
]

const PALETTES := [
	{"id": "anodized", "name": "Anodized", "hue_start": 0.0, "hue_end": 1.0, "wrap": true, "sat": 0.55, "val": 0.55, "lit_sat": 0.4, "lit_val": 1.0},
	{"id": "pastel", "name": "Pastel Dream", "hue_start": 0.0, "hue_end": 1.0, "wrap": true, "sat": 0.35, "val": 0.78, "lit_sat": 0.25, "lit_val": 0.98},
	{"id": "sunset", "name": "Sunset", "hue_start": 0.0, "hue_end": 0.13, "wrap": false, "sat": 0.65, "val": 0.6, "lit_sat": 0.5, "lit_val": 1.0},
	{"id": "ocean", "name": "Ocean Steel", "hue_start": 0.48, "hue_end": 0.68, "wrap": false, "sat": 0.5, "val": 0.5, "lit_sat": 0.35, "lit_val": 0.95},
	{"id": "monochrome_steel", "name": "Monochrome\nSteel", "hue_start": 0.6, "hue_end": 0.62, "wrap": false, "sat": 0.08, "val": 0.55, "lit_sat": 0.05, "lit_val": 0.95, "unlock": {"type": "round", "value": 5}},
	{"id": "neon", "name": "Neon", "hue_start": 0.0, "hue_end": 1.0, "wrap": true, "sat": 0.85, "val": 0.95, "lit_sat": 0.7, "lit_val": 1.0, "unlock": {"type": "score", "value": 500}},
	{"id": "forest", "name": "Forest", "hue_start": 0.25, "hue_end": 0.42, "wrap": false, "sat": 0.55, "val": 0.5, "lit_sat": 0.4, "lit_val": 0.9, "unlock": {"type": "combo", "value": 15}},
	{"id": "royal", "name": "Royal", "hue_start": 0.7, "hue_end": 0.87, "wrap": false, "sat": 0.6, "val": 0.55, "lit_sat": 0.45, "lit_val": 0.95, "unlock": {"type": "round", "value": 15}},
	{"id": "galaxy", "name": "Galaxy", "shader": "res://shaders/galaxy.gdshader", "accent_color": Color(0.55, 0.35, 0.85), "unlock": {"type": "round", "value": 20}},
	{"id": "aurora", "name": "Aurora", "shader": "res://shaders/aurora.gdshader", "accent_color": Color(0.2, 0.85, 0.6), "unlock": {"type": "score", "value": 1500}},
	{"id": "graphite_spectrum", "name": "Graphite\nSpectrum", "colors": [Color(0.263, 0.733, 0.655), Color(0.216, 0.730, 0.717), Color(0.211, 0.722, 0.773), Color(0.250, 0.710, 0.823), Color(0.313, 0.695, 0.863), Color(0.384, 0.676, 0.893), Color(0.457, 0.656, 0.912), Color(0.526, 0.635, 0.918)]},
]

# Every theme carries its pad look directly as pad_style, so Theme is the
# only axis the player chooses in Settings - there's no separate Palette
# picker to fall out of sync with it.
const THEMES := [
	{"id": "premium_minimal", "name": "Premium &\nMinimal", "bg": Color(0.046, 0.053, 0.060), "panel": Color(0.082, 0.092, 0.103), "border": Color(0.165, 0.181, 0.199), "text": Color(0.914, 0.923, 0.932), "text_muted": Color(0.520, 0.540, 0.561), "accent": Color(0.000, 0.767, 0.859), "accent2": Color(0.523, 0.673, 1.000)},
	{"id": "cosmic_atmospheric", "name": "Cosmic &\nAtmospheric", "shader": "res://shaders/galaxy.gdshader", "resonator_color": Color(0.1, 0.08, 0.18, 1), "background_color": Color(0.02, 0.015, 0.05, 1), "bg": Color(0.039, 0.030, 0.085), "panel": Color(0.077, 0.066, 0.135), "border": Color(0.198, 0.181, 0.293), "text": Color(0.933, 0.931, 0.960), "text_muted": Color(0.595, 0.590, 0.644), "accent": Color(0.718, 0.526, 1.000), "accent2": Color(0.942, 0.438, 0.745), "unlock": {"type": "round", "value": 20},
		"pad_style": {"shader": "res://shaders/galaxy.gdshader", "accent_color": Color(0.718, 0.526, 1.000)}},
	{"id": "warm_tactile", "name": "Warm &\nTactile", "bg": Color(0.104, 0.082, 0.057), "panel": Color(0.157, 0.126, 0.091), "border": Color(0.253, 0.211, 0.164), "text": Color(0.949, 0.932, 0.913), "text_muted": Color(0.621, 0.592, 0.559), "accent": Color(0.791, 0.617, 0.199), "accent2": Color(0.921, 0.510, 0.481), "unlock": {"type": "round", "value": 3},
		"pad_style": {"colors": [Color(0.854, 0.506, 0.534), Color(0.857, 0.511, 0.487), Color(0.854, 0.519, 0.442), Color(0.846, 0.529, 0.398), Color(0.832, 0.542, 0.358), Color(0.813, 0.557, 0.323), Color(0.789, 0.573, 0.296), Color(0.759, 0.591, 0.279)]}},
	{"id": "playful_colorful", "name": "Playful &\nColorful", "bg": Color(0.956, 0.948, 0.919), "panel": Color(0.990, 0.987, 0.976), "border": Color(0.869, 0.858, 0.815), "text": Color(0.134, 0.123, 0.080), "text_muted": Color(0.402, 0.390, 0.340), "accent": Color(1.000, 0.412, 0.445), "accent2": Color(0.268, 0.646, 1.000), "unlock": {"type": "score", "value": 300},
		"pad_style": {"colors": [Color(0.983, 0.425, 0.627), Color(0.992, 0.473, 0.201), Color(0.816, 0.613, 0.000), Color(0.437, 0.738, 0.225), Color(0.000, 0.780, 0.662), Color(0.000, 0.724, 0.973), Color(0.477, 0.606, 1.000), Color(0.808, 0.491, 0.944)]}},
	{"id": "monochrome_noir", "name": "Monochrome\nNoir", "bg": Color(0.007, 0.007, 0.007), "panel": Color(0.028, 0.028, 0.028), "border": Color(0.141, 0.141, 0.141), "text": Color(0.961, 0.961, 0.961), "text_muted": Color(0.445, 0.445, 0.445), "accent": Color(0.703, 0.134, 0.158), "accent2": Color(0.806, 0.806, 0.806), "unlock": {"type": "combo", "value": 8},
		"pad_style": {"colors": [Color(0.104, 0.104, 0.104), Color(0.189, 0.189, 0.189), Color(0.281, 0.281, 0.281), Color(0.378, 0.378, 0.378), Color(0.782, 0.293, 0.280), Color(0.585, 0.585, 0.585), Color(0.694, 0.694, 0.694), Color(0.806, 0.806, 0.806)]}},
	{"id": "retro_arcade", "name": "Retro\nArcade", "bg": Color(0.008, 0.029, 0.012), "panel": Color(0.022, 0.064, 0.030), "border": Color(0.116, 0.230, 0.121), "text": Color(0.499, 0.926, 0.401), "text_muted": Color(0.316, 0.501, 0.275), "accent": Color(0.499, 0.926, 0.401), "accent2": Color(1.000, 0.669, 0.000), "unlock": {"type": "score", "value": 1000},
		"pad_style": {"shader": "res://shaders/scanline.gdshader", "accent_color": Color(0.499, 0.926, 0.401)}},
	{"id": "zen_garden", "name": "Zen\nGarden", "bg": Color(0.896, 0.916, 0.891), "panel": Color(0.953, 0.965, 0.950), "border": Color(0.787, 0.817, 0.781), "text": Color(0.112, 0.141, 0.106), "text_muted": Color(0.366, 0.401, 0.359), "accent": Color(0.420, 0.617, 0.460), "accent2": Color(0.320, 0.607, 0.694), "unlock": {"type": "round", "value": 8},
		"pad_style": {"colors": [Color(0.636, 0.603, 0.403), Color(0.590, 0.619, 0.422), Color(0.541, 0.633, 0.453), Color(0.492, 0.644, 0.493), Color(0.446, 0.651, 0.539), Color(0.408, 0.654, 0.587), Color(0.385, 0.653, 0.634), Color(0.380, 0.647, 0.678)]}},
	{"id": "raw_steel", "name": "Raw\nSteel", "bg": Color(0.099, 0.105, 0.111), "panel": Color(0.144, 0.151, 0.160), "border": Color(0.248, 0.262, 0.277), "text": Color(0.916, 0.922, 0.929), "text_muted": Color(0.551, 0.563, 0.575), "accent": Color(0.568, 0.629, 0.694), "accent2": Color(0.801, 0.454, 0.332), "unlock": {"type": "combo", "value": 20},
		"pad_style": {"colors": [Color(0.456, 0.638, 0.624), Color(0.453, 0.636, 0.642), Color(0.454, 0.633, 0.660), Color(0.459, 0.629, 0.675), Color(0.467, 0.625, 0.689), Color(0.479, 0.620, 0.701), Color(0.493, 0.614, 0.710), Color(0.510, 0.608, 0.717)]}},
	{"id": "solar_flare", "name": "Solar\nFlare", "bg": Color(0.091, 0.047, 0.040), "panel": Color(0.145, 0.087, 0.077), "border": Color(0.255, 0.177, 0.164), "text": Color(0.973, 0.940, 0.929), "text_muted": Color(0.608, 0.545, 0.533), "accent": Color(0.986, 0.353, 0.276), "accent2": Color(0.905, 0.625, 0.000), "unlock": {"type": "score", "value": 2500},
		"pad_style": {"shader": "res://shaders/ember.gdshader", "accent_color": Color(0.986, 0.353, 0.276)}},
]
const DEFAULT_RESONATOR_COLOR := Color(0.35, 0.37, 0.4, 1)
const DEFAULT_BACKGROUND_COLOR := Color(0.05, 0.05, 0.07, 1)

const SAVE_PATH := "user://simon_save.json"
const EASTER_EGG_CODE := "hubert"

const ONBOARDING_STEPS := [
	{"title": "Watch, Then Repeat", "body": "Each round, the pads flash a sequence of notes. Repeat it back by pressing the same pads in order - the sequence grows by one note every round you clear."},
	{"title": "Score & Combo", "body": "Correct hits build a combo streak, which boosts your score multiplier. A forgiven miss halves your combo instead of wiping it out."},
	{"title": "Cash Out Anytime", "body": "Your points build up as an unbanked streak total while you play. Tap Cash Out whenever you want to bank them - plus a bonus that grows the longer the streak ran - and start a fresh, short sequence. A miss before you cash out forfeits that streak's points, so bank when you don't want to risk it."},
	{"title": "Five Ways to Play", "body": "Normal Mode is the standard growing sequence. Chaos reshuffles the pads and speeds up each round. Duet has the game play a short phrase for you to echo back exactly. Zen has no sequence or fail state - just play freely. Music plays itself for chill, hands-off listening."},
	{"title": "Modifier Choices", "body": "Every 3rd round, pick one of three modifiers to stack for the rest of the run - they can change scoring, forgiveness, and pacing."},
]

@onready var background_rect: ColorRect = $Background
@onready var resonator_panel: Panel = $Resonator
@onready var pad_ring: Control = $PadRing
@onready var start_button: Button = $ModeBar/StartButton
@onready var round_label: Label = $RoundLabel
@onready var combo_label: Label = $ComboLabel
@onready var score_label: Label = $ScoreLabel
@onready var cash_out_button: Button = $CashOutButton
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var modifier_panel: Control = $ModifierPanel
@onready var modifier_vbox: Control = $ModifierPanel/CenterContainer/VBoxContainer
@onready var modifier_buttons: Array[Button] = [
	$ModifierPanel/CenterContainer/VBoxContainer/Option1,
	$ModifierPanel/CenterContainer/VBoxContainer/Option2,
	$ModifierPanel/CenterContainer/VBoxContainer/Option3,
]
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel
@onready var settings_scroll: Control = $SettingsPanel/CenterContainer/ContentBox
@onready var settings_tabs: TabContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer
@onready var settings_panel_bg: PanelContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG
@onready var scale_grid: GridContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Scales/Margin/ScaleGrid
var scale_buttons: Array[Button] = []
var scale_card_badges: Array[PanelContainer] = []
var scale_card_notes_rows: Array[HBoxContainer] = []
var scale_card_unlock_labels: Array[Label] = []
@onready var theme_grid: GridContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Themes/Margin/VBoxContainer/ThemeCenterContainer/ThemeGrid
@onready var palette_section: Control = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Themes/Margin/VBoxContainer/PaletteSection
@onready var palette_grid: GridContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Themes/Margin/VBoxContainer/PaletteSection/PaletteGrid
var palette_buttons: Array[Button] = []
var theme_buttons: Array[Button] = []
var theme_card_badges: Array[PanelContainer] = []
var theme_card_unlock_labels: Array[Label] = []
var palette_card_badges: Array[PanelContainer] = []
var palette_card_unlock_labels: Array[Label] = []
@onready var settings_close_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/CloseButton
@onready var settings_close_x_button: Button = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/CloseXButton
@onready var settings_reset_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ResetButton
@onready var settings_confirm_row: HBoxContainer = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ConfirmRow
@onready var settings_confirm_yes_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ConfirmRow/ConfirmYesButton
@onready var settings_confirm_no_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ConfirmRow/ConfirmNoButton
@onready var best_score_label: Label = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/StatRow/ScoreTile/ValueLabel
@onready var best_round_label: Label = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/StatRow/RoundTile/ValueLabel
@onready var best_combo_label: Label = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/StatRow/ComboTile/ValueLabel

@onready var help_button: Button = $HelpButton
@onready var onboarding_panel: Control = $OnboardingPanel
@onready var onboarding_step_label: Label = $OnboardingPanel/CenterContainer/VBoxContainer/StepIndicatorLabel
@onready var onboarding_title_label: Label = $OnboardingPanel/CenterContainer/VBoxContainer/TitleLabel
@onready var onboarding_body_label: Label = $OnboardingPanel/CenterContainer/VBoxContainer/BodyLabel
@onready var onboarding_skip_button: Button = $OnboardingPanel/CenterContainer/VBoxContainer/ButtonRow/SkipButton
@onready var onboarding_next_button: Button = $OnboardingPanel/CenterContainer/VBoxContainer/ButtonRow/NextButton

@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_stats_label: Label = $GameOverPanel/CenterContainer/VBoxContainer/StatsLabel
@onready var game_over_best_label: Label = $GameOverPanel/CenterContainer/VBoxContainer/BestLabel
@onready var game_over_close_button: Button = $GameOverPanel/CenterContainer/VBoxContainer/CloseButton

@onready var reduce_motion_check: CheckBox = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Accessibility/Margin/CenterContainer/VBoxContainer/ReduceMotionCheck

const MIX_BUSES := ["Master", "Tones", "UI"]
const MIX_DEFAULTS := {"Master": 1.0, "Tones": 0.9, "UI": 0.5}
@onready var mix_sliders: Dictionary = {
	"Master": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/MasterRow/Slider,
	"Tones": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/TonesRow/Slider,
	"UI": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/UIRow/Slider,
}
@onready var mix_pct_labels: Dictionary = {
	"Master": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/MasterRow/PctLabel,
	"Tones": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/TonesRow/PctLabel,
	"UI": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/UIRow/PctLabel,
}
@onready var zen_button: Button = $ModeBar/ZenButton
@onready var zen_bar: Control = $ZenBar
@onready var exit_zen_button: Button = $ZenBar/ExitZenButton
@onready var chaos_button: Button = $ModeBar/ChaosButton
@onready var music_button: Button = $ModeBar/MusicButton
@onready var music_bar: Control = $MusicBar
@onready var exit_music_button: Button = $MusicBar/ExitMusicButton
@onready var duet_button: Button = $ModeBar/DuetButton

var pads_by_name: Dictionary = {}
var pad_names: Array[String] = []
var pad_slots: Array = []
var pad_slot_order: Array[String] = []
var note_labels: Dictionary = {}
var chaos_mode := false
var sequence: Array[String] = []
var gold_indices: Array[int] = []
var player_index := 0
var accepting_input := false
var score := 0
var combo := 0
var current_offer: Array = []
var current_scale_index := 0
var current_palette_index := 0
var current_theme_index := 0
var zen_mode := false
var music_mode := false
var duet_mode := false
var duet_round := 0
var duet_rhythm: Array[bool] = []
var duet_step_duration := 0.0
var duet_pulse_times: Array[float] = []
var _duet_last_press := ""
var _duet_last_press_pos := Vector2.ZERO
var _normal_current_degree := 0
var _normal_last_direction := 0
var _normal_last_was_leap := false
var _normal_repeat_streak := 1
var _music_repeat_streak := 1
var _music_current_degree := 0
var _music_last_direction := 0
var _music_last_was_leap := false
var _music_bar_index := 0
var best_score := 0
var best_round := 0
var best_combo := 0
var cheat_all_unlocked := false
var onboarding_seen := false
var onboarding_step := 0
var mix_levels: Dictionary = MIX_DEFAULTS.duplicate()
var reduce_motion := false
var run_start_best_score := 0
var run_start_best_round := 0
var run_start_best_combo := 0
var run_new_unlocks: Array[Dictionary] = []
var _typed_buffer := ""

# Modifier-driven run stats, reset each new run.
var combo_growth := 0.1
var mistake_charges := 0
var golden_step_count := 0
var sequence_speed_multiplier := 1.0
var score_bonus_percent := 0.0
var modifier_stacks: Dictionary = {}

# Wave-reset state. `waves_completed` only increments on a voluntary cash
# out (no forced cap to hit). Duet needs its own wave-local round counter
# since its ramp (bpm/pulses in `_generate_duet_phrase`) is driven by round
# count, not a cumulative sequence - `duet_wave_round` resets on cash out
# while `duet_round` (below) keeps incrementing for modifier cadence.
var waves_completed := 0
var duet_wave_round := 0
# Per-hit points earned since the last cash out - not added to `score` (the
# real, permanent total) until banked. A forgiven miss (Safety Net charge)
# leaves this untouched - forgiveness protects points, not just the run,
# per the design call: "otherwise what's the point [of forgiveness]?" A
# true run-ending miss forfeits it, since it's never added to `score`.
var unbanked_points := 0
# Monotonic round counter, distinct from `sequence.size()` which now resets
# on cash out - keeps MODIFIER_ROUND_INTERVAL/best-round tracking on a
# steady cadence across resets ("round count keeps incrementing across
# resets"). Duet Mode already has its own `duet_round` for this purpose and
# is unaffected.
var total_round := 0

func _ready() -> void:
	# Godot's global random functions default to a fixed seed - without this,
	# every fresh launch replays the exact same "random" sequence from the
	# first call onward (Chaos reshuffles, Normal/Music/Duet note walks, gold
	# steps, modifier offers, everything that uses randi()/randf()/.shuffle()).
	randomize()
	_load_progress()
	start_button.pressed.connect(_on_start_pressed.bind("normal"))
	chaos_button.pressed.connect(_on_start_pressed.bind("chaos"))
	settings_button.pressed.connect(_on_settings_button_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)
	settings_close_x_button.pressed.connect(_on_settings_close_pressed)
	settings_reset_button.pressed.connect(_on_reset_ask_pressed)
	settings_confirm_yes_button.pressed.connect(_on_reset_progress_pressed)
	settings_confirm_no_button.pressed.connect(_on_reset_cancel_pressed)
	zen_button.pressed.connect(_on_zen_button_pressed)
	exit_zen_button.pressed.connect(_on_exit_zen_pressed)
	music_button.pressed.connect(_on_music_button_pressed)
	exit_music_button.pressed.connect(_on_exit_music_pressed)
	duet_button.pressed.connect(_on_start_pressed.bind("duet"))
	cash_out_button.pressed.connect(_on_cash_out_button_pressed)
	for i in modifier_buttons.size():
		modifier_buttons[i].pressed.connect(_on_modifier_button_pressed.bind(i))
	_build_scale_cards()
	_build_palette_and_theme_buttons()
	for i in palette_buttons.size():
		palette_buttons[i].pressed.connect(_on_palette_button_pressed.bind(i))
	for i in theme_buttons.size():
		theme_buttons[i].pressed.connect(_on_theme_button_pressed.bind(i))
	settings_tabs.tab_changed.connect(_on_settings_tab_changed)
	help_button.pressed.connect(_on_help_button_pressed)
	onboarding_skip_button.pressed.connect(_on_onboarding_close_pressed)
	onboarding_next_button.pressed.connect(_on_onboarding_next_pressed)
	game_over_close_button.pressed.connect(_on_game_over_close_pressed)
	_connect_ui_clicks()
	_setup_mix_sliders()
	reduce_motion_check.button_pressed = reduce_motion
	reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	_apply_theme()
	_build_pads()
	if not onboarding_seen:
		_show_onboarding()

# A small pill used by scale/palette/theme cards to show "ACTIVE" or a lock
# icon. Built as a PanelContainer + Label (not a bare Label) because Label
# never draws a background stylebox on its own - only a Panel-family control
# does, so the pill's accent-colored background needs the wrapper to render.
func _make_pick_badge(parent: Control) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	parent.add_child(badge)
	return badge

func _style_pick_badge(badge: PanelContainer, active: bool, locked: bool, accent: Color, accent_text: Color) -> void:
	var label: Label = badge.get_child(0)
	if active:
		label.text = "ACTIVE"
		label.add_theme_color_override("font_color", accent_text)
		var sb := StyleBoxFlat.new()
		sb.bg_color = accent
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", sb)
	else:
		label.text = "🔒" if locked else ""
		label.remove_theme_color_override("font_color")
		# Explicit transparent stylebox rather than removing the override -
		# without it the badge falls back to the global "PanelContainer"
		# theme style (a visible rounded/bordered box) even with empty text.
		badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _style_pick_card(card: Button, active: bool, locked: bool, accent: Color, border: Color, corner_radius: int) -> void:
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = border.darkened(0.15) if locked else Color(border, 0.5)
	card_sb.border_color = accent if active else border
	card_sb.set_border_width_all(2 if active else 1)
	card_sb.set_corner_radius_all(corner_radius)
	card.add_theme_stylebox_override("normal", card_sb)
	card.add_theme_stylebox_override("disabled", card_sb)
	var card_hover_sb: StyleBoxFlat = card_sb.duplicate()
	card_hover_sb.border_color = accent
	card.add_theme_stylebox_override("hover", card_hover_sb)
	card.modulate.a = 0.65 if locked else 1.0

# Cards are built here rather than hand-placed in the scene, same reasoning as
# `_build_pads()` - 11 near-identical nodes are far less error-prone generated
# from `SCALES` than hand-authored in the .tscn.
func _build_scale_cards() -> void:
	for i in SCALES.size():
		var scale: Dictionary = SCALES[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(280, 108)
		card.focus_mode = Control.FOCUS_NONE
		card.clip_contents = true
		card.pressed.connect(_on_scale_button_pressed.bind(i))
		scale_grid.add_child(card)
		scale_buttons.append(card)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)

		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(header)

		var name_label := Label.new()
		name_label.text = scale["name"]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = 2
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(name_label)

		scale_card_badges.append(_make_pick_badge(header))

		var notes_row := HBoxContainer.new()
		notes_row.add_theme_constant_override("separation", 4)
		notes_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(notes_row)
		for note in scale["notes"]:
			var chip := PanelContainer.new()
			chip.custom_minimum_size = Vector2(24, 24)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var chip_sb := StyleBoxFlat.new()
			chip_sb.bg_color = Color(1, 1, 1, 0.08)
			chip_sb.set_corner_radius_all(5)
			chip.add_theme_stylebox_override("panel", chip_sb)
			var chip_label := Label.new()
			chip_label.text = note
			chip_label.add_theme_font_size_override("font_size", 10)
			chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(chip_label)
			notes_row.add_child(chip)
		scale_card_notes_rows.append(notes_row)

		var unlock_label := Label.new()
		unlock_label.add_theme_font_size_override("font_size", 11)
		unlock_label.autowrap_mode = 2
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unlock_label.visible = false
		if scale.has("unlock"):
			unlock_label.text = _requirement_text(scale["unlock"])
		vbox.add_child(unlock_label)
		scale_card_unlock_labels.append(unlock_label)

func _build_palette_and_theme_buttons() -> void:
	for i in PALETTES.size():
		var palette: Dictionary = PALETTES[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true
		palette_grid.add_child(btn)
		palette_buttons.append(btn)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		btn.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(row)

		var swatch_row := HBoxContainer.new()
		swatch_row.add_theme_constant_override("separation", 3)
		swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in _palette_preview_colors(palette):
			var chip := ColorRect.new()
			chip.color = c
			chip.custom_minimum_size = Vector2(18, 18)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(chip)
		row.add_child(swatch_row)

		var name_label := Label.new()
		name_label.text = palette["name"]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		if palette.get("animated", false):
			var animated_tag := Label.new()
			animated_tag.text = "ANIMATED"
			animated_tag.add_theme_font_size_override("font_size", 9)
			animated_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(animated_tag)

		palette_card_badges.append(_make_pick_badge(row))

		var unlock_label := Label.new()
		unlock_label.add_theme_font_size_override("font_size", 11)
		unlock_label.visible = false
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if palette.has("unlock"):
			unlock_label.text = _requirement_text(palette["unlock"])
		row.add_child(unlock_label)
		palette_card_unlock_labels.append(unlock_label)

	for i in THEMES.size():
		var theme_data: Dictionary = THEMES[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(196, 120)
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true
		theme_grid.add_child(btn)
		theme_buttons.append(btn)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		btn.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)

		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(0, 44)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var preview_sb := StyleBoxFlat.new()
		preview_sb.bg_color = theme_data["panel"]
		preview_sb.border_color = theme_data["border"]
		preview_sb.set_border_width_all(1)
		preview_sb.set_corner_radius_all(6)
		preview_sb.content_margin_left = 8
		preview_sb.content_margin_top = 6
		preview.add_theme_stylebox_override("panel", preview_sb)
		var preview_row := HBoxContainer.new()
		preview_row.add_theme_constant_override("separation", 6)
		preview_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in [theme_data["bg"], theme_data["accent"], theme_data["accent2"]]:
			var dot := ColorRect.new()
			dot.color = c
			dot.custom_minimum_size = Vector2(14, 14)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_row.add_child(dot)
		preview.add_child(preview_row)
		vbox.add_child(preview)

		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(header)

		var name_label := Label.new()
		name_label.text = theme_data["name"].replace("\n", " ")
		name_label.add_theme_font_size_override("font_size", 12.5)
		name_label.autowrap_mode = 2
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(name_label)

		theme_card_badges.append(_make_pick_badge(header))

		var unlock_label := Label.new()
		unlock_label.add_theme_font_size_override("font_size", 10.5)
		unlock_label.autowrap_mode = 2
		unlock_label.visible = false
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if theme_data.has("unlock"):
			unlock_label.text = "🔒 " + _requirement_text(theme_data["unlock"])
		vbox.add_child(unlock_label)
		theme_card_unlock_labels.append(unlock_label)

func _palette_preview_colors(palette: Dictionary) -> Array[Color]:
	if palette.has("colors"):
		var explicit: Array[Color] = []
		explicit.assign(palette["colors"])
		return explicit
	if palette.has("shader"):
		var c: Color = palette["accent_color"]
		var shader_colors: Array[Color] = [c, c.lightened(0.15), c.lightened(0.3), c.darkened(0.15)]
		return shader_colors
	var colors: Array[Color] = []
	for i in PAD_COUNT:
		var hue := _pad_hue(i, palette)
		colors.append(Color.from_hsv(hue, palette["sat"], palette["val"]))
	return colors

func _connect_ui_clicks() -> void:
	# Soft UI SFX for routine interactions - distinct from gameplay pad tones.
	var ui_click_buttons: Array[Button] = [
		start_button, chaos_button, zen_button, exit_zen_button,
		music_button, exit_music_button, duet_button,
		settings_button, settings_close_button, settings_close_x_button, settings_reset_button,
		settings_confirm_yes_button, settings_confirm_no_button,
		help_button, onboarding_skip_button, onboarding_next_button,
		game_over_close_button, cash_out_button,
	]
	ui_click_buttons.append_array(scale_buttons)
	ui_click_buttons.append_array(palette_buttons)
	ui_click_buttons.append_array(theme_buttons)
	ui_click_buttons.append_array(modifier_buttons)
	for button in ui_click_buttons:
		button.pressed.connect(Sound.play_ui_tick.bind(660.0, 0.22))

func _setup_mix_sliders() -> void:
	for bus_name in MIX_BUSES:
		var slider: HSlider = mix_sliders[bus_name]
		slider.value = mix_levels[bus_name]
		Sound.set_bus_volume_linear(bus_name, mix_levels[bus_name])
		_update_mix_pct_label(bus_name)
		slider.value_changed.connect(_on_mix_slider_changed.bind(bus_name))

func _on_mix_slider_changed(value: float, bus_name: String) -> void:
	mix_levels[bus_name] = value
	Sound.set_bus_volume_linear(bus_name, value)
	_update_mix_pct_label(bus_name)
	_save_progress()

func _update_mix_pct_label(bus_name: String) -> void:
	var label: Label = mix_pct_labels[bus_name]
	label.text = "%d%%" % round(mix_levels[bus_name] * 100.0)

func _on_reduce_motion_toggled(is_on: bool) -> void:
	reduce_motion = is_on
	Sound.play_ui_tick()
	_save_progress()

func _on_settings_tab_changed(_tab: int) -> void:
	Sound.play_ui_tick()

func _on_help_button_pressed() -> void:
	_show_onboarding()

func _show_onboarding() -> void:
	onboarding_step = 0
	_refresh_onboarding_step()
	onboarding_panel.visible = true

func _refresh_onboarding_step() -> void:
	var step: Dictionary = ONBOARDING_STEPS[onboarding_step]
	onboarding_step_label.text = "Step %d / %d" % [onboarding_step + 1, ONBOARDING_STEPS.size()]
	onboarding_title_label.text = step["title"]
	onboarding_body_label.text = step["body"]
	var is_last := onboarding_step == ONBOARDING_STEPS.size() - 1
	onboarding_next_button.text = "Start Playing" if is_last else "Next"

func _on_onboarding_next_pressed() -> void:
	if onboarding_step == ONBOARDING_STEPS.size() - 1:
		_on_onboarding_close_pressed()
		return
	onboarding_step += 1
	_refresh_onboarding_step()

func _on_onboarding_close_pressed() -> void:
	onboarding_panel.visible = false
	if not onboarding_seen:
		onboarding_seen = true
		_save_progress()

func _input(event: InputEvent) -> void:
	if cheat_all_unlocked:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var ch := char(event.unicode).to_lower()
	if ch.length() != 1 or ch < "a" or ch > "z":
		return
	_typed_buffer += ch
	if _typed_buffer.length() > EASTER_EGG_CODE.length():
		_typed_buffer = _typed_buffer.substr(_typed_buffer.length() - EASTER_EGG_CODE.length())
	if _typed_buffer == EASTER_EGG_CODE:
		_trigger_easter_egg()

func _trigger_easter_egg() -> void:
	cheat_all_unlocked = true
	_save_progress()
	_flash_screen(Color(1, 0.85, 0.3, 0.5))
	_screen_shake(6.0, 0.3)
	_show_toast("* Hubert Mode: Everything Unlocked! *")
	_play_unlock_fanfare()
	if settings_panel.visible:
		_on_settings_button_pressed()

func _play_unlock_fanfare() -> void:
	var scale: Dictionary = SCALES[current_scale_index]
	for freq in scale["tones"]:
		Sound.play_tone(freq, 0.4)
		await get_tree().create_timer(0.06).timeout

func _show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 160.0
	label.offset_bottom = 200.0
	label.modulate.a = 0.0
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.8)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)

func _build_pads() -> void:
	for i in PAD_COUNT:
		var angle_deg := -90.0 + i * (360.0 / PAD_COUNT)
		var angle_rad := deg_to_rad(angle_deg)
		var dir := Vector2(cos(angle_rad), sin(angle_rad))
		var slot_position := RING_CENTER + dir * BASE_RADIUS - Vector2(PAD_WIDTH / 2.0, 0.0)
		var slot_rotation := angle_deg - 90.0
		pad_slots.append({"position": slot_position, "rotation": slot_rotation, "dir": dir})
		var pad := SimonButton.new()
		pad.pad_name = "pad_%d" % i
		pad.custom_minimum_size = Vector2(PAD_WIDTH, PAD_HEIGHT)
		pad.size = Vector2(PAD_WIDTH, PAD_HEIGHT)
		pad.pivot_offset = Vector2(PAD_WIDTH / 2.0, 0.0)
		pad.rotation_degrees = slot_rotation
		pad.position = slot_position
		pad.focus_mode = Control.FOCUS_NONE
		pad.disabled = true
		pad_ring.add_child(pad)
		pads_by_name[pad.pad_name] = pad
		pad_names.append(pad.pad_name)
		pad_slot_order.append(pad.pad_name)
		pad.pressed.connect(_on_pad_pressed.bind(pad.pad_name))

		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(44, 28)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad_ring.add_child(label)
		note_labels[pad.pad_name] = label
		_position_label(pad.pad_name, dir)
	_apply_scale_and_palette()

func _position_label(pad_name: String, dir: Vector2) -> void:
	var label: Label = note_labels[pad_name]
	var center := RING_CENTER + dir * (BASE_RADIUS + PAD_HEIGHT * 0.55)
	label.position = center - label.size / 2.0

func _reshuffle_pad_positions() -> void:
	pad_slot_order.shuffle()
	for i in PAD_COUNT:
		var slot: Dictionary = pad_slots[i]
		var pad: SimonButton = pads_by_name[pad_slot_order[i]]
		pad.position = slot["position"]
		pad.rotation_degrees = slot["rotation"]
		_position_label(pad_slot_order[i], slot["dir"])

func _reset_pad_positions() -> void:
	pad_slot_order = pad_names.duplicate()
	for i in PAD_COUNT:
		var slot: Dictionary = pad_slots[i]
		var pad: SimonButton = pads_by_name[pad_slot_order[i]]
		pad.position = slot["position"]
		pad.rotation_degrees = slot["rotation"]
		_position_label(pad_slot_order[i], slot["dir"])

func _pad_hue(i: int, palette: Dictionary) -> float:
	if palette["wrap"]:
		return palette["hue_start"] + float(i) / PAD_COUNT * (palette["hue_end"] - palette["hue_start"])
	return lerp(float(palette["hue_start"]), float(palette["hue_end"]), float(i) / float(PAD_COUNT - 1))

func _apply_scale_and_palette() -> void:
	var scale: Dictionary = SCALES[current_scale_index]
	var palette: Dictionary = THEMES[current_theme_index].get("pad_style", PALETTES[current_palette_index])
	var is_shader_palette: bool = palette.has("shader")
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	for i in PAD_COUNT:
		var degree: int = ring_order[i]
		var pad: SimonButton = pads_by_name[pad_names[i]]
		pad.tone_freq = scale["tones"][degree]
		note_labels[pad_names[i]].text = scale["notes"][degree]
		if is_shader_palette:
			pad.base_color = palette["accent_color"]
			pad.lit_color = (palette["accent_color"] as Color).lightened(0.4)
			pad.set_shader_skin(load(palette["shader"]), float(i) * 1.37 + randf() * 0.5)
		elif palette.has("colors"):
			pad.clear_shader_skin()
			pad.base_color = palette["colors"][i]
			pad.lit_color = (palette["colors"][i] as Color).lightened(0.35)
		else:
			pad.clear_shader_skin()
			var hue := _pad_hue(i, palette)
			pad.base_color = Color.from_hsv(hue, palette["sat"], palette["val"])
			pad.lit_color = Color.from_hsv(hue, palette["lit_sat"], palette["lit_val"])
		pad.refresh()
		_apply_label_contrast(note_labels[pad_names[i]], pad.base_color, pad.lit_color)

# Picks black-or-white note-label text (with a matching soft shadow) by
# whichever contrasts better against BOTH the pad's resting and lit color -
# many of the newer mid-tone palettes read poorly with fixed white text,
# especially once lightened() brightens them further on a hit.
func _apply_label_contrast(label: Label, base_color: Color, lit_color: Color) -> void:
	var white := Color(0.95, 0.95, 0.95, 0.95)
	var black := Color(0.06, 0.06, 0.08, 0.95)
	var white_worst: float = min(_contrast_ratio(white, base_color), _contrast_ratio(white, lit_color))
	var black_worst: float = min(_contrast_ratio(black, base_color), _contrast_ratio(black, lit_color))
	var text_color := white if white_worst >= black_worst else black
	var is_light_text := text_color == white
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6) if is_light_text else Color(1, 1, 1, 0.55))

func _color_luminance(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

func _contrast_ratio(a: Color, b: Color) -> float:
	var la := _color_luminance(a)
	var lb := _color_luminance(b)
	var lighter: float = max(la, lb)
	var darker: float = min(la, lb)
	return (lighter + 0.05) / (darker + 0.05)

func _apply_theme() -> void:
	var theme_data: Dictionary = THEMES[current_theme_index]
	theme = _build_ui_theme(theme_data)

	var accent: Color = theme_data["accent"]
	for stat_label in [best_score_label, best_round_label, best_combo_label]:
		stat_label.add_theme_color_override("font_color", accent)
	for bus_name in MIX_BUSES:
		(mix_pct_labels[bus_name] as Label).add_theme_color_override("font_color", accent)

	# The background shader (full-viewport, same cost as a pad's but at much
	# higher resolution) was a major contributor to Web-only audio/frame
	# stutter - dropped in favor of a flat fill. The pad_style shader skin
	# (much smaller per-instance area) stays, so themes like Cosmic &
	# Atmospheric keep their shader look on the pads themselves.
	background_rect.material = null
	background_rect.color = theme_data.get("background_color", theme_data["bg"])

	var settings_bg_sb := StyleBoxFlat.new()
	settings_bg_sb.bg_color = theme_data["panel"]
	settings_bg_sb.border_color = theme_data["border"]
	settings_bg_sb.set_border_width_all(1)
	settings_bg_sb.set_corner_radius_all(14)
	settings_bg_sb.shadow_color = Color(0, 0, 0, 0.4)
	settings_bg_sb.shadow_size = 12
	settings_panel_bg.add_theme_stylebox_override("panel", settings_bg_sb)

	var resonator_color: Color = theme_data.get("resonator_color", theme_data["panel"])
	var resonator_sb := StyleBoxFlat.new()
	resonator_sb.bg_color = resonator_color
	resonator_sb.corner_radius_top_left = 80
	resonator_sb.corner_radius_top_right = 80
	resonator_sb.corner_radius_bottom_right = 80
	resonator_sb.corner_radius_bottom_left = 80
	resonator_sb.border_color = theme_data["border"]
	resonator_sb.set_border_width_all(1)
	resonator_sb.shadow_color = Color(0, 0, 0, 0.35)
	resonator_sb.shadow_size = 10
	resonator_panel.add_theme_stylebox_override("panel", resonator_sb)

# Builds a full Godot Theme resource from a THEMES entry's 7 chrome colors and
# assigns it to the whole scene tree via the root Control's `theme` property
# (Godot cascades it to every descendant; per-node color overrides elsewhere -
# e.g. the gold combo/best-callout labels - still win over this).
func _build_ui_theme(theme_data: Dictionary) -> Theme:
	var panel_color: Color = theme_data["panel"]
	var border_color: Color = theme_data["border"]
	var text_color: Color = theme_data["text"]
	var text_muted_color: Color = theme_data["text_muted"]
	var accent_color: Color = theme_data["accent"]

	var ui_theme := Theme.new()

	ui_theme.set_color("font_color", "Label", text_color)
	ui_theme.set_color("font_color", "Button", text_color)
	ui_theme.set_color("font_hover_color", "Button", accent_color)
	ui_theme.set_color("font_pressed_color", "Button", accent_color)
	ui_theme.set_color("font_focus_color", "Button", text_color)
	ui_theme.set_color("font_disabled_color", "Button", text_muted_color)
	ui_theme.set_color("font_color", "CheckBox", text_color)
	ui_theme.set_color("font_hover_color", "CheckBox", accent_color)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = panel_color
	normal_sb.border_color = border_color
	normal_sb.set_border_width_all(1)
	normal_sb.set_corner_radius_all(8)
	normal_sb.content_margin_left = 10
	normal_sb.content_margin_right = 10
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6

	var hover_sb: StyleBoxFlat = normal_sb.duplicate()
	hover_sb.bg_color = panel_color.lightened(0.1)
	hover_sb.border_color = accent_color

	var pressed_sb: StyleBoxFlat = normal_sb.duplicate()
	pressed_sb.bg_color = accent_color.darkened(0.15)
	pressed_sb.border_color = accent_color

	var disabled_sb: StyleBoxFlat = normal_sb.duplicate()
	disabled_sb.bg_color = panel_color.darkened(0.15)
	disabled_sb.border_color = border_color.darkened(0.2)

	var focus_sb: StyleBoxFlat = normal_sb.duplicate()
	focus_sb.border_color = accent_color
	focus_sb.set_border_width_all(2)

	ui_theme.set_stylebox("normal", "Button", normal_sb)
	ui_theme.set_stylebox("hover", "Button", hover_sb)
	ui_theme.set_stylebox("pressed", "Button", pressed_sb)
	ui_theme.set_stylebox("disabled", "Button", disabled_sb)
	ui_theme.set_stylebox("focus", "Button", focus_sb)

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = panel_color
	panel_sb.border_color = border_color
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(14)
	ui_theme.set_stylebox("panel", "PanelContainer", panel_sb)

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = border_color
	slider_track.set_corner_radius_all(6)
	ui_theme.set_stylebox("slider", "HSlider", slider_track)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = accent_color
	slider_fill.set_corner_radius_all(6)
	ui_theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	var tab_selected_sb := StyleBoxFlat.new()
	tab_selected_sb.bg_color = Color(accent_color, 0.16)
	tab_selected_sb.border_color = accent_color
	tab_selected_sb.border_width_bottom = 2
	tab_selected_sb.content_margin_left = 12
	tab_selected_sb.content_margin_right = 12
	tab_selected_sb.content_margin_top = 8
	tab_selected_sb.content_margin_bottom = 8
	var tab_unselected_sb: StyleBoxFlat = tab_selected_sb.duplicate()
	tab_unselected_sb.bg_color = Color.TRANSPARENT
	tab_unselected_sb.border_color = Color.TRANSPARENT
	ui_theme.set_stylebox("tab_selected", "TabContainer", tab_selected_sb)
	ui_theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected_sb)
	ui_theme.set_stylebox("tab_hovered", "TabContainer", tab_unselected_sb)
	ui_theme.set_stylebox("tab_disabled", "TabContainer", tab_unselected_sb)
	ui_theme.set_color("font_selected_color", "TabContainer", accent_color)
	ui_theme.set_color("font_unselected_color", "TabContainer", text_muted_color)
	ui_theme.set_color("font_hovered_color", "TabContainer", text_color)

	return ui_theme

func _meets_requirement(req: Dictionary) -> bool:
	match req["type"]:
		"round":
			return best_round >= int(req["value"])
		"score":
			return best_score >= int(req["value"])
		"combo":
			return best_combo >= int(req["value"])
	return true

func _is_unlocked(entry: Dictionary) -> bool:
	if cheat_all_unlocked:
		return true
	if not entry.has("unlock"):
		return true
	return _meets_requirement(entry["unlock"])

func _requirement_text(req: Dictionary) -> String:
	match req["type"]:
		"round":
			return "Reach Round %d" % int(req["value"])
		"score":
			return "Score %d" % int(req["value"])
		"combo":
			return "Combo x%d" % int(req["value"])
	return ""

func _on_settings_button_pressed() -> void:
	_refresh_settings_content()
	if settings_panel.visible:
		return
	await _slide_in_panel(settings_panel, settings_scroll, Vector2(70, 0))

func _refresh_settings_content() -> void:
	settings_confirm_row.visible = false
	settings_reset_button.visible = true
	best_score_label.text = str(best_score)
	best_round_label.text = str(best_round)
	best_combo_label.text = str(best_combo)
	var accent: Color = THEMES[current_theme_index]["accent"]
	var accent_text: Color = THEMES[current_theme_index].get("accent_text", Color.BLACK)
	var border: Color = THEMES[current_theme_index]["border"]
	for i in scale_buttons.size():
		var unlocked := _is_unlocked(SCALES[i])
		var active := unlocked and i == current_scale_index
		scale_buttons[i].disabled = not unlocked
		scale_card_notes_rows[i].visible = unlocked
		scale_card_unlock_labels[i].visible = not unlocked
		_style_pick_badge(scale_card_badges[i], active, not unlocked, accent, accent_text)
		_style_pick_card(scale_buttons[i], active, not unlocked, accent, border, 10)
	# Only Premium & Minimal leaves the pad palette to the player - every other
	# theme carries its own fixed pad_style, so the palette picker only makes
	# sense (and only appears) while Premium & Minimal is active.
	palette_section.visible = current_theme_index == 0
	for i in palette_buttons.size():
		var unlocked := _is_unlocked(PALETTES[i])
		var active := unlocked and i == current_palette_index and current_theme_index == 0
		palette_buttons[i].disabled = not unlocked
		palette_card_unlock_labels[i].visible = not unlocked
		_style_pick_badge(palette_card_badges[i], active, not unlocked, accent, accent_text)
		_style_pick_card(palette_buttons[i], active, not unlocked, accent, border, 8)
	for i in theme_buttons.size():
		var unlocked := _is_unlocked(THEMES[i])
		var active := unlocked and i == current_theme_index
		theme_buttons[i].disabled = not unlocked
		theme_card_unlock_labels[i].visible = not unlocked
		_style_pick_badge(theme_card_badges[i], active, not unlocked, accent, accent_text)
		_style_pick_card(theme_buttons[i], active, not unlocked, accent, border, 10)

func _on_settings_close_pressed() -> void:
	await _slide_out_panel(settings_panel, settings_scroll, Vector2(70, 0))

# Quick slide-in/out from the edge, used for panel open/close transitions.
func _slide_in_panel(panel: Control, content: Control, offset: Vector2, duration := 0.22) -> void:
	panel.visible = true
	content.modulate.a = 0.0
	await get_tree().process_frame
	var target := content.position
	content.position = target + offset
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(content, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(content, "modulate:a", 1.0, duration)
	await t.finished

func _slide_out_panel(panel: Control, content: Control, offset: Vector2, duration := 0.18) -> void:
	var start := content.position
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(content, "position", start + offset, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(content, "modulate:a", 0.0, duration)
	await t.finished
	panel.visible = false
	content.position = start
	content.modulate.a = 1.0

func _on_scale_button_pressed(index: int) -> void:
	if not _is_unlocked(SCALES[index]):
		return
	current_scale_index = index
	_apply_scale_and_palette()
	_on_settings_button_pressed()

func _on_palette_button_pressed(index: int) -> void:
	if not _is_unlocked(PALETTES[index]):
		return
	current_palette_index = index
	_apply_scale_and_palette()
	_save_progress()
	_on_settings_button_pressed()

func _on_theme_button_pressed(index: int) -> void:
	if not _is_unlocked(THEMES[index]):
		return
	current_theme_index = index
	_apply_theme()
	_apply_scale_and_palette()
	_save_progress()
	_on_settings_button_pressed()

func _on_reset_ask_pressed() -> void:
	settings_reset_button.visible = false
	settings_confirm_row.visible = true

func _on_reset_cancel_pressed() -> void:
	settings_confirm_row.visible = false
	settings_reset_button.visible = true

func _on_reset_progress_pressed() -> void:
	best_score = 0
	best_round = 0
	best_combo = 0
	cheat_all_unlocked = false
	current_scale_index = 0
	current_palette_index = 0
	current_theme_index = 0
	_save_progress()
	_apply_theme()
	_apply_scale_and_palette()
	settings_confirm_row.visible = false
	settings_reset_button.visible = true
	_on_settings_button_pressed()
	_show_toast("Progress Reset")

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	best_score = int(data.get("best_score", 0))
	best_round = int(data.get("best_round", 0))
	best_combo = int(data.get("best_combo", 0))
	cheat_all_unlocked = bool(data.get("cheat_all_unlocked", false))
	onboarding_seen = bool(data.get("onboarding_seen", false))
	# Selected-id persistence for Palette and Theme (Theme mirrors Palette's
	# schema per GAME_DESIGN.md 1.1/open-items: no separate "unlocked set" is
	# stored for either - unlock state is derived fresh from best_round/
	# best_score/best_combo via _is_unlocked()/_meets_requirement() every load,
	# same as Scales - only the player's *selected* index is persisted here.
	# Falls back to 0 (the always-unlocked default entry) if the saved index
	# is out of range or points at something no longer unlocked (e.g. after a
	# Reset Progress on a different save, or a shortened array), so a corrupt
	# or stale save can never select a locked/nonexistent entry on load.
	var saved_palette_index := int(data.get("current_palette_index", 0))
	if saved_palette_index >= 0 and saved_palette_index < PALETTES.size() and _is_unlocked(PALETTES[saved_palette_index]):
		current_palette_index = saved_palette_index
	var saved_theme_index := int(data.get("current_theme_index", 0))
	if saved_theme_index >= 0 and saved_theme_index < THEMES.size() and _is_unlocked(THEMES[saved_theme_index]):
		current_theme_index = saved_theme_index
	var saved_mix: Variant = data.get("mix_levels", {})
	if typeof(saved_mix) == TYPE_DICTIONARY:
		for bus_name in MIX_BUSES:
			mix_levels[bus_name] = float(saved_mix.get(bus_name, MIX_DEFAULTS[bus_name]))
	reduce_motion = bool(data.get("reduce_motion", false))

func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"best_score": best_score,
		"best_round": best_round,
		"best_combo": best_combo,
		"cheat_all_unlocked": cheat_all_unlocked,
		"onboarding_seen": onboarding_seen,
		"mix_levels": mix_levels,
		"reduce_motion": reduce_motion,
		"current_palette_index": current_palette_index,
		"current_theme_index": current_theme_index,
	}))

func _register_best(round_reached: int, current_score: int, current_combo: int) -> void:
	var prev_round := best_round
	var prev_score := best_score
	var prev_combo := best_combo
	var improved := false
	if round_reached > best_round:
		best_round = round_reached
		improved = true
	if current_score > best_score:
		best_score = current_score
		improved = true
	if current_combo > best_combo:
		best_combo = current_combo
		improved = true
	if improved:
		_save_progress()
		if not cheat_all_unlocked:
			_check_new_unlocks(prev_round, prev_score, prev_combo)

func _meets_requirement_values(req: Dictionary, round_val: int, score_val: int, combo_val: int) -> bool:
	match req["type"]:
		"round":
			return round_val >= int(req["value"])
		"score":
			return score_val >= int(req["value"])
		"combo":
			return combo_val >= int(req["value"])
	return true

func _check_new_unlocks(prev_round: int, prev_score: int, prev_combo: int) -> void:
	# Accumulated silently during play - surfaced once on the end-of-run
	# summary rather than as a mid-run interruption (was too jarring).
	for entry in SCALES + PALETTES + THEMES:
		if not entry.has("unlock"):
			continue
		var req: Dictionary = entry["unlock"]
		var was_met := _meets_requirement_values(req, prev_round, prev_score, prev_combo)
		if _meets_requirement(req) and not was_met:
			run_new_unlocks.append(entry)

func _on_zen_button_pressed() -> void:
	await _cross_fade_mode_switch(func():
		zen_mode = true
		_reset_pad_positions()
		start_button.visible = false
		chaos_button.visible = false
		zen_button.visible = false
		music_button.visible = false
		duet_button.visible = false
		round_label.visible = false
		combo_label.visible = false
		score_label.visible = false
		cash_out_button.visible = false
		zen_bar.visible = true
		settings_button.disabled = false
		_set_pads_disabled(false)
	)

func _on_exit_zen_pressed() -> void:
	await _cross_fade_mode_switch(func():
		zen_mode = false
		start_button.visible = true
		chaos_button.visible = true
		zen_button.visible = true
		music_button.visible = true
		duet_button.visible = true
		round_label.visible = true
		combo_label.visible = true
		score_label.visible = true
		zen_bar.visible = false
		round_label.text = "Round: 0"
		score_label.text = "Score: 0"
		start_button.disabled = false
		chaos_button.disabled = false
		zen_button.disabled = false
		music_button.disabled = false
		duet_button.disabled = false
		settings_button.disabled = false
		_set_pads_disabled(true)
	)

func _on_music_button_pressed() -> void:
	await _cross_fade_mode_switch(func():
		music_mode = true
		_reset_pad_positions()
		start_button.visible = false
		chaos_button.visible = false
		zen_button.visible = false
		music_button.visible = false
		duet_button.visible = false
		round_label.visible = false
		combo_label.visible = false
		score_label.visible = false
		cash_out_button.visible = false
		music_bar.visible = true
		settings_button.disabled = false
		_set_pads_disabled(true)
	)
	_music_loop()

func _on_exit_music_pressed() -> void:
	await _cross_fade_mode_switch(func():
		music_mode = false
		start_button.visible = true
		chaos_button.visible = true
		zen_button.visible = true
		music_button.visible = true
		duet_button.visible = true
		round_label.visible = true
		combo_label.visible = true
		score_label.visible = true
		music_bar.visible = false
		round_label.text = "Round: 0"
		score_label.text = "Score: 0"
		start_button.disabled = false
		chaos_button.disabled = false
		zen_button.disabled = false
		music_button.disabled = false
		duet_button.disabled = false
		settings_button.disabled = false
		_set_pads_disabled(true)
	)

# Euclidean rhythm (Bjorklund's algorithm): distributes `pulses` onsets as
# evenly as possible across `steps`, e.g. E(3,8) -> 10010010. Standard
# "fill two bucket lists, repeatedly fold the shorter into the longer"
# construction.
func _euclidean_rhythm(pulses: int, steps: int) -> Array[bool]:
	if pulses <= 0:
		var empty: Array[bool] = []
		empty.resize(steps)
		empty.fill(false)
		return empty
	if pulses >= steps:
		var full: Array[bool] = []
		full.resize(steps)
		full.fill(true)
		return full
	var a: Array = []
	for i in pulses:
		a.append([true])
	var b: Array = []
	for i in steps - pulses:
		b.append([false])
	while b.size() > 1:
		var m: int = min(a.size(), b.size())
		var new_a: Array = []
		for i in m:
			new_a.append(a[i] + b[i])
		var remainder_a: Array = a.slice(m)
		var remainder_b: Array = b.slice(m)
		a = new_a
		b = remainder_a if not remainder_a.is_empty() else remainder_b
	var flat: Array[bool] = []
	for group in a:
		for v in group:
			flat.append(v)
	for group in b:
		for v in group:
			flat.append(v)
	return flat

# One bar's worth of onsets for a Music Mode phrase - pulse count re-rolled
# each call so successive bars don't feel mechanically identical.
func _generate_music_rhythm() -> Array[bool]:
	var pulses := randi_range(MUSIC_PULSES_MIN, MUSIC_PULSES_MAX)
	return _euclidean_rhythm(pulses, MUSIC_RHYTHM_STEPS)

# Reflecting boundary (Xenakis's random-walk barrier technique - see
# docs/music-mode.md): an out-of-range step bounces back into range by the
# amount it overshot, rather than clamping to the edge value. Clamping was
# forcing the walk to deterministically pick a single "safe" direction
# whenever it stood on an edge with no established direction yet (e.g. every
# game's opening note, always the tonic), which killed melodic variety right
# where it mattered most. Reflection keeps direction fully random and still
# guarantees real movement.
func _reflect_degree(raw_target: int) -> int:
	var reflected := raw_target
	if reflected < 0:
		reflected = -reflected
	elif reflected > PAD_COUNT - 1:
		reflected = (PAD_COUNT - 1) * 2 - reflected
	return clampi(reflected, 0, PAD_COUNT - 1)

func _music_reset_walk() -> void:
	# Random starting degree, not always the tonic - so each Music/Duet
	# session opens differently rather than sounding like the same song
	# restarting (mid-session phrase resolution still lands on the tonic
	# every MUSIC_PHRASE_BARS bars, same as before).
	_music_current_degree = randi() % PAD_COUNT
	_music_last_direction = 0
	_music_last_was_leap = false
	_music_bar_index = 0
	_music_repeat_streak = 1

# Biased random walk step: mostly stepwise motion, some repeats, occasional
# leaps. Direction follows two documented melodic tendencies (Huron, "Sweet
# Anticipation"; Narmour's implication-realization model) rather than an
# arbitrary streak-count rule:
# - step inertia: a stepwise move tends to be followed by another step in
#   the same direction, not a reversal.
# - post-skip reversal: a leap tends to be followed by stepwise motion back
#   the other way, "filling the gap" it just opened.
func _music_next_delta(max_leap: int) -> int:
	var repeat_chance: float = BASE_REPEAT_CHANCE * pow(REPEAT_DECAY, float(_music_repeat_streak - 1))
	var step_chance := (1.0 - repeat_chance) * STEP_TO_NON_REPEAT_RATIO
	var r := randf()
	var magnitude: int
	if r < repeat_chance:
		magnitude = 0
	elif r < repeat_chance + step_chance:
		magnitude = 1
	else:
		magnitude = randi_range(2, max_leap)
	if magnitude == 0:
		_music_last_was_leap = false
		return 0
	var direction: int
	if _music_last_was_leap and _music_last_direction != 0:
		direction = -_music_last_direction
		magnitude = 1
	elif _music_last_direction != 0 and magnitude == 1:
		direction = _music_last_direction if randf() < 0.70 else -_music_last_direction
	else:
		direction = 1 if randf() < 0.5 else -1
	_music_last_direction = direction
	_music_last_was_leap = magnitude >= 2
	return direction * magnitude

# One bar's worth of scale degrees (0-7), one per rhythm pulse. Walk starts
# at the tonic and is forced back to it on the last note of every
# MUSIC_PHRASE_BARS-th bar, so phrases have a clear landing point.
func _generate_music_bar_melody(pulse_count: int) -> Array[int]:
	if pulse_count <= 0:
		return []
	var scale: Dictionary = SCALES[current_scale_index]
	var is_narrow: bool = MUSIC_NARROW_LEAP_SCALES.has(scale["id"])
	var max_leap := MUSIC_NARROW_MAX_LEAP if is_narrow else MUSIC_PENTATONIC_MAX_LEAP
	var degrees: Array[int] = []
	for i in pulse_count:
		var degree := _music_current_degree
		degrees.append(degree)
		var delta := _music_next_delta(max_leap)
		var raw_target := degree + delta
		var new_degree := _reflect_degree(raw_target)
		if new_degree != raw_target and delta != 0:
			# Bounced off the scale's edge - flip the stored direction so
			# step inertia continues in the direction the walk actually
			# reflected toward, not the blocked one.
			_music_last_direction = -_music_last_direction
		if new_degree == degree:
			_music_repeat_streak += 1
		else:
			_music_repeat_streak = 1
		_music_current_degree = new_degree
	_music_bar_index += 1
	if _music_bar_index % MUSIC_PHRASE_BARS == 0:
		degrees[degrees.size() - 1] = 0
		_music_current_degree = 0
		_music_last_direction = 0
	return degrees

# Looks up the pad currently tuned to a scale degree, per the ring_order
# mapping _apply_scale_and_palette() already maintains - stays correct
# across scale changes without any Music-Mode-specific retuning logic.
func _music_pad_for_degree(degree: int) -> SimonButton:
	var scale: Dictionary = SCALES[current_scale_index]
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	var ring_pos: int = ring_order.find(degree)
	if ring_pos == -1:
		return null
	return pads_by_name[pad_names[ring_pos]]

# Drives Music Mode: generates one Euclidean-rhythm bar + melody phrase at a
# time and plays it, looping until the player exits. Tempo is fixed for the
# whole session; scale/theme changes take effect on the next note lookup
# automatically, so no explicit "retune" step is needed.
func _music_loop() -> void:
	_music_reset_walk()
	var bpm := randf_range(MUSIC_BPM_MIN, MUSIC_BPM_MAX)
	var step_duration := 60.0 / bpm / 4.0
	var flash_duration: float = min(step_duration * MUSIC_FLASH_FRACTION, MUSIC_FLASH_MAX)
	while music_mode:
		var rhythm := _generate_music_rhythm()
		var pulse_count := 0
		for on in rhythm:
			if on:
				pulse_count += 1
		var melody := _generate_music_bar_melody(pulse_count)
		var note_i := 0
		for step_index in rhythm.size():
			if not music_mode:
				return
			if rhythm[step_index]:
				var pad := _music_pad_for_degree(melody[note_i])
				note_i += 1
				var is_downbeat := step_index == 0
				var decay := MUSIC_ACCENT_DECAY if is_downbeat else MUSIC_DECAY_RATE
				var volume := MUSIC_ACCENT_VOLUME if is_downbeat else MUSIC_VOLUME
				if pad:
					await pad.flash(flash_duration, decay, volume)
				var remaining := step_duration - flash_duration
				if remaining > 0.0:
					await get_tree().create_timer(remaining).timeout
			else:
				await get_tree().create_timer(step_duration).timeout

# Full-screen cross-fade for a mode switch that swaps the whole UI layout
# (currently Zen entry/exit) - covers the abrupt visibility toggle.
func _cross_fade_mode_switch(apply_state: Callable) -> void:
	var t := create_tween()
	t.tween_property(flash_overlay, "color", Color(0.05, 0.05, 0.07, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	apply_state.call()
	var t2 := create_tween()
	t2.tween_property(flash_overlay, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t2.finished

func _on_start_pressed(mode: String) -> void:
	run_start_best_score = best_score
	run_start_best_round = best_round
	run_start_best_combo = best_combo
	run_new_unlocks.clear()
	chaos_mode = mode == "chaos"
	duet_mode = mode == "duet"
	duet_round = 0
	if duet_mode:
		_music_reset_walk()
	elif not chaos_mode:
		_normal_reset_walk()
	if not chaos_mode:
		_reset_pad_positions()
	sequence.clear()
	gold_indices.clear()
	player_index = 0
	score = 0
	combo = 0
	combo_growth = 0.1
	mistake_charges = 0
	golden_step_count = 0
	sequence_speed_multiplier = 1.0
	score_bonus_percent = 0.0
	modifier_stacks.clear()
	waves_completed = 0
	duet_wave_round = 0
	total_round = 0
	unbanked_points = 0
	_update_score_labels()
	start_button.disabled = true
	chaos_button.disabled = true
	start_button.text = "Normal Mode"
	chaos_button.text = "Chaos Mode"
	duet_button.text = "Duet Mode"
	settings_button.disabled = true
	zen_button.disabled = true
	music_button.disabled = true
	duet_button.disabled = true
	cash_out_button.visible = true
	_next_round()

func _current_round() -> int:
	return duet_round if duet_mode else total_round

# Current streak length since the last cash out - the quantity the cash-out
# bonus scales off of. Sequence length for Normal/Chaos (cumulative); Duet's
# own wave-local round counter for Duet (its phrase isn't cumulative).
func _current_wave_length() -> int:
	return duet_wave_round if duet_mode else sequence.size()

# The streak-length bonus only - additional on top of `unbanked_points`,
# which already holds the streak's real per-hit score. Includes
# score_bonus_percent (Resonance) alongside the combo-growth multiplier
# (Sharper Ear) - both are "current score multiplier" effects, and both
# should compound into cash-outs, not just per-hit score. This was a real
# gap found in a modifier audit: Resonance's bonus previously only reached
# `unbanked_points` (via `_register_hit`), never the streak bonus itself.
func _cash_out_streak_bonus() -> int:
	var s := _current_wave_length()
	var multiplier := (1.0 + float(combo - 1) * combo_growth) * (1.0 + score_bonus_percent)
	return int(round(CASHOUT_QUADRATIC_K * float(s) * float(s) * multiplier))

# Total the player would bank right now: this streak's real per-hit points
# (`unbanked_points`) plus the streak-length bonus.
func _cash_out_total() -> int:
	return unbanked_points + _cash_out_streak_bonus()

# Player-triggered cash out ("kaching"): banks `unbanked_points` plus the
# streak bonus into real `score`, then resets the streak (sequence
# truncated to 0 notes for Normal/Chaos, `duet_wave_round` zeroed for Duet)
# while combo/combo_growth and all modifiers persist untouched.
func _on_cash_out_button_pressed() -> void:
	if zen_mode or music_mode or not accepting_input:
		return
	var total := _cash_out_total()
	if total <= 0:
		return
	score += total
	unbanked_points = 0
	waves_completed += 1
	accepting_input = false
	_set_pads_disabled(true)
	if duet_mode:
		duet_wave_round = 0
	else:
		sequence = sequence.slice(0, min(WAVE_RESET_LENGTH, sequence.size()))
	_update_score_labels()
	_punch(score_label)
	_spawn_score_popup(cash_out_button.global_position + cash_out_button.size / 2.0, "+%d" % total, Color(1, 0.85, 0.3))
	_flash_screen(Color(1, 0.85, 0.3, 0.22))
	_next_round()

func _next_round() -> void:
	accepting_input = false
	_set_pads_disabled(true)
	if chaos_mode:
		_reshuffle_pad_positions()
	if duet_mode:
		duet_round += 1
		duet_wave_round += 1
		_generate_duet_phrase()
	elif chaos_mode:
		sequence.append(pad_names[randi() % pad_names.size()])
		total_round += 1
	else:
		sequence.append(_normal_next_pad_name())
		total_round += 1
	var round_prefix := "Chaos - " if chaos_mode else ("Duet - " if duet_mode else "")
	var wave_suffix := "  (Streak %d)" % _current_wave_length()
	round_label.text = (round_prefix + "Round: %d") % _current_round() + wave_suffix
	_roll_gold_indices()
	await _play_sequence()
	if duet_mode:
		await _run_duet_response()
		return
	player_index = 0
	accepting_input = true
	_set_pads_disabled(false)

# One bar's call phrase for Duet Mode - reuses Music Mode's rhythm/melody
# generators (see docs/music-mode.md) rather than Normal/Chaos's uniform
# random note. Not cumulative like `sequence` normally is: each round is a
# fresh phrase, since Duet's challenge is timing/note precision per phrase,
# not memorizing an ever-growing sequence (that's Normal Mode's job).
func _generate_duet_phrase() -> void:
	var bpm_lo := minf(DUET_BPM_BASE_MIN + float(duet_wave_round) * DUET_BPM_RAMP_PER_ROUND, DUET_BPM_CAP - 10.0)
	var bpm_hi := minf(DUET_BPM_BASE_MAX + float(duet_wave_round) * DUET_BPM_RAMP_PER_ROUND, DUET_BPM_CAP)
	var bpm := randf_range(bpm_lo, bpm_hi)
	duet_step_duration = 60.0 / bpm / 4.0
	var pulses_lo := clampi(1 + duet_wave_round, 2, MUSIC_PULSES_MIN)
	var pulses_hi := clampi(2 + duet_wave_round, 3, MUSIC_PULSES_MAX)
	duet_rhythm = _euclidean_rhythm(randi_range(pulses_lo, pulses_hi), MUSIC_RHYTHM_STEPS)
	var pulse_count := 0
	duet_pulse_times.clear()
	var t := 0.0
	for on in duet_rhythm:
		if on:
			pulse_count += 1
			duet_pulse_times.append(t)
		t += duet_step_duration
	var melody := _generate_music_bar_melody(pulse_count)
	sequence.clear()
	for degree in melody:
		var pad := _music_pad_for_degree(degree)
		sequence.append(pad.pad_name if pad else pad_names[0])

func _normal_reset_walk() -> void:
	# Unlike Music/Duet's phrases, which always open on the tonic, Normal
	# Mode's run is the only "opening note" a player hears repeatedly across
	# many runs - starting it on a random degree keeps that moment from
	# feeling identical every time. Mid-run phrase resolution (every
	# NORMAL_PHRASE_LENGTH notes) still lands on the tonic, same as Music/Duet.
	_normal_current_degree = randi() % PAD_COUNT
	_normal_last_direction = 0
	_normal_last_was_leap = false
	_normal_repeat_streak = 1

# Normal Mode's per-round note pick. Independent state from Music/Duet's
# walk (`_music_*` vars) since Normal's sequence is one continuously
# growing phrase for the whole run, not a per-bar/per-round reset - same
# step-inertia/post-skip-reversal bias as _music_next_delta (see
# docs/music-mode.md), duplicated rather than shared so the three modes'
# walks can't interfere with each other's state.
func _normal_next_delta(max_leap: int) -> int:
	var repeat_chance: float = BASE_REPEAT_CHANCE * pow(REPEAT_DECAY, float(_normal_repeat_streak - 1))
	var step_chance := (1.0 - repeat_chance) * STEP_TO_NON_REPEAT_RATIO
	var r := randf()
	var magnitude: int
	if r < repeat_chance:
		magnitude = 0
	elif r < repeat_chance + step_chance:
		magnitude = 1
	else:
		magnitude = randi_range(2, max_leap)
	if magnitude == 0:
		_normal_last_was_leap = false
		return 0
	var direction: int
	if _normal_last_was_leap and _normal_last_direction != 0:
		direction = -_normal_last_direction
		magnitude = 1
	elif _normal_last_direction != 0 and magnitude == 1:
		direction = _normal_last_direction if randf() < 0.70 else -_normal_last_direction
	else:
		direction = 1 if randf() < 0.5 else -1
	_normal_last_direction = direction
	_normal_last_was_leap = magnitude >= 2
	return direction * magnitude

func _normal_next_pad_name() -> String:
	var scale: Dictionary = SCALES[current_scale_index]
	var is_narrow: bool = MUSIC_NARROW_LEAP_SCALES.has(scale["id"])
	var max_leap := MUSIC_NARROW_MAX_LEAP if is_narrow else MUSIC_PENTATONIC_MAX_LEAP
	var degree := _normal_current_degree
	var delta := _normal_next_delta(max_leap)
	var raw_target := degree + delta
	var new_degree := _reflect_degree(raw_target)
	if new_degree != raw_target and delta != 0:
		_normal_last_direction = -_normal_last_direction
	if new_degree == degree:
		_normal_repeat_streak += 1
	else:
		_normal_repeat_streak = 1
	_normal_current_degree = new_degree
	var play_degree := degree
	# Phrase resolution, same idea as Music/Duet's every-4-bar tonic return
	# (see docs/music-mode.md) - gives the ever-growing sequence periodic
	# "landing points" instead of wandering indefinitely.
	if (sequence.size() + 1) % NORMAL_PHRASE_LENGTH == 0:
		play_degree = 0
		_normal_current_degree = 0
		_normal_repeat_streak = 1
		_normal_last_direction = 0
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	var ring_pos: int = ring_order.find(play_degree)
	return pad_names[ring_pos if ring_pos != -1 else 0]

func _roll_gold_indices() -> void:
	gold_indices.clear()
	if golden_step_count <= 0:
		return
	var pool: Array[int] = []
	for i in sequence.size():
		pool.append(i)
	pool.shuffle()
	var take: int = min(golden_step_count, pool.size())
	gold_indices = pool.slice(0, take)

func _play_sequence() -> void:
	if duet_mode:
		await _play_duet_call()
		return
	var chaos_speed := 1.0
	if chaos_mode:
		chaos_speed = clamp(1.0 - float(sequence.size() - 1) * 0.05, 0.5, 1.0)
	var duration_scale := sequence_speed_multiplier * chaos_speed
	await get_tree().create_timer(0.6).timeout
	for pad_name in sequence:
		await pads_by_name[pad_name].flash(0.4 * duration_scale)
		await get_tree().create_timer(0.25 * duration_scale).timeout

# Plays the Duet call phrase on its actual Euclidean-rhythm grid (not
# uniform gaps like Normal/Chaos) so the call's timing is the thing the
# player is meant to reproduce.
func _play_duet_call() -> void:
	await get_tree().create_timer(0.6).timeout
	var flash_duration: float = min(duet_step_duration * MUSIC_FLASH_FRACTION, MUSIC_FLASH_MAX)
	var note_i := 0
	for step_on in duet_rhythm:
		if step_on:
			var pad_name: String = sequence[note_i]
			note_i += 1
			await pads_by_name[pad_name].flash(flash_duration)
			var remaining := duet_step_duration - flash_duration
			if remaining > 0.0:
				await get_tree().create_timer(remaining).timeout
		else:
			await get_tree().create_timer(duet_step_duration).timeout

# Duet Mode's response phase: strict positional match like Normal Mode (see
# docs/game-modes.md) but timed against `duet_pulse_times`, the same
# schedule the call was just played on. Note identity determines pass/fail
# (wrong pad or no press within the grace window behaves exactly like a
# Normal Mode miss - forgiven by Safety Net charges or ends the run);
# timing accuracy only scales the score via `_register_hit`'s
# `timing_multiplier`, never fails a round on its own.
func _run_duet_response() -> void:
	accepting_input = true
	_set_pads_disabled(false)
	var response_start_ms := Time.get_ticks_msec()
	var i := 0
	while i < sequence.size():
		player_index = i
		_duet_last_press = ""
		var deadline_ms := Time.get_ticks_msec() + int(DUET_NOTE_GRACE_SEC * 1000.0)
		while duet_mode and _duet_last_press == "" and Time.get_ticks_msec() < deadline_ms:
			await get_tree().process_frame
		if not duet_mode:
			return
		if _duet_last_press == "" or _duet_last_press != sequence[i]:
			if not await _handle_duet_miss():
				return
			continue
		var actual_time := float(Time.get_ticks_msec() - response_start_ms) / 1000.0
		var offset := absf(actual_time - duet_pulse_times[i])
		var timing_multiplier := DUET_LATE_MULT
		if offset <= DUET_TIGHT_WINDOW:
			timing_multiplier = DUET_TIGHT_MULT
		elif offset <= DUET_GOOD_WINDOW:
			timing_multiplier = DUET_GOOD_MULT
		_register_hit(_duet_last_press, _duet_last_press_pos, timing_multiplier)
		i += 1
	accepting_input = false
	_set_pads_disabled(true)
	_play_round_clear_beat()
	await get_tree().create_timer(0.6).timeout
	if _current_round() % MODIFIER_ROUND_INTERVAL == 0:
		await _offer_modifier_choice()
	_next_round()

# Returns true if forgiven (caller should retry the same note index), false
# if the run ended and the caller should stop.
func _handle_duet_miss() -> bool:
	if mistake_charges > 0:
		mistake_charges -= 1
		combo = combo / 2
		_update_score_labels()
		_flash_forgiven()
		await _flash_miss_hint(sequence[player_index])
		return true
	_game_over()
	return false

func _on_pad_pressed(pad_name: String) -> void:
	if zen_mode or music_mode:
		return
	if not accepting_input:
		return
	if duet_mode:
		_duet_last_press = pad_name
		_duet_last_press_pos = get_viewport().get_mouse_position()
		return
	if pad_name == sequence[player_index]:
		_register_hit(pad_name, get_viewport().get_mouse_position())
		player_index += 1
		if player_index == sequence.size():
			accepting_input = false
			_set_pads_disabled(true)
			_play_round_clear_beat()
			await get_tree().create_timer(0.6).timeout
			if _current_round() % MODIFIER_ROUND_INTERVAL == 0:
				await _offer_modifier_choice()
			_next_round()
	else:
		if mistake_charges > 0:
			mistake_charges -= 1
			combo = combo / 2
			_update_score_labels()
			_flash_forgiven()
			await _flash_miss_hint(sequence[player_index])
		else:
			_game_over()

func _register_hit(pad_name: String, click_pos: Vector2, timing_multiplier := 1.0) -> void:
	combo += 1
	var multiplier := 1.0 + float(combo - 1) * combo_growth
	var points := int(round(10.0 * multiplier * timing_multiplier))
	if player_index in gold_indices:
		points *= 3
	points = int(round(points * (1.0 + score_bonus_percent)))
	unbanked_points += points
	_register_best(_current_round(), score, combo)
	_update_score_labels()
	_punch(combo_label)
	_spawn_score_popup(click_pos, "+%d" % points, pads_by_name[pad_name].lit_color)
	_spawn_burst(click_pos, pads_by_name[pad_name].lit_color)
	_screen_shake(3.0, 0.12)

func _offer_modifier_choice() -> void:
	current_offer = MODIFIERS.duplicate()
	current_offer.shuffle()
	current_offer = current_offer.slice(0, 3)
	for i in modifier_buttons.size():
		var mod: Dictionary = current_offer[i]
		var stack_count: int = modifier_stacks.get(mod["id"], 0)
		var stack_suffix := "  (active x%d)" % stack_count if stack_count > 0 else ""
		modifier_buttons[i].text = "%s %s%s\n%s" % [mod["icon"], mod["title"], stack_suffix, mod["desc"]]
	await _reveal_modifier_panel()
	var chosen_id: String = await _modifier_picked
	modifier_panel.visible = false
	_apply_modifier(chosen_id)

# Dramatic reveal for the modifier choice - it's a meaningful decision point,
# so it gets a heavier scale + glow-in treatment than routine panel opens.
func _reveal_modifier_panel() -> void:
	modifier_panel.visible = true
	var vbox: Control = modifier_vbox
	await get_tree().process_frame
	vbox.pivot_offset = vbox.size / 2.0
	vbox.scale = Vector2(0.55, 0.55)
	vbox.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(vbox, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(vbox, "modulate:a", 1.0, 0.25)
	_flash_screen(Color(0.7, 0.5, 1.0, 0.18))
	await t.finished

func _on_modifier_button_pressed(index: int) -> void:
	if index < current_offer.size():
		_modifier_picked.emit(current_offer[index]["id"])

func _apply_modifier(id: String) -> void:
	modifier_stacks[id] = int(modifier_stacks.get(id, 0)) + 1
	match id:
		"sharper_ear":
			combo_growth += 0.05
		"safety_net":
			mistake_charges += 1
		"golden_step":
			golden_step_count += 1
		"steady_hands":
			sequence_speed_multiplier *= 1.15
		"resonance":
			score_bonus_percent += 0.1

func _game_over() -> void:
	accepting_input = false
	_set_pads_disabled(true)
	var final_round := _current_round() - 1
	var final_score := score
	var final_combo := combo
	var new_best_score := final_score > run_start_best_score
	var new_best_round := final_round > run_start_best_round
	var new_best_combo := final_combo > run_start_best_combo
	var celebrate := new_best_score or new_best_round or new_best_combo or not run_new_unlocks.is_empty()
	combo = 0
	_update_score_labels()
	Sound.play_fail()
	cash_out_button.visible = false
	round_label.text = "Game Over! Round %d" % final_round
	start_button.disabled = false
	chaos_button.disabled = false
	settings_button.disabled = false
	zen_button.disabled = false
	music_button.disabled = false
	duet_button.disabled = false
	_screen_shake(5.0, 0.25)
	if celebrate:
		_flash_screen(Color(1, 0.85, 0.3, 0.35))
		_play_unlock_fanfare()
	else:
		_flash_screen(Color(1, 0.65, 0.3, 0.2))
	_show_game_over_summary(final_round, final_score, final_combo, new_best_score, new_best_round, new_best_combo)

func _show_game_over_summary(round_reached: int, final_score: int, final_combo: int, new_best_score: bool, new_best_round: bool, new_best_combo: bool) -> void:
	game_over_stats_label.text = "Score: %d   Round: %d   Combo: %d" % [final_score, round_reached, final_combo]
	var callouts: Array[String] = []
	if new_best_score:
		callouts.append("New Best Score!")
	if new_best_round:
		callouts.append("New Best Round!")
	if new_best_combo:
		callouts.append("New Best Combo!")
	for entry in run_new_unlocks:
		callouts.append("Unlocked: %s!" % String(entry["name"]).replace("\n", " "))
	game_over_best_label.visible = not callouts.is_empty()
	game_over_best_label.text = "\n".join(callouts)
	game_over_panel.visible = true

func _on_game_over_close_pressed() -> void:
	game_over_panel.visible = false
	# Brief cooldown before the top mode buttons (one of which now reads
	# "Restart") become clickable again - dismissing the summary shouldn't
	# hand you a hot "do it again" button with zero breathing room.
	start_button.disabled = true
	chaos_button.disabled = true
	zen_button.disabled = true
	music_button.disabled = true
	duet_button.disabled = true
	await get_tree().create_timer(0.35).timeout
	start_button.disabled = false
	chaos_button.disabled = false
	zen_button.disabled = false
	music_button.disabled = false
	duet_button.disabled = false

func _flash_forgiven() -> void:
	_screen_shake(6.0, 0.15)
	_flash_screen(Color(1, 1, 1, 0.35))

# Audit finding: a blind retry only helps when the miss was a fumble, not a
# forgotten note - if you didn't know the note, guessing again with zero new
# information usually just burns another charge. Safety Net (the only
# shipped Defense modifier) now replays the correct pad once before handing
# input back, so forgiveness actually saves the player rather than just
# delaying the same failure. Pads stay disabled during the hint so a stray
# click can't sneak in ahead of it.
func _flash_miss_hint(pad_name: String) -> void:
	_set_pads_disabled(true)
	await pads_by_name[pad_name].flash(0.35)
	_set_pads_disabled(false)

func _update_score_labels() -> void:
	score_label.text = "Score: %d" % score
	if combo > 1:
		var multiplier := 1.0 + float(combo - 1) * combo_growth
		combo_label.text = "Combo x%d  (%.1fx)" % [combo, multiplier]
	else:
		combo_label.text = ""
	var total := _cash_out_total()
	cash_out_button.text = "Cash Out (+%d)" % total if total > 0 else "Cash Out"

func _set_pads_disabled(value: bool) -> void:
	for pad_name in pads_by_name:
		pads_by_name[pad_name].disabled = value
	# Cash out is only offered on the player's turn - not while the sequence
	# is playing back or during the round-clear pause, so it can't be tapped
	# mid-animation into an inconsistent state.
	cash_out_button.disabled = value

func _play_round_clear_beat() -> void:
	_punch(round_label)
	_flash_screen(Color(0.4, 1.0, 0.6, 0.15))

func _punch(node: Control) -> void:
	node.scale = Vector2(1.35, 1.35)
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _screen_shake(strength: float, duration: float) -> void:
	if reduce_motion:
		return
	var steps := 6
	var t := create_tween()
	for i in steps:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		t.tween_property(self, "position", offset, duration / steps)
	t.tween_property(self, "position", Vector2.ZERO, duration / steps)

func _flash_screen(color: Color) -> void:
	var display_color := color
	if reduce_motion:
		display_color.a *= 0.25
	flash_overlay.color = display_color
	var t := create_tween()
	t.tween_property(flash_overlay, "color:a", 0.0, 0.5)

func _spawn_score_popup(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos - Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 40, 0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(label.queue_free)

func _spawn_burst(pos: Vector2, color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2(0, 300)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)
