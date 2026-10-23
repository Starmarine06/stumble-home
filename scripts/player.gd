extends CharacterBody3D

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
# 1. Coma Lifeline Red Bar (Must keep smoking or drinking, or fall into Coma!)
var buzz_meter: float = 100.0 # 100% full at start, drains over 40s if inactive
const BUZZ_DRAIN_RATE: float = 2.5 # ~40 seconds from full to coma if inactive

# 2. Drunkenness Meter (0-100%): Controls go opposite, at 60%+ MOUSE GOES OPPOSITE TOO!
var drunk_meter: float = 0.0
const DRUNK_DECAY_RATE: float = 1.2

# 3. Smoke Density / Dizziness Meter (0-100%):
# Within 1 cigarette player NEVER feels dizzy (max ~25-30%); takes >1 cigarette to feel dizzy!
var smoke_meter: float = 0.0
const SMOKE_DECAY_RATE: float = 1.0
const DIZZY_SMOKE_THRESHOLD: float = 38.0 # Dizziness & weird screen effects require smoking >1 cigarette!

# 4. Status Flags
var is_in_coma: bool = false
var coma_fade: float = 0.0
var is_inside_van: bool = false
var boost_timer: float = 0.0
var fx_elapsed_time: float = 0.0

# Active drink animation state
enum AnimState { NONE, DRINKING, SOBER_CAN }
var current_anim: AnimState = AnimState.NONE
var anim_timer: float = 0.0
var anim_duration: float = 0.0

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

	reset_viewmodels()

	if dialogue_ui:
		dialogue_ui.visible = false
	if interact_prompt_lbl:
		interact_prompt_lbl.visible = false
	if coma_ui:
		coma_ui.visible = false

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

func _input(event: InputEvent) -> void:
	# Coma Restart Handling
	if is_in_coma:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R or event.keycode == KEY_SPACE:
				print("Restarting game after coma...")
				get_tree().reload_current_scene()
		return

	# Mouse Look (360-degree yaw & pitch)
	if event is InputEventMouseMotion:
		if not is_mouse_unlocked:
			# When heavily drunk (drunk_meter >= 60%), MOUSE CONTROLS GO COMPLETELY OPPOSITE!
			var mouse_invert = -1.0 if drunk_meter >= 60.0 else 1.0
			
			# Horizontal 360-degree yaw
			rotate_y(-event.relative.x * mouse_sensitivity * mouse_invert)
			
			# Vertical pitch
			if head:
				head.rotate_x(-event.relative.y * mouse_sensitivity * mouse_invert)
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	# Mouse Click to re-capture & Mouse Scroll Wheel to Smoke
	if event is InputEventMouseButton and event.pressed:
		if is_mouse_unlocked:
			is_mouse_unlocked = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# --- MOUSE SCROLL WHEEL SMOKING CONTROL ---
		# Scrolling wheel down brings cigarette to center bottom of screen & smokes it!
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			handle_mouse_wheel_down_smoke()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			handle_mouse_wheel_down_smoke()

	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			is_mouse_unlocked = not is_mouse_unlocked
			if is_mouse_unlocked:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Flashlight Toggle
		elif event.keycode == KEY_F or event.is_action_pressed("toggle_flashlight"):
			if flashlight:
				flashlight.visible = not flashlight.visible
		
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

		# E: Interact (Enter/Exit Van OR Talk to NPC)
		elif event.keycode == KEY_E and not event.echo:
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

	# 2. Otherwise talk to nearby NPC
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

# ----------------- COMA & GAME OVER -----------------

func trigger_coma() -> void:
	if is_in_coma:
		return
	is_in_coma = true
	velocity = Vector3.ZERO
	print("!!! PLAYER FELL ASLEEP AND ENTERED A COMA !!!")
	
	# Camera collapses to floor
	if head:
		head.rotation.x = deg_to_rad(-65.0)
		head.position.y = 0.25

	if not coma_ui:
		coma_ui = find_child("ComaUI", true, false)
	if coma_ui:
		coma_ui.visible = true
	if interact_prompt_lbl:
		interact_prompt_lbl.visible = false

# ----------------- PROCESS & METER UPDATES -----------------

func _process(delta: float) -> void:
	fx_elapsed_time += delta

	# Coma State Handling
	if is_in_coma:
		coma_fade = min(1.0, coma_fade + delta * 2.0)
		if screen_fx_rect and screen_fx_rect.material:
			var mat = screen_fx_rect.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("coma_fade", coma_fade)
				mat.set_shader_parameter("fx_time", fx_elapsed_time)
		return

	# Update active animations
	if current_anim != AnimState.NONE:
		anim_timer += delta
		update_viewmodel_animation(delta)
		if anim_timer >= anim_duration:
			finish_viewmodel_animation()

	# Update realistic smoking sequence & scroll-wheel puffing
	update_smoking_sequence(delta)

	# --- METER DRAINS & DECAYS ---
	# 1. Buzz / Addiction Meter: Constantly drains unless smoking or drinking!
	buzz_meter = max(0.0, buzz_meter - BUZZ_DRAIN_RATE * delta)
	if buzz_meter <= 0.0:
		trigger_coma()
		return

	# 2. Drunk Meter slowly decays
	drunk_meter = max(0.0, drunk_meter - DRUNK_DECAY_RATE * delta)

	# 3. Smoke Density Meter slowly clears
	smoke_meter = max(0.0, smoke_meter - SMOKE_DECAY_RATE * delta)

	# 4. Energy boost timer
	if boost_timer > 0.0:
		boost_timer = max(0.0, boost_timer - delta)

	# Update Post-Processing Shader Parameters
	if screen_fx_rect and screen_fx_rect.material:
		var mat = screen_fx_rect.material as ShaderMaterial
		if mat:
			# Dizziness & weird screen distortion only trigger when smoke_meter > DIZZY_SMOKE_THRESHOLD (38.0%).
			# Within 1 cigarette (peak ~25%), dizzy_intensity is strictly 0.0 -> NO dizziness!
			# Takes smoking >1 cigarette to feel dizzy!
			var dizzy_int = 0.0
			if smoke_meter > DIZZY_SMOKE_THRESHOLD:
				dizzy_int = clamp((smoke_meter - DIZZY_SMOKE_THRESHOLD) / (100.0 - DIZZY_SMOKE_THRESHOLD), 0.0, 1.0)

			var smoke_cloud_int = 0.0
			if smoke_meter > DIZZY_SMOKE_THRESHOLD:
				smoke_cloud_int = dizzy_int
			elif smoke_meter > 10.0:
				smoke_cloud_int = (smoke_meter / DIZZY_SMOKE_THRESHOLD) * 0.04 # Subtle wisp only

			var d_int = drunk_meter / 100.0
			# Drowsy blackout flash when the red coma bar is critically low (< 30%)
			var drowsy_pulse = 0.0
			if buzz_meter < 30.0:
				drowsy_pulse = (sin(fx_elapsed_time * 5.0) * 0.5 + 0.5) * (1.0 - buzz_meter / 30.0) * 0.75

			mat.set_shader_parameter("smoke_intensity", smoke_cloud_int)
			mat.set_shader_parameter("dizzy_intensity", dizzy_int)
			mat.set_shader_parameter("drunk_intensity", d_int)
			mat.set_shader_parameter("coma_fade", drowsy_pulse)
			mat.set_shader_parameter("fx_time", fx_elapsed_time)

	# Dynamic Camera Effects (Warping FOV & Sway)
	if camera:
		var dizzy_int = 0.0
		if smoke_meter > DIZZY_SMOKE_THRESHOLD:
			dizzy_int = clamp((smoke_meter - DIZZY_SMOKE_THRESHOLD) / (100.0 - DIZZY_SMOKE_THRESHOLD), 0.0, 1.0)
		var d_int = drunk_meter / 100.0
		
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
		if d_int > 0.05:
			roll += sin(fx_elapsed_time * 2.8) * 0.16 * d_int
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
		if drunk_meter >= 60.0:
			drunk_label.text = "🚨 EXTREME DRUNK (%.0f%%) - MOUSE & WASD CONTROLS INVERTED!" % drunk_meter
			drunk_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.2))
		elif drunk_meter >= 30.0:
			drunk_label.text = "⚠️ DRUNK (%.0f%%) - WASD MOVEMENT INVERTED!" % drunk_meter
			drunk_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		else:
			drunk_label.text = "DRUNKENNESS METER: %.0f%% (Sober / Mild Buzz)" % drunk_meter
			drunk_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))

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

		if buzz_meter < 25.0:
			badges.append("🚨 RED BAR CRITICAL - COMA IMMINENT")

		if drunk_meter >= 60.0:
			badges.append("🚨 MOUSE & WASD INVERTED")
		elif drunk_meter >= 30.0:
			badges.append("⚠️ WASD INVERTED")

		if smoke_meter >= 38.0:
			badges.append("💨 DIZZY SMOKE (SCREEN WEIRD)")

		if badges.size() > 0:
			effect_badge.text = " | ".join(badges)
		else:
			effect_badge.text = "Status: Awake • Normal"

# ----------------- PHYSICS & MOVEMENT -----------------

func _physics_process(delta: float) -> void:
	if is_in_coma:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump
	var wants_jump = Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)
	if wants_jump and is_on_floor():
		velocity.y = jump_velocity

	# Determine current speed
	var is_sprinting = Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	var current_speed = sprint_speed if is_sprinting else walk_speed
	if boost_timer > 0.0:
		current_speed *= 1.25

	# Raw input direction from WASD / Arrows
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_backward") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	# --- DRUNK INVERTED CONTROLS ---
	# When drunk_meter >= 30%, WASD controls go completely opposite!
	if drunk_meter >= 30.0:
		input_dir = -input_dir # W goes backward, S forward, A right, D left!

	input_dir = input_dir.normalized()
	# Relative movement oriented to camera yaw
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Add drunk stumble drift
	if drunk_meter >= 30.0 and direction != Vector3.ZERO:
		var d_fact = drunk_meter / 100.0
		var stumble_x = sin(fx_elapsed_time * 3.2) * 0.45 * d_fact
		var stumble_z = cos(fx_elapsed_time * 2.6) * 0.45 * d_fact
		direction = (direction + transform.basis * Vector3(stumble_x, 0, stumble_z)).normalized()

	# Acceleration & deceleration
	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
		
		# Head bobbing
		if is_on_floor() and head:
			var speed_factor = current_speed / walk_speed
			bob_timer += delta * bob_frequency * speed_factor
			head.position.y = default_head_y + sin(bob_timer * TAU) * bob_amplitude
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)
		if head:
			head.position.y = lerp(head.position.y, default_head_y, 10.0 * delta)
		bob_timer = 0.0

	move_and_slide()
