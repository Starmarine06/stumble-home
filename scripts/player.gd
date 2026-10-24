extends CharacterBody3D

# ----------------- CASINO MINIGAME PRELOADS -----------------
const DartsScene = preload("res://scripts/minigames/darts_game.gd")
const CupPongScene = preload("res://scripts/minigames/cup_pong_game.gd")
const SlotsScene = preload("res://scripts/minigames/slots_game.gd")
const RouletteScene = preload("res://scripts/minigames/roulette_game.gd")

@export var walk_speed: float = 5.2
@export var sprint_speed: float = 9.2
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.003
@export var acceleration: float = 12.0
@export var friction: float = 9.0

# Head bobbing settings
@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.05
var bob_timer: float = 0.0
var default_head_y: float = 0.0
var is_mouse_unlocked: bool = false
var default_fov: float = 75.0

# ----------------- GAME MECHANIC METERS -----------------
# 1. Coma Lifeline Bar removed per user request (no coma blackout/death)
var buzz_meter: float = 100.0
const BUZZ_DRAIN_RATE: float = 0.0 # No coma drain

# 2. Drunkenness Meter (Always 100% permanently drunk from boot!)
var drunk_meter: float = 100.0 # Starts and stays fully drunk!
const DRUNK_DECAY_RATE: float = 0.0 # Never decays

# 3. Smoke Density / Dizziness Meter (0-100%):
var smoke_meter: float = 0.0
const SMOKE_DECAY_RATE: float = 1.0
const DIZZY_SMOKE_THRESHOLD: float = 38.0

# 4. Status Flags
var is_in_coma: bool = false
var coma_fade: float = 0.0
var is_inside_van: bool = false
var boost_timer: float = 0.0
var fx_elapsed_time: float = 0.0

# 5. Drunk Double-Image (Previous Frame Trail & Blur)
var lag_cam_rot: Vector3 = Vector3.ZERO
var ghost_offset: Vector2 = Vector2.ZERO

const PART_NAMES: Array[String] = ["Battery", "Fuel Pump", "Spark Plugs", "Spare Tyre"]
const PART_MASS: Array[float] = [12.0, 5.0, 0.4, 9.0]
enum PS { WORLD, CARRIED, INSTALLED }
var local_parts: Array = []

func _get_game() -> Node:
	if has_node("/root/Game"):
		return get_node("/root/Game")
	return null

func _get_parts() -> Array:
	var g = _get_game()
	if g and ("parts" in g) and not g.parts.is_empty():
		return g.parts
	return local_parts

func _get_scavenge_parts_root() -> Node3D:
	if scavenge_parts_root and is_instance_valid(scavenge_parts_root):
		return scavenge_parts_root
	if is_inside_tree() and get_tree().root:
		scavenge_parts_root = get_tree().root.find_child("ScavengeParts", true, false) as Node3D
	return scavenge_parts_root

# Active drink animation state
enum AnimState { NONE, DRINKING, SOBER_CAN }
var current_anim: AnimState = AnimState.NONE
var anim_timer: float = 0.0
var anim_duration: float = 0.0

# ----------------- DRUNKEN STRIDE & WASD KEY-SHIFT STUMBLE MECHANIC -----------------
enum WASDKey { NONE, W, A, S, D }
var current_step_key: WASDKey = WASDKey.NONE
var key_hold_time: float = 0.0
var drunk_momentum: float = 0.0
var is_stumbling: bool = false
var stumble_timer: float = 0.0
var stumble_direction: Vector3 = Vector3.ZERO
var last_move_direction: Vector3 = Vector3.ZERO
var is_fallen_down: bool = false
var fall_stun_timer: float = 0.0
var step_shift_feedback_timer: float = 0.0
var is_stunned: bool = false
var balance_tilt: float = 0.0 # Legacy fallback for tests/external references
var balance_bar: Control = null
var drunk_model: Drunk = null

# ----------------- CASINO MINIGAME STATIONS & PARTS UNLOCKED -----------------
var minigame_stations: Array[Node] = []
var active_station_idx: int = -1
var won_parts: Array[bool] = [false, false, false, false] # Battery, FuelPump, SparkPlugs, SpareTyre
var player_money: int = 1000 # 4-Patron Shared Wallet ($1,000 Starting Cash)
var wallet_label: Label = null

# 3D Darts & Betting Dialog Preloads
const Darts3DGameClass = preload("res://scripts/minigames/darts_3d_game.gd")
const DartsBettingDialogClass = preload("res://scripts/ui/darts_betting_dialog.gd")
var active_darts_3d: Node = null

# 3D Roulette & Betting Dialog Preloads
const Roulette3DGameClass = preload("res://scripts/minigames/roulette_3d_game.gd")
const RouletteBettingDialogClass = preload("res://scripts/ui/roulette_betting_dialog.gd")
var active_roulette_3d: Node = null

# ----------------- CAR PART SCAVENGING & CARRYING -----------------
var carried_part_idx: int = -1
var carried_reach: float = 1.0
var carried_rel_yaw: float = 0.0
var carried_hp: Vector3 = Vector3.ZERO
var carried_hv: Vector3 = Vector3.ZERO
var arm_strain: float = 0.0
var aim_part_idx: int = -1
var fit_q: float = -1.0
var minigame_active: bool = false
var grab_cd: float = 0.0

# References to Car Parts Viewmodels & HUD
@onready var carried_part_root: Node3D = get_node_or_null("Head/Camera3D/ViewModels/CarriedPart")
var carried_meshes: Array[MeshInstance3D] = []
@onready var strain_bar: ProgressBar = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/StrainContainer/StrainBar")
@onready var strain_label: Label = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/StrainContainer/StrainLabel")
@onready var shaky_holder: Control = get_node_or_null("HUD/ShakyHolder")

var part_checklist: PartChecklist = null
var part_compass: PartCompass = null
var part_crosshair: PartCrosshair = null
var scavenge_parts_root: Node3D = null
var van_root: Node3D = null
var van_slots: Array[Node3D] = []
var victory_ui: Control = null

# ----------------- REALISTIC SMOKING SYSTEM -----------------
enum SmokingSeqState {
	IDLE,               # No cigarette held
	TAKING_PACK,        # Pack swings up into view
	PULLING_CIG,        # Pack lid flips open, cigarette slides up out of pack
	LIGHTING_LIGHTER,   # Lighter rises into view, snaps open
	IGNITING_TIP,       # Flame sparks, touches tip, ember ignites
	PUTTING_AWAY,       # Pack & lighter lower away, lit cigarette settles in hand
	READY,              # Lit cigarette held in hand, waiting for mouse scroll wheel
	PUFFING,            # Inhaling drag at mouth via scroll wheel, paper burns down
	EXHALING,           # Lowering back to hand, billowing smoke cloud exhaled
	BURNT_OUT           # Completely burnt down to filter stub, flicked away
}
var smoking_seq_state: SmokingSeqState = SmokingSeqState.IDLE
var seq_timer: float = 0.0
var cig_burn_factor: float = 0.0 # 1.0 (fresh full length) down to 0.0 (burnt out)
var cig_is_lit: bool = false
var puff_timer: float = 0.0
var is_inhaling: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = get_node_or_null("Head/Camera3D/Flashlight")

# Viewmodel references
@onready var viewmodel_root: Node3D = $Head/Camera3D/ViewModels

# 1. Cigarette Pack
@onready var cig_pack: Node3D = get_node_or_null("Head/Camera3D/ViewModels/CigarettePack")
@onready var pack_lid: Node3D = get_node_or_null("Head/Camera3D/ViewModels/CigarettePack/PackLid")
@onready var ext_cig: Node3D = get_node_or_null("Head/Camera3D/ViewModels/CigarettePack/ExtractedCig")

# 2. Lighter
@onready var lighter: Node3D = get_node_or_null("Head/Camera3D/ViewModels/Lighter")
@onready var lighter_lid: Node3D = get_node_or_null("Head/Camera3D/ViewModels/Lighter/LighterLid")
@onready var lighter_flame: MeshInstance3D = get_node_or_null("Head/Camera3D/ViewModels/Lighter/LighterFlame")
@onready var lighter_light: OmniLight3D = get_node_or_null("Head/Camera3D/ViewModels/Lighter/LighterLight")

# 3. Active Cigarette
@onready var cigarette: Node3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette")
@onready var cig_paper: MeshInstance3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette/PaperMesh")
@onready var tip_assembly: Node3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette/TipAssembly")
@onready var cig_tip: MeshInstance3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette/TipAssembly/EmberTip")
@onready var ash_tip: MeshInstance3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette/TipAssembly/AshTip")
@onready var ember_light: OmniLight3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette/TipAssembly/EmberLight")
@onready var smoke_particles: CPUParticles3D = get_node_or_null("Head/Camera3D/ViewModels/Cigarette/TipAssembly/SmokeParticles")
@onready var exhale_smoke: CPUParticles3D = get_node_or_null("Head/Camera3D/ExhaleSmoke")

# 4. Consumables
@onready var bottle: Node3D = get_node_or_null("Head/Camera3D/ViewModels/Bottle")
@onready var energy_can: Node3D = get_node_or_null("Head/Camera3D/ViewModels/EnergyCan")

# Screen FX & UI
@onready var screen_fx_rect: ColorRect = $HUD/ScreenFX
@onready var effect_badge: Label = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/EffectBadge")
@onready var dialogue_ui: Control = get_node_or_null("HUD/DialogueUI")
@onready var dialogue_name_lbl: Label = get_node_or_null("HUD/DialogueUI/Margin/VBox/SpeakerName")
@onready var dialogue_text_lbl: Label = get_node_or_null("HUD/DialogueUI/Margin/VBox/DialogueText")
@onready var interact_prompt_lbl: Label = get_node_or_null("HUD/InteractPrompt")

# Meters UI
@onready var buzz_bar: ProgressBar = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/BuzzContainer/BuzzBar")
@onready var buzz_label: Label = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/BuzzContainer/BuzzLabel")
@onready var drunk_bar: ProgressBar = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/DrunkContainer/DrunkBar")
@onready var drunk_label: Label = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/DrunkContainer/DrunkLabel")
@onready var smoke_bar: ProgressBar = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/SmokeContainer/SmokeBar")
@onready var smoke_label: Label = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/SmokeContainer/SmokeLabel")
@onready var cig_bar: ProgressBar = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/CigContainer/CigBar")
@onready var cig_label: Label = get_node_or_null("HUD/ControlsUI/PanelContainer/VBoxContainer/CigContainer/CigLabel")

# Coma Overlay UI
@onready var coma_ui: Control = get_node_or_null("HUD/ComaUI")

# Interaction State
var current_talking_npc: Node = null
var dialogue_timer: float = 0.0
var van_node: Node3D = null

# Default positions & transforms for viewmodels
const PACK_REST_POS = Vector3(-0.32, -0.55, -0.35)
const PACK_REST_ROT = Vector3(0.26, 0.44, -0.14)
const PACK_UP_POS = Vector3(-0.16, -0.22, -0.30)
const PACK_UP_ROT = Vector3(0.20, 0.35, -0.10)

const LIGHTER_REST_POS = Vector3(0.32, -0.55, -0.30)
const LIGHTER_REST_ROT = Vector3(0.17, -0.35, 0.09)
const LIGHTER_LIGHTING_POS = Vector3(0.042, -0.140, -0.298)
const LIGHTER_LIGHTING_ROT = Vector3(0.10, -0.26, 0.07)
const LIGHTER_UP_POS = LIGHTER_LIGHTING_POS
const LIGHTER_UP_ROT = LIGHTER_LIGHTING_ROT

const CIG_REST_POS = Vector3(0.20, -0.55, -0.35)
const CIG_REST_ROT = Vector3(0.3, 0.15, -0.1)
# Center & a bit below center of screen for lighting sequence
const CIG_LIGHTING_POS = Vector3(0.0, -0.135, -0.23)
const CIG_LIGHTING_ROT = Vector3(0.52, 0.0, 0.0)
# Lowered resting hand stance
const CIG_HOLD_POS = Vector3(0.14, -0.26, -0.28)
const CIG_HOLD_ROT = Vector3(0.30, 0.15, -0.08)
# Center bottom of screen for active smoking via scroll wheel down
const CIG_SMOKE_POS = Vector3(0.0, -0.105, -0.185)
const CIG_SMOKE_ROT = Vector3(0.68, 0.0, 0.0)
const CIG_MOUTH_POS = CIG_SMOKE_POS
const CIG_MOUTH_ROT = CIG_SMOKE_ROT
const CIG_BURNT_POS = Vector3(0.14, -0.65, -0.28)
const CIG_BURNT_ROT = Vector3(1.6, 0.6, 1.4)

# Bottle: Nozzle (+Y axis) tilts towards player face (+Z) with positive rotation around X!
const BOTTLE_REST_POS = Vector3(0.24, -0.42, -0.38)
const BOTTLE_REST_ROT = Vector3(0.0, 0.0, 0.0)
const BOTTLE_UP_POS = Vector3(0.07, -0.12, -0.22)
const BOTTLE_UP_ROT = Vector3(1.309, -0.28, -0.14) # ~75° X pitch pointing nozzle straight at mouth

const CAN_REST_POS = Vector3(0.26, -0.42, -0.40)
const CAN_REST_ROT = Vector3(0.0, 0.0, 0.0)
const CAN_UP_POS = Vector3(0.12, -0.11, -0.28)
const CAN_UP_ROT = Vector3(-0.85, 0.2, -0.15)

func _ready() -> void:
	if not head:
		head = get_node_or_null("Head")
	if not flashlight:
		flashlight = find_child("Flashlight", true, false)
	if not effect_badge:
		effect_badge = find_child("EffectBadge", true, false)
	if not screen_fx_rect:
		screen_fx_rect = find_child("ScreenFX", true, false)
	if not dialogue_ui:
		dialogue_ui = find_child("DialogueUI", true, false)
	if not dialogue_name_lbl:
		dialogue_name_lbl = find_child("SpeakerName", true, false)
	if not dialogue_text_lbl:
		dialogue_text_lbl = find_child("DialogueText", true, false)
	if not interact_prompt_lbl:
		interact_prompt_lbl = find_child("InteractPrompt", true, false)
	if not coma_ui:
		coma_ui = find_child("ComaUI", true, false)

	# Fetch meter UI references via fallback if needed
	if not buzz_bar:
		buzz_bar = find_child("BuzzBar", true, false)
	if buzz_bar:
		# Explicitly style the Coma Lifeline Bar in vibrant RED
		var red_fill = StyleBoxFlat.new()
		red_fill.bg_color = Color(0.95, 0.12, 0.18) # Vibrant crimson red
		red_fill.corner_radius_top_left = 3
		red_fill.corner_radius_top_right = 3
		red_fill.corner_radius_bottom_left = 3
		red_fill.corner_radius_bottom_right = 3
		buzz_bar.add_theme_stylebox_override("fill", red_fill)

		var red_bg = StyleBoxFlat.new()
		red_bg.bg_color = Color(0.20, 0.04, 0.06, 0.90) # Dark maroon background
		red_bg.border_width_left = 1
		red_bg.border_width_top = 1
		red_bg.border_width_right = 1
		red_bg.border_width_bottom = 1
		red_bg.border_color = Color(0.85, 0.20, 0.25, 0.70)
		red_bg.corner_radius_top_left = 3
		red_bg.corner_radius_top_right = 3
		red_bg.corner_radius_bottom_left = 3
		red_bg.corner_radius_bottom_right = 3
		buzz_bar.add_theme_stylebox_override("background", red_bg)
		buzz_bar.custom_minimum_size = Vector2(240, 16)
	if not buzz_label:
		buzz_label = find_child("BuzzLabel", true, false)
	if not drunk_bar:
		drunk_bar = find_child("DrunkBar", true, false)
	if not drunk_label:
		drunk_label = find_child("DrunkLabel", true, false)
	if not smoke_bar:
		smoke_bar = find_child("SmokeBar", true, false)
	if not smoke_label:
		smoke_label = find_child("SmokeLabel", true, false)
	if not cig_bar:
		cig_bar = find_child("CigBar", true, false)
	if not cig_label:
		cig_label = find_child("CigLabel", true, false)

	# Fetch viewmodel references with fallback if needed
	if not cig_pack:
		cig_pack = find_child("CigarettePack", true, false)
	if not pack_lid:
		pack_lid = find_child("PackLid", true, false)
	if not ext_cig:
		ext_cig = find_child("ExtractedCig", true, false)
	if not lighter:
		lighter = find_child("Lighter", true, false)
	if not lighter_lid:
		lighter_lid = find_child("LighterLid", true, false)
	if not lighter_flame:
		lighter_flame = find_child("LighterFlame", true, false)
	if not lighter_light:
		lighter_light = find_child("LighterLight", true, false)
	if not cigarette:
		cigarette = find_child("Cigarette", true, false)
	if not cig_paper:
		cig_paper = find_child("PaperMesh", true, false)
	if not tip_assembly:
		tip_assembly = find_child("TipAssembly", true, false)
	if not cig_tip:
		cig_tip = find_child("EmberTip", true, false)
	if not ash_tip:
		ash_tip = find_child("AshTip", true, false)
	if not ember_light:
		ember_light = find_child("EmberLight", true, false)
	if not smoke_particles:
		smoke_particles = find_child("SmokeParticles", true, false)
	if not exhale_smoke:
		exhale_smoke = find_child("ExhaleSmoke", true, false)

	if head:
		default_head_y = head.position.y
		head.rotation.x = deg_to_rad(6.0)
	if camera:
		default_fov = camera.fov

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_mouse_unlocked = false

	# Smooth step/ramp walking without getting stuck or needing to jump
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	floor_stop_on_slope = true

	reset_viewmodels()

	if dialogue_ui:
		dialogue_ui.visible = false
	if interact_prompt_lbl:
		interact_prompt_lbl.visible = false
	if coma_ui:
		coma_ui.visible = false
	if buzz_bar and buzz_bar.get_parent():
		buzz_bar.get_parent().visible = false

	# Initialize Drunk Balance Model
	drunk_model = Drunk.new(0.6)
	drunk_model.tripped.connect(func():
		_play_sfx(&"passout")
		print("⚠️ Tripped! Regaining balance...")
	)

	# Initialize local_parts and sync with Game if available
	local_parts = [
		{"name": "Battery", "state": PS.WORLD, "holder": 0, "pos": Vector3(14.2, 1.35, -43.2), "yaw": 0.0, "q": 0.0, "loose_t": 0.0, "warned": false},
		{"name": "Fuel Pump", "state": PS.WORLD, "holder": 0, "pos": Vector3(-6.0, 1.35, -26.0), "yaw": 0.0, "q": 0.0, "loose_t": 0.0, "warned": false},
		{"name": "Spark Plugs", "state": PS.WORLD, "holder": 0, "pos": Vector3(-16.0, 1.35, -32.0), "yaw": 0.0, "q": 0.0, "loose_t": 0.0, "warned": false},
		{"name": "Spare Tyre", "state": PS.WORLD, "holder": 0, "pos": Vector3(20.0, 0.95, -34.0), "yaw": 0.0, "q": 0.0, "loose_t": 0.0, "warned": false}
	]
	var g_node = _get_game()
	if g_node and ("parts" in g_node) and g_node.parts.is_empty():
		g_node.parts = local_parts.duplicate(true)

	# Locate ScavengeParts root in the scene
	scavenge_parts_root = get_tree().root.find_child("ScavengeParts", true, false)
	# Locate MinigameStations in the scene
	var st_root = get_tree().root.find_child("MinigameStations", true, false)
	if st_root:
		minigame_stations = st_root.get_children()
	else:
		minigame_stations = get_tree().get_nodes_in_group("minigame_stations")
	# Locate Van root
	van_root = get_tree().root.find_child("ParkedVan", true, false)
	if not van_root:
		van_root = get_tree().root.find_child("Van", true, false)
	van_slots.clear()
	if van_root:
		for s_name in ["Slot_Battery", "Slot_FuelPump", "Slot_SparkPlugs", "Slot_SpareTyre"]:
			var slot_node = van_root.find_child(s_name, true, false) as Node3D
			van_slots.append(slot_node)
			if slot_node:
				var ghost = slot_node.find_child("Ghost", true, false)
				if ghost:
					ghost.visible = false

	# Setup CarriedPart viewmodel meshes
	if not carried_part_root:
		carried_part_root = find_child("CarriedPart", true, false)
	if carried_part_root:
		carried_meshes.clear()
		for i in 4:
			var m = carried_part_root.get_node_or_null("Mesh_%d" % i)
			if not m:
				for c in carried_part_root.get_children():
					if c.name.begins_with("Mesh_%d" % i):
						m = c
						break
			if m:
				carried_meshes.append(m as MeshInstance3D)
				m.visible = false

	# Setup HUD widgets
	var hud_node = get_node_or_null("HUD")
	if hud_node:
		part_checklist = PartChecklist.new()
		part_checklist.name = "PartChecklist"
		part_checklist.position = Vector2(20, 20)
		hud_node.add_child(part_checklist)

		# 4-Patron Shared Wallet in Top Right ($1,000 Starting Cash)
		var wallet_panel = PanelContainer.new()
		wallet_panel.name = "WalletPanel"
		var w_sb = StyleBoxFlat.new()
		w_sb.bg_color = Color(0.06, 0.08, 0.12, 0.94)
		w_sb.border_color = Color(0.95, 0.78, 0.22)
		w_sb.set_border_width_all(2)
		w_sb.set_corner_radius_all(10)
		w_sb.shadow_size = 10
		w_sb.shadow_color = Color(0, 0, 0, 0.6)
		wallet_panel.add_theme_stylebox_override("panel", w_sb)
		wallet_panel.position = Vector2(1280 - 250, 16)
		wallet_panel.custom_minimum_size = Vector2(230, 72)

		var w_margin = MarginContainer.new()
		w_margin.add_theme_constant_override("margin_left", 14)
		w_margin.add_theme_constant_override("margin_right", 14)
		w_margin.add_theme_constant_override("margin_top", 8)
		w_margin.add_theme_constant_override("margin_bottom", 8)
		wallet_panel.add_child(w_margin)

		var w_vbox = VBoxContainer.new()
		w_vbox.add_theme_constant_override("separation", 2)
		w_margin.add_child(w_vbox)

		var w_hdr = Label.new()
		w_hdr.text = "💰 SHARED WALLET (4 PATRONS)"
		w_hdr.add_theme_font_size_override("font_size", 11)
		w_hdr.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		w_vbox.add_child(w_hdr)

		wallet_label = Label.new()
		wallet_label.text = "$%d" % player_money
		wallet_label.add_theme_font_size_override("font_size", 24)
		wallet_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		w_vbox.add_child(wallet_label)

		hud_node.add_child(wallet_panel)

		part_crosshair = PartCrosshair.new()
		part_crosshair.name = "PartCrosshair"
		hud_node.add_child(part_crosshair)

		# BalanceBar removed per user request (no manual Q/E tilt balancing)
		balance_bar = null

		if not shaky_holder:
			shaky_holder = hud_node.find_child("ShakyHolder", true, false)
			if not shaky_holder:
				shaky_holder = CenterContainer.new()
				shaky_holder.name = "ShakyHolder"
				shaky_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
				shaky_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hud_node.add_child(shaky_holder)

	if not strain_bar:
		strain_bar = find_child("StrainBar", true, false)
	if not strain_label:
		strain_label = find_child("StrainLabel", true, false)

func reset_viewmodels() -> void:
	ensure_smoking_references()
	if cig_pack:
		cig_pack.position = PACK_REST_POS
		cig_pack.rotation = PACK_REST_ROT
		cig_pack.visible = false
	if pack_lid:
		pack_lid.rotation.x = 0.0
	if ext_cig:
		ext_cig.position = Vector3(0, 0.035, 0)
		ext_cig.visible = false
	if lighter:
		lighter.position = LIGHTER_REST_POS
		lighter.rotation = LIGHTER_REST_ROT
		lighter.visible = false
	if lighter_lid:
		lighter_lid.rotation.z = 0.0
	if lighter_flame:
		lighter_flame.visible = false
	if lighter_light:
		lighter_light.visible = false
	if cigarette:
		cigarette.position = CIG_REST_POS
		cigarette.rotation = CIG_REST_ROT
		cigarette.visible = false
	if smoke_particles:
		smoke_particles.emitting = false
	if bottle:
		bottle.position = BOTTLE_REST_POS
		bottle.rotation = BOTTLE_REST_ROT
		bottle.visible = false
	if energy_can:
		energy_can.position = CAN_REST_POS
		energy_can.rotation = CAN_REST_ROT
		energy_can.visible = false
	if carried_part_root:
		carried_part_root.visible = false
	for m in carried_meshes:
		m.visible = false

func is_ui_active() -> bool:
	if dialogue_ui and dialogue_ui.visible:
		return true
	if victory_ui and victory_ui.visible:
		return true
	if active_darts_3d != null:
		return true
	if active_roulette_3d != null:
		return true
	if get_tree() and get_tree().root.find_child("DartsBettingDialog", true, false) != null:
		return true
	if get_tree() and get_tree().root.find_child("RouletteBettingDialog", true, false) != null:
		return true
	if minigame_active:
		return true
	if shaky_holder and shaky_holder.get_child_count() > 0:
		return true
	if is_mouse_unlocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return true
	return false

func is_modal_dialog_open() -> bool:
	if dialogue_ui and dialogue_ui.visible:
		return true
	if victory_ui and victory_ui.visible:
		return true
	if active_darts_3d != null:
		return true
	if active_roulette_3d != null:
		return true
	if get_tree() and get_tree().root.find_child("DartsBettingDialog", true, false) != null:
		return true
	if get_tree() and get_tree().root.find_child("RouletteBettingDialog", true, false) != null:
		return true
	if minigame_active:
		return true
	if shaky_holder and shaky_holder.get_child_count() > 0:
		return true
	return false

func _close_all_modals() -> void:
	var darts_dlg = get_tree().root.find_child("DartsBettingDialog", true, false) if get_tree() else null
	if darts_dlg:
		darts_dlg.queue_free()
	var roulette_dlg = get_tree().root.find_child("RouletteBettingDialog", true, false) if get_tree() else null
	if roulette_dlg:
		roulette_dlg.queue_free()
	if active_darts_3d != null:
		active_darts_3d.cleanup()
		active_darts_3d.queue_free()
		active_darts_3d = null
	if active_roulette_3d != null:
		active_roulette_3d.queue_free()
		active_roulette_3d = null
	if shaky_holder:
		for c in shaky_holder.get_children():
			c.queue_free()
	if dialogue_ui and dialogue_ui.visible:
		dialogue_ui.visible = false
		current_talking_npc = null
		dialogue_timer = 0.0
	minigame_active = false
	is_mouse_unlocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Coma Restart / Menu Handling
	if is_in_coma:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R or event.keycode == KEY_SPACE:
				print("Restarting game after coma...")
				get_tree().reload_current_scene()
			elif event.keycode == KEY_M or event.keycode == KEY_ESCAPE:
				print("Returning to Home Screen...")
				get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
		return

	# ESC key: cleanly close any active modal dialog and hide/recapture mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_modal_dialog_open():
			_close_all_modals()
			return
		else:
			is_mouse_unlocked = not is_mouse_unlocked
			if is_mouse_unlocked:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

	# When any UI or modal dialog is open, freeze 3D camera look and gameplay actions completely!
	if is_ui_active() or is_modal_dialog_open():
		return

	# Mouse Look (360-degree yaw & pitch)
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var mouse_invert = 1.0
			rotate_y(-event.relative.x * mouse_sensitivity * mouse_invert)
			if head:
				head.rotate_x(-event.relative.y * mouse_sensitivity * mouse_invert)
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	# Mouse Click to re-capture & Mouse Scroll Wheel to Smoke
	if event is InputEventMouseButton and event.pressed:
		if is_mouse_unlocked and not is_modal_dialog_open():
			is_mouse_unlocked = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		# If holding a car part: mouse wheel alters reach!
		if carried_part_idx != -1:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				carried_reach = minf(1.5, carried_reach + 0.08)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				carried_reach = maxf(0.6, carried_reach - 0.08)
			# Right click or Left click while green seats the part into the van!
			elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
				if fit_q >= 0.75:
					_seat_part_perfectly(carried_part_idx)
				elif fit_q >= 0.0:
					_seat_part_crooked(carried_part_idx)
		else:
			# --- MOUSE SCROLL WHEEL SMOKING CONTROL ---
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
				handle_mouse_wheel_down_smoke()

		# Hold Right Click or Left Click to lift aimed car part
		if (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT) and carried_part_idx == -1 and aim_part_idx != -1 and grab_cd <= 0.0:
			_lift_part(aim_part_idx)

	# Keyboard shortcuts (only when no UI is open)
	if event is InputEventKey and event.pressed:
		# Flashlight Toggle
		if event.keycode == KEY_F or event.is_action_pressed("toggle_flashlight"):
			if flashlight:
				flashlight.visible = not flashlight.visible

		# Return to Home Screen
		elif event.keycode == KEY_M:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/home_screen.tscn")

		# Screenshot
		elif event.keycode == KEY_F12:
			var img = get_viewport().get_texture().get_image()
			if img:
				img.save_png("/tmp/stumble_home_screenshot.png")
				print("Saved screenshot to /tmp/stumble_home_screenshot.png")

		# --- NUMBER ACTIONS 1-3 ---
		# 1: Cigarette Action (Pull from pack & light fresh one / puff if held)
		elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			handle_mouse_wheel_down_smoke()

		# 2: Drinking -> Replenishes buzz stamina (+35), increases drunkenness!
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			start_drinking_animation()

		# 3: Energy Drink -> Sober Up (clears drunk and smoke, boosts stamina!)
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			start_sober_can_animation()

		# Q: Drop carried car part
		elif event.keycode == KEY_Q and not event.echo:
			if carried_part_idx != -1:
				_drop_carried_part()

		# E: Interact / Play Casino Minigame / Seat part when green / Lift part
		elif event.keycode == KEY_E and not event.echo:
			if carried_part_idx != -1:
				if fit_q >= 0.75:
					_seat_part_perfectly(carried_part_idx)
				elif fit_q >= 0.0:
					_seat_part_crooked(carried_part_idx)
			elif aim_part_idx != -1:
				_lift_part(aim_part_idx)
			elif active_station_idx != -1:
				_open_casino_minigame(active_station_idx)
			else:
				handle_interaction()

# ----------------- REALISTIC SMOKING ACTIONS & SEQUENCES -----------------

func handle_key_1_smoke() -> void:
	handle_mouse_wheel_down_smoke()

func handle_mouse_wheel_smoke() -> void:
	handle_mouse_wheel_down_smoke()

func handle_mouse_wheel_down_smoke() -> void:
	if is_in_coma:
		return
	if smoking_seq_state == SmokingSeqState.READY or smoking_seq_state == SmokingSeqState.PUFFING or smoking_seq_state == SmokingSeqState.EXHALING:
		# Lit cigarette: scroll wheel down brings it to center bottom of screen & smokes it!
		puff_cigarette()
	elif smoking_seq_state == SmokingSeqState.IDLE or smoking_seq_state == SmokingSeqState.BURNT_OUT:
		# Empty / finished: scrolling wheel down pulls fresh cigarette from right hand and lights it!
		start_take_and_light_cigarette()

func ensure_smoking_references() -> void:
	if not cig_pack:
		cig_pack = find_child("CigarettePack", true, false)
	if not pack_lid and cig_pack:
		pack_lid = cig_pack.find_child("PackLid", true, false)
	if not ext_cig and cig_pack:
		ext_cig = cig_pack.find_child("ExtractedCig", true, false)
	if not lighter:
		lighter = find_child("Lighter", true, false)
	if not lighter_lid and lighter:
		lighter_lid = lighter.find_child("LighterLid", true, false)
	if not lighter_flame and lighter:
		lighter_flame = lighter.find_child("LighterFlame", true, false)
	if not lighter_light and lighter:
		lighter_light = lighter.find_child("LighterLight", true, false)
	if not cigarette:
		cigarette = find_child("Cigarette", true, false)
	if not cig_paper and cigarette:
		cig_paper = cigarette.find_child("PaperMesh", true, false)
	if not tip_assembly and cigarette:
		tip_assembly = cigarette.find_child("TipAssembly", true, false)
	if not cig_tip and cigarette:
		cig_tip = cigarette.find_child("EmberTip", true, false)
	if not ash_tip and cigarette:
		ash_tip = cigarette.find_child("AshTip", true, false)
	if not ember_light and cigarette:
		ember_light = cigarette.find_child("EmberLight", true, false)
	if not smoke_particles and cigarette:
		smoke_particles = cigarette.find_child("SmokeParticles", true, false)
	if not exhale_smoke:
		exhale_smoke = find_child("ExhaleSmoke", true, false)
	if not cig_bar:
		cig_bar = find_child("CigBar", true, false)
	if not cig_label:
		cig_label = find_child("CigLabel", true, false)

func start_take_and_light_cigarette() -> void:
	ensure_smoking_references()
	if is_in_coma or current_anim != AnimState.NONE:
		return
	if smoking_seq_state == SmokingSeqState.TAKING_PACK or smoking_seq_state == SmokingSeqState.PULLING_CIG or smoking_seq_state == SmokingSeqState.LIGHTING_LIGHTER or smoking_seq_state == SmokingSeqState.IGNITING_TIP or smoking_seq_state == SmokingSeqState.PUTTING_AWAY:
		return # Already in progress
	
	smoking_seq_state = SmokingSeqState.TAKING_PACK
	seq_timer = 0.0
	cig_burn_factor = 1.0
	cig_is_lit = false
	is_inhaling = false
	puff_timer = 0.0
	
	reset_viewmodels()
	update_cigarette_mesh()
	
	if cig_pack:
		cig_pack.position = PACK_REST_POS
		cig_pack.rotation = PACK_REST_ROT
		cig_pack.visible = true
	if pack_lid:
		pack_lid.rotation.x = 0.0
	if ext_cig:
		ext_cig.position = Vector3(0, 0.035, 0)
		ext_cig.visible = true
	if lighter:
		lighter.position = LIGHTER_REST_POS
		lighter.rotation = LIGHTER_REST_ROT
		lighter.visible = false
	if lighter_lid:
		lighter_lid.rotation.z = 0.0
	if lighter_flame:
		lighter_flame.visible = false
	if lighter_light:
		lighter_light.visible = false
	if ash_tip:
		ash_tip.visible = false
	if cig_tip:
		var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
		if ember_mat:
			ember_mat.emission_energy_multiplier = 0.0
	if ember_light:
		ember_light.light_energy = 0.0
	
	print("🚬 Taking cigarette pack out to extract and light a fresh cigarette...")

func puff_cigarette() -> void:
	if not cig_is_lit or smoking_seq_state == SmokingSeqState.BURNT_OUT or is_in_coma or current_anim != AnimState.NONE:
		return
	
	smoking_seq_state = SmokingSeqState.PUFFING
	is_inhaling = true
	puff_timer = 0.85 # Hold at mouth / center-bottom during inhale drag
	
	# Burn down cigarette by ~6.5% per scroll click (~15 drags to finish)
	cig_burn_factor = max(0.0, cig_burn_factor - 0.065)
	
	# Inhaling drag refills the red coma bar (+12.5%) keeping player awake!
	buzz_meter = min(100.0, buzz_meter + 12.5)
	
	# Pacing: 1 full cigarette (~15 drags) only builds ~25-30% smoke total (+2.0% per drag).
	# This guarantees 1 cigarette does NOT feel dizzy! Takes chain-smoking >1 cigarette to feel dizzy!
	smoke_meter = min(100.0, smoke_meter + 2.0)
	
	# Ember flares with intense glowing heat
	if cig_tip:
		var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
		if ember_mat:
			ember_mat.emission_energy_multiplier = 24.0
	if ember_light:
		ember_light.light_energy = 8.0
	if smoke_particles and smoke_particles.is_inside_tree():
		smoke_particles.emitting = true
		smoke_particles.amount = 32
	
	# Visually shorten paper and move burning ember back towards filter
	update_cigarette_mesh()
	
	print("💨 Dragged cigarette with scroll wheel down! Remaining: %.0f%% | Red Bar (Buzz): %.1f%% | Smoke: %.1f%%" % [cig_burn_factor * 100.0, buzz_meter, smoke_meter])
	
	# Check if cigarette burnt down completely
	if cig_burn_factor <= 0.04:
		trigger_burnt_out()

func trigger_burnt_out() -> void:
	smoking_seq_state = SmokingSeqState.BURNT_OUT
	cig_is_lit = false
	cig_burn_factor = 0.0
	is_inhaling = false
	puff_timer = 0.0
	update_cigarette_mesh()
	
	# Ember turns to dark grey ash stub
	if cig_tip:
		var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
		if ember_mat:
			ember_mat.emission_energy_multiplier = 0.0
	if ember_light:
		ember_light.light_energy = 0.0
	if smoke_particles:
		smoke_particles.emitting = false
	if ash_tip:
		ash_tip.visible = true
	
	print("🚬 Cigarette burnt out! Use mouse scroll wheel DOWN or press [1] to light a new one.")

func update_cigarette_mesh() -> void:
	ensure_smoking_references()
	# Paper tube max length is 0.065m.
	# Scale along local Y shrinks the paper as cig_burn_factor decreases.
	if cig_paper:
		var scale_y = max(0.03, cig_burn_factor)
		cig_paper.scale.y = scale_y
		var curr_paper_len = 0.065 * scale_y
		cig_paper.position.z = -0.012 - (curr_paper_len / 2.0)
	
	if tip_assembly:
		var scale_y = max(0.03, cig_burn_factor)
		var curr_paper_len = 0.065 * scale_y
		tip_assembly.position.z = -0.012 - curr_paper_len

func update_smoking_sequence(delta: float) -> void:
	ensure_smoking_references()
	match smoking_seq_state:
		SmokingSeqState.TAKING_PACK:
			seq_timer += delta
			var t = clamp(seq_timer / 0.35, 0.0, 1.0)
			if cig_pack:
				cig_pack.position = PACK_REST_POS.lerp(PACK_UP_POS, ease(t, -2.0))
				cig_pack.rotation = PACK_REST_ROT.lerp(PACK_UP_ROT, t)
			if seq_timer >= 0.35:
				smoking_seq_state = SmokingSeqState.PULLING_CIG
				seq_timer = 0.0

		SmokingSeqState.PULLING_CIG:
			seq_timer += delta
			var t = clamp(seq_timer / 0.45, 0.0, 1.0)
			if pack_lid:
				pack_lid.rotation.x = lerp(0.0, deg_to_rad(-115.0), ease(t, -2.0))
			if ext_cig:
				ext_cig.position.y = lerp(0.035, 0.115, ease(t, -2.0))
			if seq_timer >= 0.45:
				# Cigarette taken from right hand, brought closer to screen at center & bit below center
				if cigarette:
					cigarette.position = CIG_LIGHTING_POS
					cigarette.rotation = CIG_LIGHTING_ROT
					cigarette.visible = true
				if ext_cig:
					ext_cig.visible = false
				if lighter:
					lighter.visible = true
					lighter.position = LIGHTER_REST_POS
					lighter.rotation = LIGHTER_REST_ROT
				smoking_seq_state = SmokingSeqState.LIGHTING_LIGHTER
				seq_timer = 0.0

		SmokingSeqState.LIGHTING_LIGHTER:
			seq_timer += delta
			var t = clamp(seq_timer / 0.45, 0.0, 1.0)
			if cig_pack:
				pack_lid.rotation.x = lerp(deg_to_rad(-115.0), 0.0, t)
				cig_pack.position = PACK_UP_POS.lerp(PACK_REST_POS, t)
			# Hold cigarette steady at screen center-bottom lighting position
			if cigarette:
				cigarette.position = CIG_LIGHTING_POS
				cigarette.rotation = CIG_LIGHTING_ROT
			# Right hand brings lighter up directly to cigarette tip
			if lighter:
				lighter.visible = true
				lighter.position = LIGHTER_REST_POS.lerp(LIGHTER_LIGHTING_POS, ease(t, -2.0))
				lighter.rotation = LIGHTER_REST_ROT.lerp(LIGHTER_LIGHTING_ROT, t)
			if lighter_lid and t >= 0.45:
				lighter_lid.rotation.z = lerp(0.0, deg_to_rad(105.0), (t - 0.45) / 0.55)
			if seq_timer >= 0.45:
				if cig_pack:
					cig_pack.visible = false
				if lighter_flame:
					lighter_flame.visible = true
				if lighter_light:
					lighter_light.visible = true
				smoking_seq_state = SmokingSeqState.IGNITING_TIP
				seq_timer = 0.0

		SmokingSeqState.IGNITING_TIP:
			seq_timer += delta
			var t = clamp(seq_timer / 0.55, 0.0, 1.0)
			if cigarette:
				cigarette.position = CIG_LIGHTING_POS
				cigarette.rotation = CIG_LIGHTING_ROT
			if lighter:
				lighter.position = LIGHTER_LIGHTING_POS
				lighter.rotation = LIGHTER_LIGHTING_ROT
			if cig_tip:
				var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
				if ember_mat:
					ember_mat.emission_energy_multiplier = lerp(2.0, 22.0, t)
			if ember_light:
				ember_light.light_energy = lerp(0.5, 5.0, t)
			if lighter_light:
				lighter_light.light_energy = 4.5 + sin(seq_timer * 20.0) * 0.8
			if smoke_particles and smoke_particles.is_inside_tree() and not smoke_particles.emitting:
				smoke_particles.emitting = true
			if seq_timer >= 0.55:
				if lighter_flame:
					lighter_flame.visible = false
				if lighter_light:
					lighter_light.visible = false
				smoking_seq_state = SmokingSeqState.PUTTING_AWAY
				seq_timer = 0.0

		SmokingSeqState.PUTTING_AWAY:
			seq_timer += delta
			var t = clamp(seq_timer / 0.40, 0.0, 1.0)
			if lighter_lid:
				lighter_lid.rotation.z = lerp(deg_to_rad(105.0), 0.0, ease(t, -2.0))
			if lighter:
				lighter.position = LIGHTER_LIGHTING_POS.lerp(LIGHTER_REST_POS, t)
				lighter.rotation = LIGHTER_LIGHTING_ROT.lerp(LIGHTER_REST_ROT, t)
			if cigarette:
				cigarette.position = CIG_LIGHTING_POS.lerp(CIG_HOLD_POS, ease(t, -2.0))
				cigarette.rotation = CIG_LIGHTING_ROT.lerp(CIG_HOLD_ROT, ease(t, -2.0))
			if cig_tip:
				var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
				if ember_mat:
					ember_mat.emission_energy_multiplier = lerp(22.0, 2.5, t)
			if ember_light:
				ember_light.light_energy = lerp(5.0, 1.0, t)
			if seq_timer >= 0.40:
				if lighter:
					lighter.visible = false
				cig_is_lit = true
				smoking_seq_state = SmokingSeqState.READY
				seq_timer = 0.0
				print("Cigarette lit! Use mouse scroll wheel DOWN to puff/smoke.")

		SmokingSeqState.PUFFING:
			# Brought closer again to center bottom of screen and smoked
			if cigarette:
				cigarette.position = cigarette.position.lerp(CIG_SMOKE_POS, delta * 14.0)
				cigarette.rotation = cigarette.rotation.lerp(CIG_SMOKE_ROT, delta * 14.0)
			puff_timer -= delta
			if puff_timer <= 0.0:
				is_inhaling = false
				smoking_seq_state = SmokingSeqState.EXHALING
				seq_timer = 0.65
				if exhale_smoke:
					exhale_smoke.restart()
				if cig_tip:
					var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
					if ember_mat:
						ember_mat.emission_energy_multiplier = 2.5
				if ember_light:
					ember_light.light_energy = 1.0
				if smoke_particles:
					smoke_particles.amount = 18

		SmokingSeqState.EXHALING:
			if cigarette:
				cigarette.position = cigarette.position.lerp(CIG_HOLD_POS, delta * 7.0)
				cigarette.rotation = cigarette.rotation.lerp(CIG_HOLD_ROT, delta * 7.0)
			seq_timer -= delta
			if seq_timer <= 0.0:
				smoking_seq_state = SmokingSeqState.READY

		SmokingSeqState.READY:
			if cigarette and current_anim == AnimState.NONE:
				cigarette.visible = true
				var sway = sin(fx_elapsed_time * 2.2) * 0.003
				cigarette.position = CIG_HOLD_POS + Vector3(0, sway, sway * 0.5)
				cigarette.rotation = CIG_HOLD_ROT
				if cig_tip:
					var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
					if ember_mat:
						ember_mat.emission_energy_multiplier = 2.0 + sin(fx_elapsed_time * 3.0) * 0.5

		SmokingSeqState.BURNT_OUT:
			if cigarette:
				cigarette.position = cigarette.position.lerp(CIG_BURNT_POS, delta * 6.0)
				cigarette.rotation = cigarette.rotation.lerp(CIG_BURNT_ROT, delta * 6.0)
				if cigarette.position.y <= -0.55:
					cigarette.visible = false

func start_drinking_animation() -> void:
	if current_anim != AnimState.NONE or is_in_coma:
		return
	current_anim = AnimState.DRINKING
	anim_timer = 0.0
	anim_duration = 3.8
	if cigarette and cig_is_lit:
		cigarette.visible = false
	if bottle:
		bottle.position = BOTTLE_REST_POS
		bottle.rotation = BOTTLE_REST_ROT
		bottle.visible = true

func start_sober_can_animation() -> void:
	if current_anim != AnimState.NONE or is_in_coma:
		return
	current_anim = AnimState.SOBER_CAN
	anim_timer = 0.0
	anim_duration = 3.2
	if cigarette and cig_is_lit:
		cigarette.visible = false
	if energy_can:
		energy_can.position = CAN_REST_POS
		energy_can.rotation = CAN_REST_ROT
		energy_can.visible = true

# ----------------- VEHICLE & NPC INTERACTION -----------------

func get_nearby_van() -> Node3D:
	if van_node and is_instance_valid(van_node):
		var dist = global_position.distance_to(van_node.global_position)
		if dist < 4.5 or is_inside_van:
			return van_node
	var van = get_tree().root.find_child("ParkedVan", true, false) as Node3D
	if van:
		van_node = van
		var dist = global_position.distance_to(van.global_position)
		if dist < 4.5 or is_inside_van:
			return van
	return null

func get_nearby_npc() -> Node:
	if is_inside_van:
		return null
	var npcs = get_tree().get_nodes_in_group("npcs")
	var closest_npc: Node = null
	var min_dist = 3.4
	var cam_forward = -camera.global_transform.basis.z if camera else -global_transform.basis.z

	for node in npcs:
		if not is_instance_valid(node):
			continue
		var to_npc = node.global_position - global_position
		var horiz_dist = Vector2(to_npc.x, to_npc.z).length()
		if horiz_dist < min_dist:
			var dir = to_npc.normalized()
			var dot = cam_forward.dot(dir)
			if dot > 0.15: # in front
				min_dist = horiz_dist
				closest_npc = node
	return closest_npc

func handle_interaction() -> void:
	var van = get_nearby_van()
	var npc = get_nearby_npc()

	# 1. If inside van or near van, prioritize Van Enter / Exit
	if is_inside_van and van:
		exit_van(van)
		return
	elif van and not npc:
		enter_van(van)
		return
	elif van and npc:
		# If closer to van than NPC, enter van
		var d_van = global_position.distance_to(van.global_position)
		var d_npc = global_position.distance_to(npc.global_position)
		if d_van < d_npc:
			enter_van(van)
			return

	# 2. If near Barney Darts NPC, open 3D Darts Challenge & Betting
	if npc and (npc.name == "NPC_Barney" or npc.get_meta("is_darts_npc", false)):
		_open_casino_minigame(0)
		return

	# 3. If near Antoine Roulette Croupier NPC, open 3D Roulette
	if npc and (npc.name == "NPC_Antoine" or npc.get_meta("is_roulette_npc", false)):
		_open_casino_minigame(3)
		return

	# 4. Otherwise talk to nearby NPC
	if npc and npc.has_method("talk"):
		current_talking_npc = npc
		var res: Dictionary = npc.talk()
		show_dialogue(res.get("name", "Stranger"), res.get("role", ""), res.get("text", "..."))
	elif dialogue_ui and dialogue_ui.visible:
		close_dialogue()

func enter_van(van: Node3D) -> void:
	is_inside_van = true
	# Teleport inside driver's seat looking out front windshield
	global_position = van.to_global(Vector3(-0.55, 0.40, -1.2))
	rotation.y = van.rotation.y + deg_to_rad(180.0)
	velocity = Vector3.ZERO
	if effect_badge:
		effect_badge.text = "Sitting in Van (Driver Seat) • Press [E] to Exit"

func exit_van(van: Node3D) -> void:
	is_inside_van = false
	# Step outside the open sliding side door
	global_position = van.to_global(Vector3(1.8, 0.0, 0.5))
	velocity = Vector3.ZERO
	if effect_badge:
		effect_badge.text = "Exited Van onto Parking Lot"

func show_dialogue(speaker: String, role: String, text: String) -> void:
	if not dialogue_ui:
		dialogue_ui = find_child("DialogueUI", true, false)
	if not dialogue_name_lbl:
		dialogue_name_lbl = find_child("SpeakerName", true, false)
	if not dialogue_text_lbl:
		dialogue_text_lbl = find_child("DialogueText", true, false)

	if dialogue_name_lbl:
		dialogue_name_lbl.text = "%s  •  %s" % [speaker, role] if role != "" else speaker
	if dialogue_text_lbl:
		dialogue_text_lbl.text = "\"%s\"" % text
	if dialogue_ui:
		dialogue_ui.visible = true
	dialogue_timer = 8.0

func close_dialogue() -> void:
	if dialogue_ui:
		dialogue_ui.visible = false
	current_talking_npc = null
	dialogue_timer = 0.0
	is_mouse_unlocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ----------------- COMA & GAME OVER (DISABLED PER USER REQUEST) -----------------

func trigger_coma() -> void:
	# Coma disabled per user request
	pass

# ----------------- PROCESS & METER UPDATES -----------------

func _process(delta: float) -> void:
	fx_elapsed_time += delta

	# Update active animations
	if current_anim != AnimState.NONE:
		anim_timer += delta
		update_viewmodel_animation(delta)
		if anim_timer >= anim_duration:
			finish_viewmodel_animation()

	# Update realistic smoking sequence & scroll-wheel puffing
	update_smoking_sequence(delta)

	# --- METER UPDATES ---
	# Player is always 100% drunk per user request
	drunk_meter = 100.0

	# Smoke Density Meter slowly clears
	smoke_meter = max(0.0, smoke_meter - SMOKE_DECAY_RATE * delta)

	# Energy boost timer
	if boost_timer > 0.0:
		boost_timer = max(0.0, boost_timer - delta)

	# Drunk Double-Image Camera Lag Tracking (Previous Frame Ghost Trail)
	if camera:
		var cur_cam_rot = Vector3(camera.rotation.x, rotation.y, camera.rotation.z)
		if lag_cam_rot == Vector3.ZERO:
			lag_cam_rot = cur_cam_rot

		# Smoothly lag behind current rotation by several frames
		lag_cam_rot = lag_cam_rot.lerp(cur_cam_rot, clampf(delta * 10.0, 0.05, 0.35))
		var delta_rot = cur_cam_rot - lag_cam_rot

		# Continuous drunken sway separation
		var sway_offset = Vector2(
			sin(fx_elapsed_time * 2.2) * 0.016,
			cos(fx_elapsed_time * 1.7) * 0.012
		)

		# Total ghost offset passed to screen shader
		ghost_offset = Vector2(delta_rot.y * 0.40, -delta_rot.x * 0.40) + sway_offset

	# Update Post-Processing Shader Parameters
	if screen_fx_rect and screen_fx_rect.material:
		var mat = screen_fx_rect.material as ShaderMaterial
		if mat:
			var dizzy_int = 0.0
			if smoke_meter > DIZZY_SMOKE_THRESHOLD:
				dizzy_int = clamp((smoke_meter - DIZZY_SMOKE_THRESHOLD) / (100.0 - DIZZY_SMOKE_THRESHOLD), 0.0, 1.0)

			var smoke_cloud_int = 0.0
			if smoke_meter > DIZZY_SMOKE_THRESHOLD:
				smoke_cloud_int = dizzy_int
			elif smoke_meter > 10.0:
				smoke_cloud_int = (smoke_meter / DIZZY_SMOKE_THRESHOLD) * 0.04

			var d_int = 1.0 # Fully drunk always

			mat.set_shader_parameter("smoke_intensity", smoke_cloud_int)
			mat.set_shader_parameter("dizzy_intensity", dizzy_int)
			mat.set_shader_parameter("drunk_intensity", d_int)
			mat.set_shader_parameter("ghost_offset", ghost_offset)
			mat.set_shader_parameter("blur_amount", 0.0032)
			mat.set_shader_parameter("double_vision_mix", 0.44)
			mat.set_shader_parameter("coma_fade", 0.0)
			mat.set_shader_parameter("fx_time", fx_elapsed_time)

	# Dynamic Camera Effects (Warping FOV & Sway)
	if camera:
		var dizzy_int = 0.0
		if smoke_meter > DIZZY_SMOKE_THRESHOLD:
			dizzy_int = clamp((smoke_meter - DIZZY_SMOKE_THRESHOLD) / (100.0 - DIZZY_SMOKE_THRESHOLD), 0.0, 1.0)

		# Smoking makes FOV breathe wildly only when dizzy (>1 cigarette smoked!)
		if dizzy_int > 0.05:
			var fov_pulse = sin(fx_elapsed_time * 3.5) * 14.0 * dizzy_int
			camera.fov = default_fov + fov_pulse
		else:
			camera.fov = lerp(camera.fov, default_fov, delta * 4.0)

		# Camera rolling sway from highness and drunkenness
		var roll = 0.0
		if dizzy_int > 0.05:
			roll += sin(fx_elapsed_time * 2.0) * 0.08 * dizzy_int
		roll += sin(fx_elapsed_time * 2.8) * 0.10
		if not is_stumbling and not is_fallen_down:
			camera.rotation.z = lerp(camera.rotation.z, roll, delta * 8.0)

	# Update Interaction Prompt Label
	update_interaction_prompt()

	# Dialogue UI auto-close
	if dialogue_ui and dialogue_ui.visible:
		dialogue_timer -= delta
		if dialogue_timer <= 0.0:
			close_dialogue()
		elif current_talking_npc and is_instance_valid(current_talking_npc):
			var dist = global_position.distance_to(current_talking_npc.global_position)
			if dist > 4.5:
				close_dialogue()

	# Update Meters on HUD
	update_meters_ui()

func update_interaction_prompt() -> void:
	if not interact_prompt_lbl:
		return
	if dialogue_ui and dialogue_ui.visible:
		interact_prompt_lbl.visible = false
		return

	var van = get_nearby_van()
	if is_inside_van:
		interact_prompt_lbl.text = "[E] Exit Van"
		interact_prompt_lbl.visible = true
		return
	elif van:
		var d_van = global_position.distance_to(van.global_position)
		if d_van < 3.8:
			interact_prompt_lbl.text = "[E] Enter Van"
			interact_prompt_lbl.visible = true
			return

	var npc = get_nearby_npc()
	if npc:
		if npc.name == "NPC_Barney" or npc.get_meta("is_darts_npc", false):
			interact_prompt_lbl.text = "🎯 [E] Play Darts with Barney (Bet Money)"
			interact_prompt_lbl.visible = true
			return
		var n_name = npc.get("character_name")
		if n_name == null or n_name == "":
			n_name = npc.name
		interact_prompt_lbl.text = "[E] Talk to %s" % n_name
		interact_prompt_lbl.visible = true
		return

	interact_prompt_lbl.visible = false

func update_viewmodel_animation(delta: float) -> void:
	match current_anim:
		AnimState.DRINKING:
			if bottle:
				var progress = anim_timer / anim_duration
				if progress < 0.22:
					# Raising bottle: nozzle tilts backward towards player's mouth!
					var t = progress / 0.22
					bottle.position = BOTTLE_REST_POS.lerp(BOTTLE_UP_POS, ease(t, -2.0))
					bottle.rotation = BOTTLE_REST_ROT.lerp(BOTTLE_UP_ROT, t)
				elif progress < 0.75:
					# Tilted back with nozzle pointing right at mouth, chugging bob
					var gulp = sin(anim_timer * 13.0) * 0.012
					bottle.position = BOTTLE_UP_POS + Vector3(0, gulp * 0.4, gulp * 0.8)
					bottle.rotation = BOTTLE_UP_ROT + Vector3(gulp * 2.0, 0, 0)
				else:
					# Lowering bottle back to rest
					var t = (progress - 0.75) / 0.25
					bottle.position = BOTTLE_UP_POS.lerp(BOTTLE_REST_POS, ease(t, 2.0))
					bottle.rotation = BOTTLE_UP_ROT.lerp(BOTTLE_REST_ROT, t)

		AnimState.SOBER_CAN:
			if energy_can:
				var progress = anim_timer / anim_duration
				if progress < 0.22:
					var t = progress / 0.22
					energy_can.position = CAN_REST_POS.lerp(CAN_UP_POS, ease(t, -2.0))
					energy_can.rotation = CAN_REST_ROT.lerp(CAN_UP_ROT, t)
				elif progress < 0.75:
					var gulp = sin(anim_timer * 14.0) * 0.012
					energy_can.position = CAN_UP_POS + Vector3(0, gulp, 0)
					energy_can.rotation = CAN_UP_ROT
				else:
					var t = (progress - 0.75) / 0.25
					energy_can.position = CAN_UP_POS.lerp(CAN_REST_POS, ease(t, 2.0))
					energy_can.rotation = CAN_UP_ROT.lerp(CAN_REST_ROT, t)

func finish_viewmodel_animation() -> void:
	match current_anim:
		AnimState.DRINKING:
			# Replenish Buzz stamina (+38%)
			buzz_meter = min(100.0, buzz_meter + 38.0)
			# Add to drunkenness meter
			drunk_meter = min(100.0, drunk_meter + 34.0)
			print("Drank Beer! Buzz: %.1f%% | Drunk Meter: %.1f%%" % [buzz_meter, drunk_meter])

		AnimState.SOBER_CAN:
			# Energy Drink boosts stamina to 100%, cures drunkenness and clears smoke!
			buzz_meter = 100.0
			drunk_meter = 0.0
			smoke_meter = 0.0
			boost_timer = 12.0
			print("Energy Drink! Sobered up & stamina restored to 100%!")

	current_anim = AnimState.NONE
	if bottle:
		bottle.visible = false
	if energy_can:
		energy_can.visible = false
	# If player had a lit cigarette with life remaining, restore it to hand!
	if cig_is_lit and cig_burn_factor > 0.05:
		if cigarette:
			cigarette.visible = true
			cigarette.position = CIG_HOLD_POS
			cigarette.rotation = CIG_HOLD_ROT
		smoking_seq_state = SmokingSeqState.READY

func update_meters_ui() -> void:
	# Update Red Coma Lifeline Bar (Buzz / Addiction Meter)
	if buzz_bar:
		buzz_bar.value = buzz_meter
	if buzz_label:
		if buzz_meter > 50.0:
			buzz_label.text = "🚨 COMA RED BAR: %.0f%% (Drain active! Keep smoking [1] or drinking [2] to prevent coma!)" % buzz_meter
			buzz_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		elif buzz_meter > 25.0:
			buzz_label.text = "⚠️ WARNING (%.0f%%) - RED BAR DROPPING! Smoke or drink now to stay awake!" % buzz_meter
			buzz_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.20))
		else:
			buzz_label.text = "🚨 CRITICAL (%.0f%%) - RED BAR EMPTYING! SMOKE OR DRINK RIGHT NOW OR GO TO COMA!" % buzz_meter
			var flash_col = Color(1.0, 0.1, 0.1) if fmod(fx_elapsed_time * 6.0, 2.0) > 1.0 else Color(1.0, 0.9, 0.9)
			buzz_label.add_theme_color_override("font_color", flash_col)

	# Update Drunk Meter
	if drunk_bar:
		drunk_bar.value = drunk_meter
	if drunk_label:
		if is_stumbling:
			drunk_label.text = "⚠️ RUNAWAY MOMENTUM! LOSING FOOTING AND FALLING!"
			drunk_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		elif drunk_momentum > 0.2:
			drunk_label.text = "⚠️ RUNAWAY MOMENTUM (%.0f%%) - SHIFT WASD KEYS TO KEEP FOOTING!" % (drunk_momentum * 100.0)
			drunk_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.15))
		elif step_shift_feedback_timer > 0.0:
			drunk_label.text = "👟 GOOD DRUNKEN STRIDE! Shifted step to [%s]" % _wasd_key_name(current_step_key)
			drunk_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45))
		else:
			drunk_label.text = "🍺 PERMANENTLY DRUNK • Alternate WASD keys while walking (Don't hold 1 key!)"
			drunk_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))

	# Update Smoke & Dizziness Meter
	if smoke_bar:
		smoke_bar.value = smoke_meter
	if smoke_label:
		if smoke_meter >= 75.0:
			smoke_label.text = "🚨 EXTREME DIZZINESS (%.0f%%) - HEAVY CHAIN-SMOKING! HARD TO SEE!" % smoke_meter
			smoke_label.add_theme_color_override("font_color", Color(0.9, 0.35, 1.0))
		elif smoke_meter >= 38.0:
			smoke_label.text = "😵 DIZZY SMOKE (%.0f%%) - Smoked >1 cigarette! Screen going weird..." % smoke_meter
			smoke_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
		else:
			smoke_label.text = "💨 SMOKE LEVEL: %.0f%% (1 Cigarette = Mild / Not Dizzy | Smoke >1 to get dizzy)" % smoke_meter
			smoke_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))

	# Update Cigarette Meter & Prompt
	if cig_bar:
		cig_bar.value = cig_burn_factor * 100.0
	if cig_label:
		match smoking_seq_state:
			SmokingSeqState.IDLE:
				cig_label.text = "🚬 CIGARETTE: None (Scroll Down or Press [1] to pull out pack & light)"
				cig_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
			SmokingSeqState.TAKING_PACK, SmokingSeqState.PULLING_CIG:
				cig_label.text = "🚬 CIGARETTE: Taking out fresh cigarette..."
				cig_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			SmokingSeqState.LIGHTING_LIGHTER, SmokingSeqState.IGNITING_TIP, SmokingSeqState.PUTTING_AWAY:
				cig_label.text = "🔥 CIGARETTE: Lighting with lighter at screen center..."
				cig_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
			SmokingSeqState.READY:
				cig_label.text = "🚬 CIGARETTE: %.0f%% | 🖱️ Scroll Down to Drag & Smoke" % [cig_burn_factor * 100.0]
				cig_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
			SmokingSeqState.PUFFING:
				cig_label.text = "🔥 INHALING... (Scroll Drag: Refills Red Coma Bar!) | Length: %.0f%%" % [cig_burn_factor * 100.0]
				cig_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.15))
			SmokingSeqState.EXHALING:
				cig_label.text = "💨 EXHALING SMOKE... | Length: %.0f%%" % [cig_burn_factor * 100.0]
				cig_label.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
			SmokingSeqState.BURNT_OUT:
				cig_label.text = "🚬 CIGARETTE FINISHED! Scroll Down or Press [1] to Light New One"
				cig_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))

	# Update Status badge
	if effect_badge:
		var badges: Array[String] = []
		if is_inside_van:
			badges.append("🚐 Inside Van")
		if smoking_seq_state == SmokingSeqState.PUFFING:
			badges.append("🔥 INHALING CIGARETTE (Refilling Red Bar)")
		elif smoking_seq_state == SmokingSeqState.READY:
			badges.append("🚬 CIGARETTE LIT")
		elif smoking_seq_state == SmokingSeqState.BURNT_OUT:
			badges.append("🚬 CIGARETTE FINISHED")
		elif current_anim == AnimState.DRINKING:
			badges.append("🍺 Drinking Beer (Refilling Red Bar)...")
		elif current_anim == AnimState.SOBER_CAN:
			badges.append("⚡ Energy Can...")

		if drunk_momentum > 0.35:
			badges.append("⚠️ MOMENTUM HIGH — SHIFT WASD STEP!")
		else:
			badges.append("🍺 DRUNK (Alternate WASD steps)")

		if smoke_meter >= 38.0:
			badges.append("💨 DIZZY SMOKE (SCREEN WEIRD)")

		if badges.size() > 0:
			effect_badge.text = " | ".join(badges)
		else:
			effect_badge.text = "Status: Awake • Normal"

# ----------------- PHYSICS & MOVEMENT -----------------

func _wasd_key_name(k: WASDKey) -> String:
	match k:
		WASDKey.W: return "W"
		WASDKey.A: return "A"
		WASDKey.S: return "S"
		WASDKey.D: return "D"
		_: return ""

func _trigger_runaway_stumble() -> void:
	if is_stumbling or is_fallen_down or is_inside_van or minigame_active:
		return
	is_stumbling = true
	stumble_timer = 0.75 # Runaway momentum stumble before losing footing
	var cam_fwd = -global_transform.basis.z
	stumble_direction = last_move_direction if last_move_direction != Vector3.ZERO else cam_fwd
	current_step_key = WASDKey.NONE
	key_hold_time = 0.0
	drunk_momentum = 1.0
	_play_sfx(&"clang")
	if interact_prompt_lbl:
		interact_prompt_lbl.text = "⚠️ RUNAWAY MOMENTUM! CAN'T STOP! LOSING BALANCE..."
		interact_prompt_lbl.visible = true

func _trigger_fall_down() -> void:
	is_stumbling = false
	is_fallen_down = true
	is_stunned = true
	fall_stun_timer = 1.8
	velocity = Vector3.ZERO
	_play_sfx(&"crash")
	_play_sfx(&"passout")
	if carried_part_idx != -1:
		_drop_carried_part()
	if interact_prompt_lbl:
		interact_prompt_lbl.text = "💥 FELL FLAT! Shift between WASD keys while walking to stay on your feet!"
		interact_prompt_lbl.visible = true

func _apply_step_climb(dir: Vector3, delta: float) -> void:
	if not is_on_floor() or dir == Vector3.ZERO:
		return
	var step_height: float = 0.42
	var test_dist: float = clampf(velocity.length() * delta + 0.14, 0.08, 0.28)
	var fwd_motion: Vector3 = dir.normalized() * test_dist
	if test_move(global_transform, fwd_motion):
		var up_step = Vector3(0, step_height, 0)
		if not test_move(global_transform, up_step):
			var up_trans = global_transform
			up_trans.origin.y += step_height
			if not test_move(up_trans, fwd_motion):
				global_position.y += step_height
				velocity.y = 0.0

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 1. Handle Fallen Down Flat State
	if is_fallen_down:
		fall_stun_timer -= delta
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		if camera:
			camera.rotation.z = lerpf(camera.rotation.z, deg_to_rad(65.0), 8.0 * delta)
		if head:
			head.position.y = lerpf(head.position.y, 0.35, 8.0 * delta)
		move_and_slide()
		if fall_stun_timer <= 0.0:
			is_fallen_down = false
			is_stunned = false
			if head:
				head.position.y = default_head_y
			if camera:
				camera.rotation.z = 0.0
				camera.rotation.x = deg_to_rad(6.0)
			if interact_prompt_lbl:
				interact_prompt_lbl.text = "★ Stumbled back to feet! Alternate WASD steps to keep your balance!"
				interact_prompt_lbl.visible = true
		return

	# 2. Handle Runaway Stumble Forward State
	if is_stumbling:
		stumble_timer -= delta
		var stumble_speed = walk_speed * 1.25
		velocity.x = stumble_direction.x * stumble_speed
		velocity.z = stumble_direction.z * stumble_speed

		# Camera pitch dips forward and shakes during drunken tumble
		if head:
			head.position.y = lerpf(head.position.y, default_head_y - 0.20, 8.0 * delta)
		if camera:
			camera.rotation.x = lerpf(camera.rotation.x, deg_to_rad(-16.0), 8.0 * delta)
			camera.rotation.z = sin(fx_elapsed_time * 16.0) * deg_to_rad(12.0)

		_apply_step_climb(stumble_direction, delta)
		move_and_slide()

		if stumble_timer <= 0.0:
			_trigger_fall_down()
		return

	# 3. Handle Jump
	var wants_jump = (Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)) and not minigame_active and not is_stunned and not is_ui_active() and not is_modal_dialog_open()
	var carried_mass = PART_MASS[carried_part_idx] if carried_part_idx != -1 else 0.0
	if wants_jump and is_on_floor() and carried_mass < 6.0:
		velocity.y = jump_velocity

	# Speed determination with carried weight penalty
	var is_sprinting = (Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)) and not is_stunned and not minigame_active and not is_ui_active() and not is_modal_dialog_open()
	var speed_penalty = clampf(1.0 - 0.03 * carried_mass, 0.45, 1.0)
	var current_speed = (sprint_speed if is_sprinting and carried_mass < 5.0 else walk_speed) * speed_penalty
	if boost_timer > 0.0:
		current_speed *= 1.25

	# 4. WASD Key Input & Drunken Key-Shift Rhythm Mechanics
	var pressed_keys: Array[WASDKey] = []
	if not minigame_active and not is_stunned and not is_ui_active() and not is_modal_dialog_open():
		if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			pressed_keys.append(WASDKey.W)
		if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			pressed_keys.append(WASDKey.A)
		if Input.is_action_pressed("move_backward") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			pressed_keys.append(WASDKey.S)
		if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			pressed_keys.append(WASDKey.D)

	if step_shift_feedback_timer > 0.0:
		step_shift_feedback_timer -= delta

	if pressed_keys.is_empty():
		# Key released!
		if current_step_key != WASDKey.NONE:
			# Player let go of the movement key they were walking with!
			# If held for too long (> 0.55s) or accumulated runaway momentum:
			# -> keeps going forward, loses balance, and falls!
			if key_hold_time >= 0.55 or drunk_momentum > 0.15:
				_trigger_runaway_stumble()
			else:
				# Quick tap release (< 0.55s) safely stops
				current_step_key = WASDKey.NONE
				key_hold_time = 0.0
				drunk_momentum = 0.0
	else:
		# One or more movement keys are pressed
		var is_shifted = false
		var new_step_key = current_step_key
		if current_step_key == WASDKey.NONE:
			new_step_key = pressed_keys[0]
			current_step_key = new_step_key
			key_hold_time = 0.0
		elif not pressed_keys.has(current_step_key):
			# Key changed!
			new_step_key = pressed_keys[0]
			is_shifted = true
		elif pressed_keys.size() > 1:
			# Shifted to another pressed key (e.g. while walking W, hit A or D)
			for pk in pressed_keys:
				if pk != current_step_key:
					new_step_key = pk
					is_shifted = true
					break

		if is_shifted:
			current_step_key = new_step_key
			key_hold_time = 0.0
			drunk_momentum = 0.0
			step_shift_feedback_timer = 0.55
			if effect_badge:
				effect_badge.text = "👟 Good Drunken Stride! Shifted step to [%s]" % _wasd_key_name(current_step_key)
		else:
			# Holding same key continuously
			key_hold_time += delta
			if key_hold_time > 0.75:
				drunk_momentum = clampf((key_hold_time - 0.75) / 0.75, 0.0, 1.0)

			# Held one single key for too long without shifting (> 1.6s) -> runaway stumble!
			if key_hold_time >= 1.6:
				_trigger_runaway_stumble()

	# 5. Raw input vector from pressed keys (Direct WASD: W=Forward, S=Down/Back, A=Left, D=Right)
	var raw_input = Vector2.ZERO
	if not minigame_active and not is_stunned and not is_ui_active() and not is_modal_dialog_open():
		for pk in pressed_keys:
			match pk:
				WASDKey.W: raw_input.y -= 1.0 # Forward
				WASDKey.S: raw_input.y += 1.0 # Down / Backward
				WASDKey.A: raw_input.x -= 1.0 # Left
				WASDKey.D: raw_input.x += 1.0 # Right
		raw_input = raw_input.normalized()

	# Relative movement oriented to camera yaw
	var direction = Vector3.ZERO
	if raw_input != Vector2.ZERO:
		direction = (transform.basis * Vector3(raw_input.x, 0, raw_input.y)).normalized()
		last_move_direction = direction

		# Runaway momentum adds forward pull
		var effective_speed = current_speed * (1.0 + drunk_momentum * 0.25)
		velocity.x = lerp(velocity.x, direction.x * effective_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * effective_speed, acceleration * delta)

		# Head bobbing
		if is_on_floor() and head:
			var speed_factor = effective_speed / walk_speed
			bob_timer += delta * bob_frequency * speed_factor
			head.position.y = lerpf(head.position.y, default_head_y + sin(bob_timer * TAU) * bob_amplitude, 10.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)
		if head:
			head.position.y = lerp(head.position.y, default_head_y, 10.0 * delta)
		bob_timer = 0.0

	# Drunken natural camera roll
	if camera and not is_stumbling and not is_fallen_down:
		var d_roll = sin(fx_elapsed_time * 2.2) * 0.06 + (drunk_momentum * sin(fx_elapsed_time * 6.5) * 0.12)
		camera.rotation.z = lerpf(camera.rotation.z, d_roll, 8.0 * delta)

	if direction != Vector3.ZERO:
		_apply_step_climb(direction, delta)
	move_and_slide()

	# Update Carried Part Physics, Aim Detection, Stations, and HUD
	_update_carried_part(delta)
	_detect_aimed_part()
	_detect_casino_station()
	_update_parts_hud(delta)

# ----------------- CAR PART HANDLING & MINIGAME IMPLEMENTATION -----------------

func _play_sfx(event: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(event)

func _detect_casino_station() -> void:
	active_station_idx = -1
	if minigame_active or carried_part_idx != -1 or is_stunned or is_fallen_down:
		return
	
	var eye = global_position
	var best_dist = 3.4
	
	for st in minigame_stations:
		if not st or not is_instance_valid(st) or not (st is Node3D):
			continue
		var d = eye.distance_to((st as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			active_station_idx = int(st.get_meta("station_idx", -1))
			if interact_prompt_lbl and aim_part_idx == -1:
				var lbl_txt = str(st.get_meta("label_text", "PLAY MINIGAME"))
				interact_prompt_lbl.text = "[E] " + lbl_txt
				interact_prompt_lbl.visible = true

func _open_casino_minigame(idx: int) -> void:
	if minigame_active:
		return
	print("Opening casino minigame for station %d..." % idx)
	minigame_active = true

	# Station 0: Full 3D Interactive Darts with Barney NPC & Wall Dartboard
	if idx == 0:
		_open_3d_darts_minigame()
		return

	# Station 3: Full 3D Interactive Roulette with Croupier Antoine & 3D Table
	if idx == 3:
		_open_3d_roulette_minigame()
		return

	if not shaky_holder:
		minigame_active = false
		return

	var mg: Control = null
	match idx:
		1:
			mg = CupPongScene.new()
		2:
			mg = SlotsScene.new()
		_:
			mg = CupPongScene.new()

	shaky_holder.add_child(mg)
	_play_sfx(&"clang")
	
	mg.connect("finished", func(won: bool):
		minigame_active = false
		is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if won:
			_on_minigame_won(idx)
		else:
			_on_minigame_lost(idx)
	)

func _open_3d_darts_minigame() -> void:
	var betting_dlg = DartsBettingDialogClass.new(player_money)
	var hud_node = get_node_or_null("HUD")
	if hud_node:
		hud_node.add_child(betting_dlg)
	else:
		add_child(betting_dlg)

	betting_dlg.cancelled.connect(func():
		minigame_active = false
		is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

	betting_dlg.bet_confirmed.connect(func(bet_amt: int):
		player_money = maxi(0, player_money - bet_amt)
		is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("Darts bet confirmed: $%d (Remaining cash: $%d)" % [bet_amt, player_money])
		
		# Find DartBoard3D and Barney NPC in the scene
		var board_node = get_tree().root.find_child("DartBoard3D", true, false)
		var barney_node = get_tree().root.find_child("NPC_Barney", true, false)
		
		var darts_session = Darts3DGameClass.new()
		add_child(darts_session)
		active_darts_3d = darts_session
		
		darts_session.start_darts_session(self, board_node, barney_node, bet_amt)
		
		darts_session.finished.connect(func(won_battery: bool, payout: int):
			minigame_active = false
			active_darts_3d = null
			is_mouse_unlocked = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if won_battery:
				_on_minigame_won(0)
			elif payout > 0:
				print("Won cash payout: $%d" % payout)
			else:
				print("Lost darts round!")
		)
	)

func _open_3d_roulette_minigame() -> void:
	var betting_dlg = RouletteBettingDialogClass.new(player_money)
	var hud_node = get_node_or_null("HUD")
	if hud_node:
		hud_node.add_child(betting_dlg)
	else:
		add_child(betting_dlg)

	betting_dlg.cancelled.connect(func():
		minigame_active = false
		is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

	betting_dlg.bet_confirmed.connect(func(bet_amt: int, bet_type: String, bet_param: Variant):
		player_money = maxi(0, player_money - bet_amt)
		is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("Roulette bet confirmed: $%d on %s (Remaining cash: $%d)" % [bet_amt, bet_type, player_money])
		
		# Find RouletteTable3D and Antoine NPC in the scene
		var table_node = get_tree().root.find_child("RouletteTable3D", true, false)
		var antoine_node = get_tree().root.find_child("NPC_Antoine", true, false)
		
		var roulette_session = Roulette3DGameClass.new()
		add_child(roulette_session)
		active_roulette_3d = roulette_session
		
		roulette_session.start_roulette_session(self, table_node, antoine_node, bet_amt, bet_type, bet_param)
		
		roulette_session.finished.connect(func(won_tyre: bool, payout: int):
			minigame_active = false
			active_roulette_3d = null
			is_mouse_unlocked = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if payout > 0:
				player_money += payout
				print("Won roulette cash payout: $%d" % payout)
			if won_tyre:
				_on_minigame_won(3)
			elif payout == 0:
				print("Lost roulette round!")
		)
	)

func _on_minigame_won(idx: int) -> void:
	print("🎉 Won casino minigame %d! Awarding %s!" % [idx, PART_NAMES[idx]])
	won_parts[idx] = true
	_play_sfx(&"win")
	_play_sfx(&"horn")
	
	if idx >= 0 and idx < _get_parts().size():
		_get_parts()[idx].state = PS.WORLD
	
	# Make physical world part visible at its station table
	var parts_root = _get_scavenge_parts_root()
	if parts_root:
		var p_node = parts_root.get_node_or_null("WorldPart_%d" % idx) as Node3D
		if p_node:
			p_node.visible = true
			var glow = p_node.find_child("BeaconGlow", true, false) as OmniLight3D
			if glow:
				glow.visible = true
				glow.light_energy = 3.5
	
	if interact_prompt_lbl:
		interact_prompt_lbl.text = "🎉 WON %s! Hold Right-Click or press [E] to carry it!" % PART_NAMES[idx]
		interact_prompt_lbl.visible = true

	if part_checklist:
		part_checklist.queue_redraw()

func _on_minigame_lost(idx: int) -> void:
	print("❌ Lost casino minigame %d" % idx)
	_play_sfx(&"part_fit_bad")
	if interact_prompt_lbl:
		interact_prompt_lbl.text = "❌ Didn't win! Press [E] to try again!"
		interact_prompt_lbl.visible = true

func _detect_aimed_part() -> void:
	aim_part_idx = -1
	var parts_root = _get_scavenge_parts_root()
	if carried_part_idx != -1 or is_stunned or is_fallen_down or not parts_root or not camera:
		return
	
	var best_dot: float = 0.72
	var eye = camera.global_position
	var fwd = -camera.global_transform.basis.z
	
	for i in 4:
		var part_node = parts_root.get_node_or_null("WorldPart_%d" % i) as Node3D
		if not part_node or not part_node.visible:
			continue
		var to_part = part_node.global_position - eye
		var dist = to_part.length()
		if dist > 3.8:
			continue
		var dot = fwd.dot(to_part.normalized())
		if dot > best_dot:
			best_dot = dot
			aim_part_idx = i

	if aim_part_idx != -1 and not minigame_active:
		if interact_prompt_lbl:
			interact_prompt_lbl.text = "Hold Right-Click / LMB or [E] to lift %s (%d kg)" % [PART_NAMES[aim_part_idx], int(PART_MASS[aim_part_idx])]
			interact_prompt_lbl.visible = true
	elif not minigame_active and active_station_idx == -1 and interact_prompt_lbl and not interact_prompt_lbl.text.begins_with("★") and not interact_prompt_lbl.text.begins_with("🚐") and not interact_prompt_lbl.text.begins_with("🟢") and not interact_prompt_lbl.text.begins_with("🎉"):
		interact_prompt_lbl.visible = false

func _lift_part(idx: int) -> void:
	if idx < 0 or idx >= 4:
		return
	print("Lifting car part %d: %s" % [idx, PART_NAMES[idx]])
	_play_sfx(&"clang")
	grab_cd = 0.4
	carried_part_idx = idx
	carried_reach = 1.0
	carried_rel_yaw = 0.0
	
	var parts_root = _get_scavenge_parts_root()
	var part_node = parts_root.get_node_or_null("WorldPart_%d" % idx) as Node3D if parts_root else null
	if part_node:
		carried_hp = part_node.global_position + Vector3(0, 0.4, 0)
		part_node.visible = false
	else:
		carried_hp = camera.global_position + camera.global_transform.basis * Vector3(0, -0.2, -1.0)
	carried_hv = Vector3.ZERO
	
	arm_strain = minf(1.0, arm_strain + 0.15 * (PART_MASS[idx] / 12.0))
	
	if idx < _get_parts().size():
		_get_parts()[idx].state = PS.CARRIED
	
	if carried_part_root:
		carried_part_root.visible = true
	for i in carried_meshes.size():
		carried_meshes[i].visible = (i == idx)

	if part_checklist:
		part_checklist.queue_redraw()

func _drop_carried_part() -> void:
	if carried_part_idx == -1:
		return
	var idx = carried_part_idx
	print("Dropping car part %d: %s" % [idx, PART_NAMES[idx]])
	_play_sfx(&"part_fell")
	
	var parts_root = _get_scavenge_parts_root()
	var part_node = parts_root.get_node_or_null("WorldPart_%d" % idx) as Node3D if parts_root else null
	if part_node:
		part_node.global_position = Vector3(carried_hp.x, 0.25, carried_hp.z)
		part_node.visible = true
		if idx < _get_parts().size():
			_get_parts()[idx].pos = part_node.global_position
			_get_parts()[idx].state = PS.WORLD
	
	if carried_part_root:
		carried_part_root.visible = false
	for m in carried_meshes:
		m.visible = false

	if idx < van_slots.size() and van_slots[idx]:
		var ghost = van_slots[idx].find_child("Ghost", true, false)
		if ghost:
			ghost.visible = false

	carried_part_idx = -1
	fit_q = -1.0
	grab_cd = 0.5

	if part_checklist:
		part_checklist.queue_redraw()

func _update_carried_part(delta: float) -> void:
	if carried_part_idx == -1:
		arm_strain = maxf(0.0, arm_strain - 0.20 * delta)
		if strain_bar:
			strain_bar.value = arm_strain * 100.0
		if strain_label:
			strain_label.text = "💪 ARM STRAIN: %d%% (Drop with Shift+Q if exhausted)" % int(arm_strain * 100.0)
		return
	
	var mass: float = PART_MASS[carried_part_idx]
	var ext: float = carried_reach - 0.6
	
	# Arm strain accumulation
	arm_strain = minf(1.0, arm_strain + mass * (0.007 + 0.010 * ext) * delta)
	if strain_bar:
		strain_bar.value = arm_strain * 100.0
	if strain_label:
		strain_label.text = "💪 ARM STRAIN: %d%% (%s %d kg - Drop with Shift+Q)" % [int(arm_strain * 100.0), PART_NAMES[carried_part_idx], int(mass)]
	
	# If arms give out or player falls down, drop part!
	if arm_strain >= 1.0 or is_fallen_down:
		_play_sfx(&"part_fell")
		if interact_prompt_lbl:
			interact_prompt_lbl.text = "⚠️ YOUR ARMS GAVE OUT! PART DROPPED!"
			interact_prompt_lbl.visible = true
		_drop_carried_part()
		return
	
	# Drunk tremor & sway
	var t: float = Time.get_ticks_msec() * 0.001
	var tremor: float = 0.015 + 0.07 * (drunk_meter / 100.0) + 0.08 * arm_strain * arm_strain
	var shake := Vector3(sin(t * 7.3), sin(t * 9.1 + 1.0), sin(t * 8.2 + 2.0)) * tremor
	
	# Target position in camera space
	var target: Vector3 = camera.global_transform * Vector3(0.0, -0.22, -carried_reach) + shake
	target.y -= arm_strain * 0.28
	
	# Heavy spring physics (mass inertia & trailing)
	var m_eff := 1.0 + 0.25 * mass
	var k := 65.0 / m_eff
	var accel := (target - carried_hp) * k - carried_hv * (2.0 * sqrt(k) * 0.82)
	carried_hv = (carried_hv + accel * delta).limit_length(10.0)
	carried_hp += carried_hv * delta
	carried_hp.y = maxf(carried_hp.y, 0.2)
	
	# Update carried viewmodel transform
	if carried_part_root and camera and camera.is_inside_tree():
		carried_part_root.visible = true
		var local_offset = camera.global_transform.affine_inverse() * carried_hp
		carried_part_root.position = local_offset
		carried_part_root.rotation.y = carried_rel_yaw + sin(t * 5.0) * tremor * 0.5
	
	# Slot check on Camper Van
	var slot_node = van_slots[carried_part_idx] if carried_part_idx < van_slots.size() else null
	if slot_node and slot_node.is_inside_tree():
		var slot_p = slot_node.global_position
		var d = carried_hp.distance_to(slot_p)
		var ghost = slot_node.find_child("Ghost", true, false) as MeshInstance3D
		if d < 2.5:
			fit_q = _calc_fit_q(carried_part_idx)
			if ghost:
				ghost.visible = true
				var mat = ghost.material_override as StandardMaterial3D
				if mat:
					# GREEN when >= 0.75, YELLOW when 0.45-0.75, RED when < 0.45
					var col = Color(0.9, 0.2, 0.2)
					if fit_q >= 0.75:
						col = Color(0.2, 0.98, 0.35) # Bright neon green!
					elif fit_q >= 0.45:
						col = Color(0.95, 0.75, 0.20) # Yellow / Orange
					mat.albedo_color = Color(col.r, col.g, col.b, 0.65)
					mat.emission = col
					mat.emission_energy_multiplier = 1.2 if fit_q >= 0.75 else 0.6
			if interact_prompt_lbl and not minigame_active:
				if fit_q >= 0.75:
					interact_prompt_lbl.text = "🟢 PERFECT FIT! Click Right-Click / LMB or [E] to bolt %s into Van!" % PART_NAMES[carried_part_idx]
				else:
					interact_prompt_lbl.text = "⚠️ Line up until GREEN to seat %s (Quality: %d%%)" % [PART_NAMES[carried_part_idx], int(fit_q * 100.0)]
				interact_prompt_lbl.visible = true
		else:
			fit_q = -1.0
			if ghost:
				ghost.visible = false

func _calc_fit_q(idx: int) -> float:
	var slot_node = van_slots[idx] if idx < van_slots.size() else null
	if not slot_node:
		return 0.0
	var slot_pos = slot_node.global_position
	var dist = carried_hp.distance_to(slot_pos)
	var pos_q = 1.0 - clampf(dist / 0.85, 0.0, 1.0)
	var speed_q = 1.0 - clampf(carried_hv.length() / 1.5, 0.0, 1.0)
	return clampf(pos_q * 0.7 + speed_q * 0.3, 0.0, 1.0)

func _seat_part_perfectly(part_idx: int) -> void:
	print("🟢 Seated part %d perfectly into Van!" % part_idx)
	_play_sfx(&"clang")
	_play_sfx(&"win")
	
	if part_idx >= 0 and part_idx < _get_parts().size():
		_get_parts()[part_idx].state = PS.INSTALLED
		_get_parts()[part_idx].q = 1.0

	if part_idx < van_slots.size() and van_slots[part_idx]:
		var inst_mesh = van_slots[part_idx].find_child("Installed", true, false)
		if inst_mesh:
			inst_mesh.visible = true
		var ghost_mesh = van_slots[part_idx].find_child("Ghost", true, false)
		if ghost_mesh:
			ghost_mesh.visible = false

	if carried_part_root:
		carried_part_root.visible = false
	for m in carried_meshes:
		m.visible = false

	carried_part_idx = -1
	fit_q = -1.0
	arm_strain = 0.0

	if interact_prompt_lbl:
		interact_prompt_lbl.text = "★ %s BOLTED SECURELY INTO VAN!" % PART_NAMES[part_idx]
		interact_prompt_lbl.visible = true

	_check_all_parts_installed()

func _seat_part_crooked(part_idx: int) -> void:
	print("⚠️ Crooked fit on part %d!" % part_idx)
	_play_sfx(&"part_fit_bad")
	_play_sfx(&"rattle")
	if interact_prompt_lbl:
		interact_prompt_lbl.text = "⚠️ Crooked fit! Line up until GREEN to seat properly!"
		interact_prompt_lbl.visible = true
	_drop_carried_part()

func _check_all_parts_installed() -> void:
	var count = 0
	for p in _get_parts():
		if p.state == PS.INSTALLED:
			count += 1
	if count >= 4:
		print("🎉 ALL 4 PARTS INSTALLED! Camper van is ready to drive!")
		_play_sfx(&"win")
		_play_sfx(&"horn")
		
		# Turn on camper van headlights!
		if van_root:
			for light in van_root.find_children("", "SpotLight3D", true, false):
				light.light_energy = 8.0
				light.visible = true
		
		if interact_prompt_lbl:
			interact_prompt_lbl.text = "🚐 ALL 4 PARTS SECURED! The Van is running!\nPress [E] at the driver door to escape home!"
			interact_prompt_lbl.visible = true

func _update_parts_hud(delta: float) -> void:
	if grab_cd > 0.0:
		grab_cd -= delta
	
	if part_crosshair:
		part_crosshair.strain = arm_strain
		part_crosshair.can_grab = (carried_part_idx == -1 and aim_part_idx != -1)
		part_crosshair.holding = (carried_part_idx != -1)
		part_crosshair.fit_q = fit_q

	if wallet_label:
		wallet_label.text = "$%d" % player_money
		if player_money < 50:
			wallet_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			wallet_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))

	if part_checklist:
		part_checklist.queue_redraw()

func show_victory_screen() -> void:
	if victory_ui:
		return
	print("🏆 SHOWING VICTORY SCREEN!")
	victory_ui = PanelContainer.new()
	victory_ui.name = "VictoryOverlay"
	victory_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg_box = StyleBoxFlat.new()
	bg_box.bg_color = Color(0.04, 0.06, 0.12, 0.88)
	bg_box.border_color = Color(0.98, 0.78, 0.25)
	bg_box.set_border_width_all(4)
	bg_box.set_corner_radius_all(18)
	victory_ui.add_theme_stylebox_override("panel", bg_box)
	
	var margin = MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 36)
	victory_ui.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "🎉 YOU MADE IT HOME!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.28))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "The Camper Van was rebuilt while high & drunk!\nAll 4 parts won from the Casino & fitted! Escaped safely!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	vbox.add_child(subtitle)
	
	var hsep = HSeparator.new()
	vbox.add_child(hsep)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)
	
	var menu_btn = Button.new()
	menu_btn.text = "🏠 Return to Home Screen [M]"
	menu_btn.custom_minimum_size = Vector2(240, 50)
	menu_btn.pressed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
	)
	btn_row.add_child(menu_btn)
	
	var replay_btn = Button.new()
	replay_btn.text = "🔄 Play Again [R]"
	replay_btn.custom_minimum_size = Vector2(200, 50)
	replay_btn.pressed.connect(func():
		get_tree().reload_current_scene()
	)
	btn_row.add_child(replay_btn)
	
	var hud_node = get_node_or_null("HUD")
	if hud_node:
		hud_node.add_child(victory_ui)
	else:
		add_child(victory_ui)
		
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_mouse_unlocked = true
