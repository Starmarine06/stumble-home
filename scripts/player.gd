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
# 1. Buzz / Addiction Meter (Must keep smoking or drinking, or fall into Coma!)
var buzz_meter: float = 100.0 # 100% full at start, drains over 40s
const BUZZ_DRAIN_RATE: float = 2.5 # ~40 seconds from full to coma if inactive

# 2. Drunkenness Meter (0-100%): Controls go opposite, at 60%+ MOUSE GOES OPPOSITE TOO!
var drunk_meter: float = 0.0
const DRUNK_DECAY_RATE: float = 1.2

# 3. Smoke Density / Weird High Meter (0-100%): Makes screen wavy & heavily clouded
var smoke_meter: float = 0.0
const SMOKE_DECAY_RATE: float = 2.0

# 4. Status Flags
var is_in_coma: bool = false
var coma_fade: float = 0.0
var is_inside_van: bool = false
var boost_timer: float = 0.0
var fx_elapsed_time: float = 0.0

# Active animation state
enum AnimState { NONE, SMOKING, DRINKING, SOBER_CAN }
var current_anim: AnimState = AnimState.NONE
var anim_timer: float = 0.0
var anim_duration: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = get_node_or_null("Head/Camera3D/Flashlight")

# Viewmodel references
@onready var viewmodel_root: Node3D = $Head/Camera3D/ViewModels
@onready var cigarette: Node3D = $Head/Camera3D/ViewModels/Cigarette
@onready var cig_tip: MeshInstance3D = $Head/Camera3D/ViewModels/Cigarette/EmberTip
@onready var smoke_particles: CPUParticles3D = $Head/Camera3D/ViewModels/Cigarette/SmokeParticles
@onready var bottle: Node3D = $Head/Camera3D/ViewModels/Bottle
@onready var energy_can: Node3D = $Head/Camera3D/ViewModels/EnergyCan

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

# Coma Overlay UI
@onready var coma_ui: Control = get_node_or_null("HUD/ComaUI")

# Interaction State
var current_talking_npc: Node = null
var dialogue_timer: float = 0.0
var van_node: Node3D = null

# Default rest positions for viewmodels
const CIG_REST_POS = Vector3(0.24, -0.38, -0.38)
const CIG_REST_ROT = Vector3(0.2, 0.4, 0.0)
const CIG_UP_POS = Vector3(0.09, -0.13, -0.26)
const CIG_UP_ROT = Vector3(0.5, 0.2, 0.1)

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

	# Mouse Click to re-capture
	if event is InputEventMouseButton and event.pressed:
		if is_mouse_unlocked:
			is_mouse_unlocked = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
		# 1: Smoking -> Replenishes buzz stamina (+35), increases smoke weirdness!
		elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			start_smoking_animation()

		# 2: Drinking -> Replenishes buzz stamina (+35), increases drunkenness!
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			start_drinking_animation()

		# 3: Energy Drink -> Sober Up (clears drunk and smoke, boosts stamina!)
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			start_sober_can_animation()

		# E: Interact (Enter/Exit Van OR Talk to NPC)
		elif event.keycode == KEY_E and not event.echo:
			handle_interaction()

# ----------------- ANIMATION TRIGGERS -----------------

func start_smoking_animation() -> void:
	if current_anim != AnimState.NONE or is_in_coma:
		return
	current_anim = AnimState.SMOKING
	anim_timer = 0.0
	anim_duration = 3.6
	reset_viewmodels()
	if cigarette:
		cigarette.visible = true

func start_drinking_animation() -> void:
	if current_anim != AnimState.NONE or is_in_coma:
		return
	current_anim = AnimState.DRINKING
	anim_timer = 0.0
	anim_duration = 3.8
	reset_viewmodels()
	if bottle:
		bottle.visible = true

func start_sober_can_animation() -> void:
	if current_anim != AnimState.NONE or is_in_coma:
		return
	current_anim = AnimState.SOBER_CAN
	anim_timer = 0.0
	anim_duration = 3.2
	reset_viewmodels()
	if energy_can:
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
			var s_int = smoke_meter / 100.0
			var d_int = drunk_meter / 100.0
			# Drowsy blackout flash when buzz is critically low
			var drowsy_pulse = 0.0
			if buzz_meter < 25.0:
				drowsy_pulse = (sin(fx_elapsed_time * 4.0) * 0.5 + 0.5) * (1.0 - buzz_meter / 25.0) * 0.65

			mat.set_shader_parameter("smoke_intensity", s_int)
			mat.set_shader_parameter("dizzy_intensity", s_int)
			mat.set_shader_parameter("drunk_intensity", d_int)
			mat.set_shader_parameter("coma_fade", drowsy_pulse)
			mat.set_shader_parameter("fx_time", fx_elapsed_time)

	# Dynamic Camera Effects (Warping FOV & Sway)
	if camera:
		var s_int = smoke_meter / 100.0
		var d_int = drunk_meter / 100.0
		
		# Smoking makes FOV breathe wildly
		if s_int > 0.05:
			var fov_pulse = sin(fx_elapsed_time * 3.5) * 14.0 * s_int
			camera.fov = default_fov + fov_pulse
		else:
			camera.fov = lerp(camera.fov, default_fov, delta * 4.0)

		# Camera rolling sway from highness and drunkenness
		var roll = 0.0
		if s_int > 0.05:
			roll += sin(fx_elapsed_time * 2.0) * 0.08 * s_int
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
		AnimState.SMOKING:
			if cigarette:
				var progress = anim_timer / anim_duration
				if progress < 0.25:
					# Raising cigarette to mouth
					var t = progress / 0.25
					cigarette.position = CIG_REST_POS.lerp(CIG_UP_POS, ease(t, -2.0))
					cigarette.rotation = CIG_REST_ROT.lerp(CIG_UP_ROT, t)
				elif progress < 0.70:
					# Holding at mouth, drag (ember glows brighter, smoke starts)
					cigarette.position = CIG_UP_POS
					cigarette.rotation = CIG_UP_ROT
					if cig_tip:
						var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
						if ember_mat:
							ember_mat.emission_energy_multiplier = 14.0
					if smoke_particles and not smoke_particles.emitting:
						smoke_particles.emitting = true
				else:
					# Lowering cigarette
					var t = (progress - 0.70) / 0.30
					cigarette.position = CIG_UP_POS.lerp(CIG_REST_POS, ease(t, 2.0))
					cigarette.rotation = CIG_UP_ROT.lerp(CIG_REST_ROT, t)
					if cig_tip:
						var ember_mat = cig_tip.get_surface_override_material(0) as StandardMaterial3D
						if ember_mat:
							ember_mat.emission_energy_multiplier = 4.0

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
		AnimState.SMOKING:
			# Replenish Buzz stamina (+35%) to prevent falling asleep!
			buzz_meter = min(100.0, buzz_meter + 38.0)
			# Add to smoke meter (makes screen weird, clouded & hard to see!)
			smoke_meter = min(100.0, smoke_meter + 35.0)
			print("Smoked! Buzz: %.1f%% | Smoke Density: %.1f%%" % [buzz_meter, smoke_meter])

		AnimState.DRINKING:
			# Replenish Buzz stamina (+35%) to prevent falling asleep!
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
	reset_viewmodels()

func update_meters_ui() -> void:
	# Update Buzz / Awake Meter
	if buzz_bar:
		buzz_bar.value = buzz_meter
	if buzz_label:
		if buzz_meter > 35.0:
			buzz_label.text = "AWAKE / BUZZ STAMINA: %.0f%% (Keep smoking or drinking to avoid coma!)" % buzz_meter
			buzz_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		else:
			buzz_label.text = "🚨 DROWSY / CRITICAL (%.0f%%) - SMOKE [1] OR DRINK [2] NOW OR ENTER COMA!" % buzz_meter
			buzz_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

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

	# Update Smoke Meter
	if smoke_bar:
		smoke_bar.value = smoke_meter
	if smoke_label:
		if smoke_meter > 50.0:
			smoke_label.text = "💨 SMOKE CLOUD DENSITY: %.0f%% (HEAVY SMOKE - HARD TO SEE!)" % smoke_meter
			smoke_label.add_theme_color_override("font_color", Color(0.85, 0.45, 1.0))
		else:
			smoke_label.text = "SMOKE DENSITY: %.0f%%" % smoke_meter
			smoke_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))

	# Update Status badge
	if effect_badge:
		var badges: Array[String] = []
		if is_inside_van:
			badges.append("🚐 Inside Van")
		if current_anim == AnimState.SMOKING:
			badges.append("🚬 Smoking...")
		elif current_anim == AnimState.DRINKING:
			badges.append("🍺 Drinking Beer...")
		elif current_anim == AnimState.SOBER_CAN:
			badges.append("⚡ Energy Can...")

		if drunk_meter >= 60.0:
			badges.append("🚨 MOUSE & WASD INVERTED")
		elif drunk_meter >= 30.0:
			badges.append("⚠️ WASD INVERTED")

		if smoke_meter > 50.0:
			badges.append("💨 SCREEN WEIRD & CLOUDED")

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
