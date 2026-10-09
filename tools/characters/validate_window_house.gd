extends Node3D
var review_dir := ""
var review_index := 0
## Real settlement architecture and shutters, with normal player jump input.
class Builder extends "res://world/suryagarh/settlements/settlement_builder.gd":
	func _ready() -> void: pass

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	review_dir = OS.get_environment("TLM_WINDOW_REVIEW_DIR")
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	add_child(light)
	var ambience := WorldEnvironment.new()
	ambience.environment = Environment.new()
	ambience.environment.background_mode = Environment.BG_COLOR
	ambience.environment.background_color = Color(.45,.56,.66)
	ambience.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambience.environment.ambient_light_color = Color(.75,.8,.9)
	ambience.environment.ambient_light_energy = .7
	add_child(ambience)
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	add_child(clock)
	var builder := Builder.new()
	add_child(builder)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.63,.51,.36)
	for property in ["plaster","ochre","brick","wood","tile","stone","iron"]: builder.set(property,material)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(30,.2,30)
	ground.position.y = -.1
	ground.add_child(shape)
	add_child(ground)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	add_child(actor)
	actor.get_node("UI").hide()
	var detail := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
	var palette: Array[Material] = [material]
	detail.configure(builder,palette)
	for index in [4,1,2]:
		var home := builder.make_building("WindowHouse",Vector2.ZERO,Vector2(6,6),false,false,false,true)
		home.position = Vector3.ZERO
		home.rotation.y = .65
		detail._openings(home,Vector2(6,6),index)
		for frame in 3: await get_tree().physics_frame
		var portals: Array[Node] = []
		for portal in get_tree().get_nodes_in_group("climbable_windows"):
			if home.is_ancestor_of(portal): portals.append(portal)
		if index == 2:
			assert(portals.is_empty(),"Iron grille registered a crossing")
		else:
			assert(portals.size() == 2)
			for portal in portals:
				if index == 1:
					for direction in [-1.0,1.0]:
						await _place(actor,portal,direction)
						assert(not actor.get_node("ClimbComponent").window.try_start(actor),"Closed house shutter admitted crossing")
					var frame_name := "TimberWindowFrameEast" if portal.position.x > 0.0 else "TimberWindowFrameWest"
					home.get_node(frame_name+"/PairedWoodShutters").restore_state(true)
					await get_tree().physics_frame
				for direction in [-1.0,1.0]:
					if not await _cross(actor,portal,direction): return
		home.queue_free()
		for frame in 3: await get_tree().physics_frame
	print("WINDOW HOUSE: PASS | rotated east/west house windows, inside/outside Space, actual closed/open shutters and grilles")
	actor.queue_free()
	builder.queue_free()
	ground.queue_free()
	for frame in 3: await get_tree().physics_frame
	get_tree().quit()

func _place(actor: CharacterBody3D, portal: Node3D, direction: float) -> void:
	actor.set_physics_process(false)
	var normal: Vector3 = portal.global_basis.x.normalized()*direction
	# Keep clear of the real sleeping platform beside the western opening.
	var point: Vector3 = portal.global_position+portal.global_basis.z.normalized()*.5
	var at: Vector3 = point+normal*.9
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*3.0)
	ray.exclude = [actor.get_rid()]
	var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not floor_hit.is_empty())
	actor.global_position = Vector3(at.x,floor_hit.position.y+.94,at.z)
	actor.velocity = Vector3.ZERO
	actor.visual_root.global_rotation.y = atan2(-normal.x,-normal.z)
	actor.camera_pivot.global_rotation.y = actor.visual_root.global_rotation.y
	for frame in 3: await get_tree().physics_frame

func _cross(actor: CharacterBody3D, portal: Node3D, direction: float) -> bool:
	await _place(actor,portal,direction)
	actor.set_physics_process(true)
	for frame in 8: await get_tree().physics_frame
	if actor.get_node("ClimbComponent").active:
		push_error("House crossing started without a fresh Space press")
		get_tree().quit(1)
		return false
	var original_shape: Shape3D = actor.get_node("CollisionShape3D").shape
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(.12).timeout
	press = InputEventAction.new()
	press.action = "jump"
	press.pressed = false
	Input.parse_input_event(press)
	var climb = actor.get_node("ClimbComponent")
	var started: bool = climb.active
	for frame in 300:
		await get_tree().physics_frame
		started = started or climb.active
		if frame in [45,95,155] and review_index < 2 and not review_dir.is_empty() and DisplayServer.get_name() != "headless":
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png(review_dir.path_join("player_%d_%d.png"%[review_index,frame]))
		if started and not climb.active: break
	if not started or climb.active:
		push_error("Single Space did not finish actual house crossing")
		get_tree().quit(1)
		return false
	var signed_distance: float = (actor.global_position-portal.global_position).dot(portal.global_basis.x)*direction
	if signed_distance >= -.8:
		push_error("House crossing did not reach the opposite side")
		get_tree().quit(1)
		return false
	if actor.get_node("CollisionShape3D").shape != original_shape or actor.get_meta("climbing",false):
		print("WINDOW HOUSE collision diagnostic: profile=",climb.window.profile," shape_height=",actor.get_node("CollisionShape3D").shape.height," original_height=",original_shape.height," climbing=",actor.get_meta("climbing",false)," progress=",climb.window.progress)
		push_error("House crossing did not restore standing collision")
		get_tree().quit(1)
		return false
	review_index += 1
	return true
