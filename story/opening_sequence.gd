extends Node3D
## Live opening: prologue cards, night scene, automatic dawn and gate handoff.
const DURATION := 32.0
const Titles = preload("res://story/opening_titles.gd")
var cart_passage = preload("res://story/opening_cart_passage.gd").new()
@export var prologue_music: AudioStream = preload("res://assets/audio/opening/prologue_tension_draft.wav")
var elapsed := 0.0
var waiting_for_reveal := false
var state := "prologue"
var prologue_elapsed := 0.0
var morning_elapsed := 0.0
var titles: Label
var score: AudioStreamPlayer
var footwear = preload("res://story/opening_footwear.gd").new()
var world: Node3D
var actor: CharacterBody3D
var home: Node3D
var bed: Node3D
var clock: GameTimeSystem
var camera: Camera3D
var shade: ColorRect
var subtitle: Label
var hint: Label
var skip_requested := false
var top_bar: ColorRect
var bottom_bar: ColorRect
var lamp: Node3D
var light: OmniLight3D
var match_prop: MeshInstance3D
var match_light: OmniLight3D
var visual: Node3D
var disabled_inputs: Array[Node] = []
var disabled_physics: Array[Node] = []
var disabled_processes: Array[Node] = []
var hidden_layers: Array[CanvasLayer] = []
var previous_clock_pause := false
var previous_physics := true
var rise_time := 0.0
var environment: Environment
var ambient_energy := 0.0
var murmur: AudioStreamPlayer3D
var murmur_played := false
var sigh_audio: AudioStreamPlayer3D
var sigh_played := false
var sound: Node
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
	get_tree().root.get_node("WorldAudio").set_opening_quiet(true)
	process_priority = 100
	visual = actor.get_node("VisualRoot/CharacterVisual")
	preload("res://player/arjun_complete_fit.gd").new().apply(visual)
	footwear.barefoot(visual.model)
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
		if str(node.name) in ["StairFootContact","CameraClearance","StealthStance"] and node.is_processing():
			disabled_processes.append(node)
			node.set_process(false)
		if node.is_physics_processing():
			disabled_physics.append(node)
			node.set_physics_process(false)
	previous_clock_pause = clock.clock_paused
	clock.clock_paused = true
	clock.total_game_minutes = 22 * 60
	clock._update_readable_time(true)
	environment = world.get_node("WorldEnvironment").environment
	ambient_energy = environment.ambient_light_energy
	environment.ambient_light_energy = 0.0
	if visual.equipment != null:
		visual.equipment.stowed = true
		visual.equipment._refresh()
	camera = Camera3D.new()
	camera.fov = 48
	add_child(camera)
	camera.make_current()
	_build_lamp()
	_build_overlay()
	score = AudioStreamPlayer.new()
	score.stream = prologue_music
	if score.stream is AudioStreamWAV:
		score.stream = score.stream.duplicate()
		score.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		score.stream.loop_begin = 0
		score.stream.loop_end = score.stream.data.size()/2
	score.volume_db = -60.0
	add_child(score)
	score.play()
	sound = preload("res://story/opening_sound.gd").new()
	add_child(sound)
	sound.configure(actor,lamp)
	murmur = AudioStreamPlayer3D.new()
	murmur.stream = preload("res://systems/audio_edges.gd").prepare(load("res://assets/audio/opening/arjun_murmur_draft.wav"))
	murmur.volume_db = -12.0
	murmur.max_distance = 8.0
	actor.add_child(murmur)
	murmur.position = Vector3(0,0.70,0)
	sigh_audio = AudioStreamPlayer3D.new()
	sigh_audio.stream = preload("res://systems/audio_edges.gd").prepare(load("res://assets/audio/opening/arjun_sigh_draft.wav"))
	sigh_audio.volume_db = -6.0
	sigh_audio.max_distance = 8.0
	actor.add_child(sigh_audio)
	sigh_audio.position = Vector3(0,.70,0)
	_place(Vector3(-2.6, 1.14, 1.27), PI)

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
	hint.offset_left = -360
	hint.offset_right = -24
	hint.offset_top = -56
	hint.offset_bottom = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font",preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf"))
	hint.add_theme_font_size_override("font_size",18)
	hint.add_theme_color_override("font_color",Color(.95,.91,.80))
	hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x",1)
	hint.add_theme_constant_override("shadow_offset_y",2)
	hint.hide()
	layer.add_child(hint)
	titles = Titles.new()
	layer.add_child(titles)

func _build_lamp() -> void:
	# Open oil-wick diya stays on the table throughout lighting.
	lamp = preload("res://objects/household/oil_lamp_visual.tscn").instantiate()
	home.add_child(lamp)
	lamp.name = "OpeningOilLamp"
	lamp.position = Vector3(-2.6, 0.96, 0.70)
	lamp.scale = Vector3.ONE*.35
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
	# Separate abrasive pad on the tabletop; the diya has no enclosure.
	var strike_pad := MeshInstance3D.new()
	strike_pad.name = "MatchStrikePad"
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(.065,.004,.03)
	strike_pad.mesh = pad_mesh
	var abrasive := StandardMaterial3D.new()
	abrasive.albedo_color = Color(.12,.09,.065)
	abrasive.roughness = 1.0
	strike_pad.material_override = abrasive
	table.add_child(strike_pad)
	strike_pad.position = Vector3(.10,.042,.20)
	var strike_contact := Marker3D.new()
	strike_contact.name = "StrikeContact"
	home.add_child(strike_contact)
	strike_contact.position = Vector3(-2.50,.958,.90)
	var sparks := Node3D.new()
	sparks.name = "StrikeSparks"
	home.add_child(sparks)
	sparks.position = strike_contact.position
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1,.66,.18)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1,.4,.06)
	spark_material.emission_energy_multiplier = 2.0
	for i in 6:
		var spark := MeshInstance3D.new()
		var streak := BoxMesh.new()
		streak.size = Vector3(.001,.001,.006)
		spark.mesh = streak
		spark.material_override = spark_material
		sparks.add_child(spark)
	sparks.hide()
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
	match_prop.position = Vector3(0,0.035,0)
	var match_head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = .003
	head_mesh.height = .006
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	match_head.mesh = head_mesh
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(.17,.09,.045)
	head_material.roughness = 1.0
	match_head.material_override = head_material
	match_prop.add_child(match_head)
	match_head.position.y = .0275
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
	if state in ["prologue","cart_passage","night"] and event is InputEventKey and event.keycode in [KEY_SPACE,KEY_ESCAPE]:
		if skip_requested:
			morning()
		else:
			skip_requested = true
			hint.text = "Press Esc or Space to Skip"
			hint.show()

func _process(delta: float) -> void:
	if home == null or state == "done" or waiting_for_reveal: return
	if state == "prologue":
		prologue_elapsed += delta
		titles.update(prologue_elapsed)
		shade.color = Color.BLACK
		score.volume_db = lerpf(-60.0,-14.0,smoothstep(.3,3.0,prologue_elapsed))
		if prologue_elapsed >= Titles.DURATION:
			titles.hide()
			elapsed = 0.0
			state = "cart_passage" if cart_passage.begin(self) else "night"
		return
	if state == "cart_passage":
		cart_passage.update(delta)
		if cart_passage.age >= cart_passage.DURATION:
			cart_passage.finish()
			state = "night"
			elapsed = 0.0
		return
	if state in ["dawn","rising","departing"]:
		_update_morning(delta)
		return
	elapsed += delta
	var t := elapsed
	score.volume_db = lerpf(-14.0,-60.0,smoothstep(0,2.0,t))
	if t >= 2.0 and score.playing: score.stop()
	# The day/night controller also writes ambient energy; override after it.
	environment.ambient_light_energy = 0.0
	for name in ["Sun","Moon"]:
		var daylight := world.get_node_or_null(name) as DirectionalLight3D
		if daylight != null: daylight.light_energy = 0.0
	sound.update(t)
	expression.update(t)
	if t >= 15.0 and t < 18.4 and not murmur_played:
		murmur_played = true
		murmur.play()
	if t >= 18.3 and t < 19.6 and not sigh_played:
		sigh_played = true
		sigh_audio.play()
	shade.color = Color(0,0,0,1.0-smoothstep(.12,.55,t))
	match_prop.visible = true
	match_prop.get_node("Flame").visible = t >= .12 and t < 6.5
	match_light.light_energy = (.65+sin(t*31.0)*.035)*smoothstep(.12,.2,t) if t >= .12 and t < 6.5 else 0.0
	var lit := t >= 5.5 and t < 29
	lamp.get_node("Flame").visible = lit
	light.light_energy = (0.85 + sin(t*17)*0.045)*smoothstep(5.5,6.2,t) if lit else 0.0
	subtitle.text = "Still no word from Dev…" if t >= 15 and t < 19 else ""
	if t < 9:
		contact.update(self,t)
		# Face, forward hand and table share a steady upper-body composition.
		_shot(Vector3(-1.15,1.85,-.30),Vector3(-2.6,1.40,1.05))
		camera.fov = 58.0
		_update_strike_sparks(t)
	elif t < 13:
		_walk(Vector3(-2.6,1.14,1.27),Vector3(-3.35,1.14,2.8),(t-9.8)/3.2,delta)
		_interior_window_shot(t)
	elif t < 20.8:
		# Face remains the subject. Only Arjun turns; camera stays in the room.
		var turn := smoothstep(19.5,20.8,t)
		_place(Vector3(-3.35,1.14,2.8),lerpf(-0.08,-PI,turn))
		actor.velocity = Vector3.ZERO
		var lowered := smoothstep(18.1,19.4,t)
		var sigh := sin(clampf((t-18.3)/1.2,0,1)*PI)
		var search := .10*sin(clampf((t-13.5)/3.8,0,1)*TAU)*(1.0-lowered)
		visual.pose("head",Vector3(0.03+0.15*lowered,-.10+search,0.035*lowered),0.9)
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
		var sit_down := smoothstep(24.0,25.3,t)
		actor.global_position = home.to_global(Vector3(-2.35,1.14,-0.60)).lerp(bed.to_global(Vector3(0,0.83,0)),sit_down)
		actor.global_basis = (home.global_basis * Basis(Vector3.UP,PI/2)).slerp(bed.global_basis,sit_down)
		actor.set_meta("rest_action","opening")
		actor.set_meta("rest_progress",0.38*sit_down+0.62*smoothstep(25.3,28.0,t))
		_shot(Vector3(-0.9,2.0,0),Vector3(-2.35,0.85,-1.4))
		shade.color.a = smoothstep(28,30,t)
	if t >= DURATION: morning()

func _update_strike_sparks(t: float) -> void:
	var sparks: Node3D = home.get_node("StrikeSparks")
	var age := t-.12
	sparks.global_position = match_prop.to_global(Vector3(0,.038,0))
	sparks.visible = age >= 0 and age < .16
	if not sparks.visible: return
	for i in sparks.get_child_count():
		var streak: Node3D = sparks.get_child(i)
		var direction := Vector3(cos(i*2.4),.6+float(i)*.12,sin(i*2.4)).normalized()
		streak.position = direction*age*.25+Vector3.DOWN*age*age*.8
		streak.scale = Vector3.ONE*(1.0-age/.16)

func _place(local: Vector3, yaw: float) -> void:
	actor.global_position = home.to_global(local)
	actor.global_basis = home.global_basis * Basis(Vector3.UP,yaw)
	actor.get_node("VisualRoot").rotation.y = 0

func _walk(from: Vector3, to: Vector3, fraction: float, delta: float) -> void:
	var p := from.lerp(to,clampf(fraction,0,1))
	var direction := to-from
	var before := actor.global_position
	var facing := actor.global_basis
	_place(p,atan2(direction.x,direction.z))
	actor.global_basis = facing.slerp(actor.global_basis,1.0-exp(-6.0*delta))
	actor.velocity = (actor.global_position-before)/maxf(delta,0.001)
	contact.update_walk(self,delta)

func _shot(at: Vector3, target: Vector3) -> void:
	camera.fov = 48
	camera.global_position = home.to_global(at)
	camera.look_at(home.to_global(target))

func morning() -> void:
	if state not in ["prologue","cart_passage","night"]: return
	cart_passage.finish()
	state = "dawn"
	morning_elapsed = 0.0
	score.stop()
	footwear.restore()
	sound.morning()
	get_tree().root.get_node("WorldAudio").begin_morning(home.to_global(Vector3(-3.35,2.3,3.7)))
	expression.restore()
	if murmur != null: murmur.stop()
	if sigh_audio != null: sigh_audio.stop()
	lamp.position = Vector3(-2.6,.96,.70)
	elapsed = DURATION
	shade.color = Color.BLACK
	clock.advance_minutes(8*60)
	# Refresh the clock-driven sky/lights before revealing the paused morning.
	var sun := world.get_node_or_null("Sun")
	if sun != null and sun.has_method("_update_day_night_lighting"):
		sun._update_day_night_lighting()
	actor.get_node("SurvivalComponent").restore_energy(100.0)
	lamp.get_node("Flame").hide()
	light.light_energy = 0
	match_prop.hide()
	match_light.light_energy = 0
	subtitle.text = ""
	hint.text = ""
	hint.hide()
	skip_requested = false
	actor.velocity = Vector3.ZERO
	actor.global_position = bed.to_global(Vector3(0,0.83,0))
	actor.global_basis = bed.global_basis
	actor.set_meta("rest_action","opening")
	actor.set_meta("rest_progress",0.38)
	actor.remove_meta("rest_waking")
	titles.show()
	titles.next_morning(0.0)
	_shot(Vector3(-.9,2.0,0),Vector3(-2.35,1.10,-1.4))
	var door := home.get_node_or_null("EntranceDoor")
	if door != null:
		door.opened = true
		door.swing = 1.0

func _update_morning(delta: float) -> void:
	morning_elapsed += delta
	var t := morning_elapsed
	if t < 4.0:
		shade.color = Color.BLACK
		titles.next_morning(t)
		return
	titles.hide()
	shade.color.a = 1.0-smoothstep(4.0,5.2,t)
	if t < 6.0: return
	if t < 8.0:
		if state != "rising":
			state = "rising"
			sound.rise()
			actor.set_meta("rest_waking",true)
		rise_time = t-6.0
		actor.set_meta("rest_progress",lerpf(.38,0.0,smoothstep(.0,1.8,rise_time)))
		actor.global_position = bed.to_global(Vector3(0,.83,0)).lerp(home.to_global(Vector3(-2.35,1.14,-.60)),smoothstep(.3,1.8,rise_time))
		actor.global_basis = bed.global_basis.slerp(home.global_basis*Basis(Vector3.UP,PI/2),smoothstep(.3,1.8,rise_time))
		return
	state = "departing"
	actor.set_meta("rest_action", "")
	actor.set_meta("rest_progress",0.0)
	actor.remove_meta("rest_waking")
	var path := [Vector3(-2.35,1.14,-.60),Vector3(.85,1.14,-.75),Vector3(.85,1.14,3.0),Vector3(0,.94,5.2),Vector3(0,.94,8.2)]
	var segment_times := [3.2,3.75,2.4,3.0]
	var walk_time := t-8.0
	var total := 0.0
	for i in segment_times.size():
		var duration: float = segment_times[i]
		if walk_time < total+duration:
			_walk(path[i],path[i+1],(walk_time-total)/duration,delta)
			var at: Vector3 = home.to_local(actor.global_position)
			var shots := [Vector3(-1.1,2.0,.2),Vector3(2.8,2.1,2.2),Vector3(1.5,2.0,5.5),Vector3(2.2,2.0,6.0)]
			_shot(shots[i],at+Vector3(0,.45,.2))
			camera.fov = 58.0
			return
		total += duration
	_place(path[-1],0.0)
	_release()

func _release() -> void:
	state = "done"
	if murmur != null: murmur.queue_free()
	if sigh_audio != null: sigh_audio.queue_free()
	actor.remove_meta("opening_active")
	actor.set_meta("rest_action", "")
	actor.set_meta("rest_progress",0.0)
	actor.remove_meta("rest_waking")
	world.player_camera.make_current()
	actor.get_node("CameraPivot").rotation = Vector3(-.12,0,0)
	actor.velocity = Vector3.ZERO
	clock.clock_paused = previous_clock_pause
	actor.set_physics_process(previous_physics)
	for node in disabled_inputs:
		if is_instance_valid(node): node.set_process_unhandled_input(true)
	for node in disabled_physics:
		if is_instance_valid(node): node.set_physics_process(true)
	for node in disabled_processes:
		if is_instance_valid(node): node.set_process(true)
	for layer in hidden_layers:
		if is_instance_valid(layer): layer.show()
	set_process_input(false)
	set_process(false)
	# Keep the lamp/table in the home; discard transient cinematic overlays.
	# Let the last cot/cloth cue decay naturally across control release.
	var inquiry: Node = world.get_node_or_null("DevInquiry")
	var tutorial := actor.get_node_or_null("UI/HUDRoot/MorningTutorial")
	if tutorial != null:
		tutorial.begin()
	elif inquiry != null:
		inquiry.begin()
		var map := actor.get_node("UI/WorldMap")
		if map.has_method("follow_story_destination"): map.follow_story_destination()
	for child in get_children():
		if child != sound: child.queue_free()

func _interior_window_shot(t: float) -> void:
	# On the room side of the front wall (z < 3.41); see his face in profile.
	var push := smoothstep(13.0,18.0,t)
	_shot(Vector3(-4.05,1.88,1.92).lerp(Vector3(-3.95,1.88,2.00),push),Vector3(-3.23,1.78,4.25))
	camera.fov = 52.0

func _exit_tree() -> void:
	cart_passage.finish()
	var audio := get_tree().root.get_node_or_null("WorldAudio")
	footwear.restore()
	if audio != null and state in ["prologue","cart_passage","night"]: audio.set_opening_quiet(false)
