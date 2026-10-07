extends Node3D
## Live opening prototype. One owner for input, timeline, skip and morning release.
const DURATION := 32.0
var elapsed := 0.0
var state := "night"
var world: Node3D
var actor: CharacterBody3D
var home: Node3D
var bed: Node3D
var clock: GameTimeSystem
var camera: Camera3D
var shade: ColorRect
var subtitle: Label
var hint: Label
var top_bar: ColorRect
var bottom_bar: ColorRect
var lamp: Node3D
var light: OmniLight3D
var match_prop: MeshInstance3D
var match_light: OmniLight3D
var visual: Node3D
var disabled_inputs: Array[Node] = []
var disabled_physics: Array[Node] = []
var hidden_layers: Array[CanvasLayer] = []
var previous_clock_pause := false
var previous_physics := true
var rise_time := 0.0
var previous_position := Vector3.ZERO
var environment: Environment
var ambient_energy := 0.0
var murmur: AudioStreamPlayer3D
var murmur_played := false
var sigh_audio: AudioStreamPlayer3D
var sigh_played := false
var contact = preload("res://story/opening_contact.gd").new()
var expression = preload("res://story/opening_expression.gd").new()

func start(target_world: Node3D) -> void:
	world = target_world
	actor = world.get_node("Player")
	bed = world.get_node("Charpai")
	clock = world.get_node("GameTimeSystem")
	for candidate in get_tree().get_nodes_in_group("arjun_home"):
		if world.is_ancestor_of(candidate): home = candidate; break
	if home == null:
		push_error("Opening requires the furnished Arjun home")
		queue_free()
		return
	process_priority = 100
	visual = actor.get_node("VisualRoot/CharacterVisual")
	expression.configure(visual.model)
	previous_physics = actor.is_physics_processing()
	actor.set_physics_process(false)
	actor.set_meta("opening_active", true)
	for node in world.find_children("*", "Node", true, false):
		if node == self or is_ancestor_of(node): continue
		if node.is_processing_unhandled_input():
			disabled_inputs.append(node)
			node.set_process_unhandled_input(false)
		if node is CanvasLayer and node.visible:
			hidden_layers.append(node)
			node.hide()
	for node in actor.find_children("*", "Node", true, false):
		if visual.is_ancestor_of(node) or node == visual: continue
		if node.is_physics_processing():
			disabled_physics.append(node)
			node.set_physics_process(false)
	previous_clock_pause = clock.clock_paused
	clock.clock_paused = true
	clock.total_game_minutes = 22 * 60
	clock._update_readable_time(true)
	environment = world.get_node("WorldEnvironment").environment
	ambient_energy = environment.ambient_light_energy
	environment.ambient_light_energy = 0.015
	if visual.equipment != null:
		visual.equipment.stowed = true
		visual.equipment._refresh()
	camera = Camera3D.new()
	camera.fov = 48
	add_child(camera)
	camera.make_current()
	_build_lamp()
	_build_overlay()
	murmur = AudioStreamPlayer3D.new()
	murmur.stream = load("res://assets/audio/opening/arjun_murmur_draft.wav")
	murmur.volume_db = -12.0
	murmur.max_distance = 8.0
	actor.add_child(murmur)
	murmur.position = Vector3(0,0.70,0)
	sigh_audio = AudioStreamPlayer3D.new()
	sigh_audio.stream = load("res://assets/audio/opening/arjun_sigh_draft.wav")
	sigh_audio.volume_db = -6.0
	sigh_audio.max_distance = 8.0
	actor.add_child(sigh_audio)
	sigh_audio.position = Vector3(0,.70,0)
	_place(Vector3(-2.6, 1.14, 1.50), PI)
	previous_position = actor.global_position

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	shade = ColorRect.new()
	shade.color = Color.BLACK
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	top_bar = ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.12
	layer.add_child(top_bar)
	bottom_bar = ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.anchor_top = 0.88
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	layer.add_child(bottom_bar)
	subtitle = Label.new()
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.anchor_top = 0.88
	subtitle.offset_top = 0
	subtitle.offset_bottom = 0
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(subtitle)
	hint = Label.new()
	hint.text = ""
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -220
	hint.offset_top = -45
	layer.add_child(hint)

func _build_lamp() -> void:
	# Oil-wick burner inside an original simple framed lantern candidate.
	lamp = preload("res://objects/household/oil_lamp_visual.tscn").instantiate()
	home.add_child(lamp)
	lamp.name = "OpeningOilLamp"
	lamp.position = Vector3(-2.6, 0.96, 0.70)
	var table := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.65, 0.08, 0.55)
	table.mesh = mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22,0.13,0.07)
	table.material_override = wood
	home.add_child(table)
	table.position = Vector3(-2.6,0.91,0.70)
	for x in [-0.25,0.25]:
		for z in [-0.20,0.20]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.055,0.63,0.055)
			leg.mesh = leg_mesh
			leg.material_override = wood
			table.add_child(leg)
			leg.position = Vector3(x,-0.35,z)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.23,0.16,0.08)
	metal.metallic = 0.65
	metal.roughness = 0.55
	for x in [-0.22,0.22]:
		for z in [-0.10,0.30]:
			var upright := MeshInstance3D.new()
			var upright_mesh := BoxMesh.new()
			upright_mesh.size = Vector3(0.015,0.43,0.015)
			upright.mesh = upright_mesh
			upright.material_override = metal
			lamp.add_child(upright)
			upright.position = Vector3(x,0.23,z)
	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.48,0.025,0.44)
	cap.mesh = cap_mesh
	cap.material_override = metal
	lamp.add_child(cap)
	cap.position = Vector3(0,0.45,0.10)
	var handle := MeshInstance3D.new()
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = .085
	handle_mesh.outer_radius = .098
	handle_mesh.rings = 12
	handle_mesh.ring_segments = 6
	handle.mesh = handle_mesh
	handle.material_override = metal
	lamp.add_child(handle)
	handle.rotation.x = PI/2
	handle.position = Vector3(-.15,.50,.10)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.8,0.75,0.65,0.08)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for z in [-0.10,0.30]:
		var pane := MeshInstance3D.new()
		var pane_mesh := PlaneMesh.new()
		pane_mesh.size = Vector2(0.43,0.40)
		pane.mesh = pane_mesh
		pane.material_override = glass
		lamp.add_child(pane)
		pane.rotation.x = PI/2
		pane.position = Vector3(0,0.23,z)
	var collider := StaticBody3D.new()
	table.add_child(collider)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape_node.shape = box
	collider.add_child(shape_node)
	light = OmniLight3D.new()
	lamp.add_child(light)
	light.position = Vector3(0,0.13,0.18)
	light.light_color = Color(1,0.52,0.18)
	light.omni_range = 5.5
	light.shadow_enabled = true
	light.light_energy = 0
	lamp.get_node("Flame").hide()
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "hand_r"
	visual.skeleton.add_child(attachment)
	match_prop = MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.002
	stick.bottom_radius = 0.002
	stick.height = 0.055
	stick.radial_segments = 6
	stick.rings = 0
	match_prop.mesh = stick
	var match_wood := StandardMaterial3D.new()
	match_wood.albedo_color = Color(.55,.36,.16)
	match_wood.roughness = .95
	match_prop.material_override = match_wood
	add_child(match_prop)
	attachment.queue_free()
	match_prop.position = Vector3(0,0.035,0)
	var match_flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.008
	flame_mesh.height = 0.026
	match_flame.mesh = flame_mesh
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color(1,0.55,0.08)
	fire.emission_enabled = true
	fire.emission = Color(1,0.35,0.02)
	fire.emission_energy_multiplier = 3.0
	match_flame.material_override = fire
	match_flame.name = "Flame"
	match_prop.add_child(match_flame)
	match_flame.position.y = 0.038
	match_light = OmniLight3D.new()
	match_prop.add_child(match_light)
	match_light.position.y = 0.027
	match_light.light_color = Color(1,0.55,0.2)
	match_light.omni_range = 1.4
	match_light.light_energy = 0

func _input(event: InputEvent) -> void:
	if state == "done": return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo(): return
	if state == "night" and event is InputEventKey and event.keycode in [KEY_SPACE,KEY_ESCAPE]:
		morning()
	elif state == "seated" and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		state = "rising"
		rise_time = 0
		actor.set_meta("rest_waking",true)

func _process(delta: float) -> void:
	if home == null or state == "done": return
	if state == "seated": return
	if state == "rising":
		rise_time += delta
		actor.set_meta("rest_progress", lerpf(0.38,0.0,clampf(rise_time/1.5,0,1)))
		if rise_time >= 1.5: _release()
		return
	elapsed += delta
	var t := elapsed
	expression.update(t)
	if t >= 15.0 and t < 18.4 and not murmur_played:
		murmur_played = true
		murmur.play()
	if t >= 18.3 and t < 19.6 and not sigh_played:
		sigh_played = true
		sigh_audio.play()
	shade.color = Color(0,0,0,1.0-smoothstep(1.5,3.5,t))
	hint.modulate.a = 1.0-smoothstep(6,8,t)
	match_prop.visible = t < 7
	match_prop.get_node("Flame").visible = t >= 2.5 and t < 6.5
	match_light.light_energy = 0.45 if t >= 2.5 and t < 6.5 else 0.0
	var lit := t >= 5.5 and t < 29
	lamp.get_node("Flame").visible = lit
	light.light_energy = (0.85 + sin(t*17)*0.045) if lit else 0.0
	subtitle.text = "Still no word from Dev…" if t >= 15 and t < 19 else ""
	if t < 9:
		_shot(Vector3(-1.2,1.7,2.65),Vector3(-2.6,1.22,0.95))
		contact.update(self,t)
	elif t < 13:
		_walk(Vector3(-2.6,1.14,1.5),Vector3(-3.35,1.14,2.8),(t-9)/4,delta)
		_interior_window_shot(t)
	elif t < 20.8:
		# Face remains the subject. Only Arjun turns; camera stays in the room.
		var turn := smoothstep(19.5,20.8,t)
		_place(Vector3(-3.35,1.14,2.8),lerpf(-0.08,-PI,turn))
		actor.velocity = Vector3.ZERO
		var lowered := smoothstep(18.1,19.4,t)
		var sigh := sin(clampf((t-18.3)/1.2,0,1)*PI)
		visual.pose("head",Vector3(0.03+0.15*lowered,lerpf(-0.1,-0.85,smoothstep(14.7,16.0,t)),0.035*lowered),0.9)
		visual.pose("spine_02",Vector3(0.025+0.035*sigh,0,0),0.75)
		visual.pose("upperarm_l",Vector3(0.015,0,-0.04*sigh),0.45)
		visual.pose("upperarm_r",Vector3(0.015,0,0.04*sigh),0.45)
		_interior_window_shot(t)
	elif t < 24:
		if t < 23.1:
			_walk(Vector3(-3.35,1.14,2.8),Vector3(-3.35,1.14,-0.6),(t-20.8)/2.3,delta)
		else:
			_walk(Vector3(-3.35,1.14,-0.6),Vector3(-2.35,1.14,-0.6),(t-23.1)/0.9,delta)
		var follow := smoothstep(20.8,24,t)
		_shot(Vector3(-3.95,1.88,2.00).lerp(Vector3(-1.1,1.95,0.5),follow), Vector3(-3.30,1.56,2.8).lerp(Vector3(-2.35,1.0,-1.4),follow))
	else:
		actor.velocity = Vector3.ZERO
		actor.global_position = bed.to_global(Vector3(0,0.83,0))
		actor.global_basis = bed.global_basis
		actor.set_meta("rest_action","opening")
		actor.set_meta("rest_progress",clampf((t-24)/4,0,1))
		_shot(Vector3(-0.9,2.0,0),Vector3(-2.35,0.85,-1.4))
		shade.color.a = smoothstep(28,30,t)
	if t >= DURATION: morning()

func _place(local: Vector3, yaw: float) -> void:
	actor.global_position = home.to_global(local)
	actor.global_basis = home.global_basis * Basis(Vector3.UP,yaw)
	actor.get_node("VisualRoot").rotation.y = 0

func _walk(from: Vector3, to: Vector3, fraction: float, delta: float) -> void:
	var p := from.lerp(to,clampf(fraction,0,1))
	var direction := to-from
	_place(p,atan2(direction.x,direction.z))
	actor.velocity = (actor.global_position-previous_position)/maxf(delta,0.001)
	previous_position = actor.global_position
	if visual.motion_tree != null:
		visual.motion_tree.update_motion(delta,0.24,0,false,true,0)

func _shot(at: Vector3, target: Vector3) -> void:
	camera.fov = 48
	camera.global_position = home.to_global(at)
	camera.look_at(home.to_global(target))

func morning() -> void:
	if state != "night": return
	state = "seated"
	expression.restore()
	if murmur != null: murmur.stop()
	if sigh_audio != null: sigh_audio.stop()
	lamp.position = Vector3(-2.6,.96,.70)
	elapsed = DURATION
	shade.color = Color.BLACK
	clock.advance_minutes(8*60)
	actor.get_node("SurvivalComponent").restore_energy(100.0)
	environment.ambient_light_energy = ambient_energy
	lamp.get_node("Flame").hide()
	light.light_energy = 0
	match_prop.hide()
	match_light.light_energy = 0
	subtitle.text = ""
	hint.text = ""
	actor.velocity = Vector3.ZERO
	actor.global_position = bed.to_global(Vector3(0,0.83,0))
	actor.global_basis = bed.global_basis
	actor.set_meta("rest_action","opening")
	actor.set_meta("rest_progress",0.38)
	actor.remove_meta("rest_waking")
	world.player_camera.make_current()
	actor.get_node("CameraPivot").rotation = Vector3(-0.12,0,0)
	create_tween().tween_property(shade,"color:a",0.0,0.8)
	var bars := create_tween().set_parallel(true)
	bars.tween_property(top_bar,"anchor_bottom",0.0,0.8)
	bars.tween_property(bottom_bar,"anchor_top",1.0,0.8)

func _release() -> void:
	state = "done"
	actor.remove_meta("opening_active")
	actor.set_meta("rest_action", "")
	actor.set_meta("rest_progress",0.0)
	actor.remove_meta("rest_waking")
	_place(Vector3(-2.35,1.14,-0.60),0)
	actor.velocity = Vector3.ZERO
	clock.clock_paused = previous_clock_pause
	actor.set_physics_process(previous_physics)
	for node in disabled_inputs:
		if is_instance_valid(node): node.set_process_unhandled_input(true)
	for node in disabled_physics:
		if is_instance_valid(node): node.set_physics_process(true)
	for layer in hidden_layers:
		if is_instance_valid(layer): layer.show()
	set_process_input(false)
	set_process(false)
	# Keep the lamp/table in the home; discard transient cinematic overlays.
	for child in get_children(): child.queue_free()

func _interior_window_shot(t: float) -> void:
	# On the room side of the front wall (z < 3.41); see his face in profile.
	var push := smoothstep(13.0,18.0,t)
	_shot(Vector3(-4.05,1.88,1.92).lerp(Vector3(-3.95,1.88,2.00),push),Vector3(-3.23,1.78,4.25))
	camera.fov = 52.0
