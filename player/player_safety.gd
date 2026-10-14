extends Node
## Player death, safe automatic checkpoints and mounted river escape.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Style = preload("res://ui/menu_style.gd")
const FATAL_DROP := 12.0
var layout := Layout.new()
var peak := -INF
var tracked_vehicle: Node
var checkpoint_elapsed := 60.0
var checkpoint_retry := 0.0
var death_open := false
var river_retry := 0.0
var escape_colliders: Array[CollisionObject3D] = []
@onready var actor: CharacterBody3D = get_parent()
@onready var world: Node3D = actor.get_parent()
@onready var saves: Node = get_node("/root/SaveManager")

func _ready() -> void:
	process_priority = 100
	process_physics_priority = 100

func _physics_process(delta: float) -> void:
	if actor.health <= 0.0:
		show_death(); return
	var mounted: Node = actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null
	if is_instance_valid(mounted):
		var vehicle: Node3D = mounted.cart if "cart" in mounted else mounted
		if tracked_vehicle != vehicle:
			tracked_vehicle = vehicle; peak = vehicle.global_position.y; river_retry = 0.0
		peak = maxf(peak, vehicle.global_position.y)
		var p := vehicle.global_position
		if river_entry(p) and (mounted.is_in_group("horses") or ("cart" in mounted and mounted.cart.get("combat") != null)):
			river_retry = maxf(0.0, river_retry-delta)
			if river_retry <= 0.0:
				river_retry = 0.25
				escape_river(mounted, vehicle)
			peak = -INF; return
		var supported: bool = vehicle.is_on_floor() if vehicle is CharacterBody3D else vehicle_supported(vehicle, mounted)
		if supported:
			if peak - p.y >= FATAL_DROP:
				actor.take_damage(actor.MAX_HEALTH); return
			peak = p.y
	else:
		tracked_vehicle = null; peak = -INF
	if preload("res://systems/world_startup.gd").current != null: return
	checkpoint_elapsed += delta
	checkpoint_retry -= delta
	if checkpoint_retry > 0.0: return
	checkpoint_retry = 1.0
	if checkpoint_elapsed < 60.0 or not actor.is_on_floor() or actor.is_swimming or is_instance_valid(mounted): return
	if not world.has_node("GameTimeSystem"): return
	if actor.get_meta("story_cinematic", false) or actor.get_meta("climbing", false) or saves.pending_slot >= 0: return
	if saves.save_game(world, saves.CHECKPOINT_SLOT): checkpoint_elapsed = 0.0

func river_entry(p: Vector3) -> bool:
	return absf(p.z) < Layout.HALF and absf(p.x-layout.river_x(p.z)) < layout.river_width(p.z)+36.0 and layout.height(p.x,p.z) < Layout.WATER_LEVEL-1.0 and p.y < Layout.WATER_LEVEL+0.4

func vehicle_supported(vehicle: Node3D, mounted: Node = null) -> bool:
	var q := PhysicsRayQueryParameters3D.create(vehicle.global_position+Vector3.UP*.15,vehicle.global_position-Vector3.UP*.35,1)
	if mounted != null and mounted.has_method("_vehicle_exclusions"): q.exclude = mounted._vehicle_exclusions()
	elif vehicle is CollisionObject3D: q.exclude = [vehicle.get_rid()]
	return not vehicle.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func river_escape_pose(mounted: Node, vehicle: Node3D) -> Dictionary:
	var toward := Vector3(layout.river_x(vehicle.global_position.z)-vehicle.global_position.x,0,0).normalized()
	if toward == Vector3.ZERO: toward = -vehicle.global_basis.z
	var side := signf(vehicle.to_local(actor.global_position).x)
	var outward := vehicle.global_basis.x * (side if side != 0.0 else 1.0)
	var shape_node := actor.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.collision_mask = int(mounted.saved_mask)
	query.exclude = [actor.get_rid()]
	# Keep the vehicle in the query: its cabin, steps and horse must also clear.
	# A closed carriage passenger leaves on their own side, not across the cabin.
	var directions: Array[Vector3] = [toward, outward, -outward, -vehicle.global_basis.z]
	if "cart" in mounted: directions.assign([outward, toward, -outward, -vehicle.global_basis.z, vehicle.global_basis.z])
	var base := actor.global_position
	base.y = maxf(base.y, Layout.WATER_LEVEL+0.7)
	for distance in [1.0, 1.6, 2.2, 2.8, 3.4, 4.0, 5.0, 6.0]:
		for direction in directions:
			var candidate: Vector3 = base+direction*distance
			if not river_entry(Vector3(candidate.x, Layout.WATER_LEVEL-0.1, candidate.z)): continue
			query.transform = Transform3D(actor.global_basis, candidate)*shape_node.transform
			if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
			var path_query := PhysicsShapeQueryParameters3D.new()
			path_query.shape = shape_node.shape
			path_query.transform = Transform3D(actor.global_basis,base)*shape_node.transform
			path_query.motion = candidate-base
			path_query.collision_mask = int(mounted.saved_mask)
			var exclusions: Array[RID] = [actor.get_rid()]
			if vehicle is CollisionObject3D: exclusions.append(vehicle.get_rid())
			for collider in vehicle.find_children('*','CollisionObject3D',true,false): exclusions.append(collider.get_rid())
			path_query.exclude = exclusions
			var swept := actor.get_world_3d().direct_space_state.cast_motion(path_query)
			if swept.size()==2 and swept[0] >= 0.999:
				return {"position":candidate,"direction":direction,"start":base}
	return {}

func escape_river(mounted: Node, vehicle: Node3D) -> bool:
	# Death/traction is independent of whether a blocked rider exit needs a retry.
	if "cart" in mounted:
		mounted.speed = 0.0
		if mounted.travel != null: mounted.travel.cancel()
		for horse in vehicle.combat.horses: horse.take_damage(1000.0)
	else:
		mounted.vitality.take_damage(1000.0)
	var exit_pose := river_escape_pose(mounted, vehicle)
	if exit_pose.is_empty(): return false
	var direction: Vector3 = exit_pose.direction
	actor.collision_layer = mounted.saved_layer
	actor.collision_mask = mounted.saved_mask
	mounted.rider = null
	mounted.transition = ""
	actor.set_meta("mounted_vehicle",null)
	actor.set_meta("cart_role","")
	actor.set_meta("horse_transition","")
	finish_river_escape()
	# The rider already occupies the seat volume. Ignore only their own vehicle
	# while jumping through its open side; retain every other world collision.
	if vehicle is CollisionObject3D: escape_colliders.append(vehicle)
	for collider in vehicle.find_children('*','CollisionObject3D',true,false): escape_colliders.append(collider)
	for collider in escape_colliders: actor.add_collision_exception_with(collider)
	if "cart" in mounted and vehicle.has_method('set_boarding_door'):
		var side := signf(vehicle.global_basis.x.dot(direction))
		if side != 0.0: vehicle.set_boarding_door(side,1.0)
	actor.global_position = exit_pose.start
	var distance: float = exit_pose.position.distance_to(exit_pose.start)
	actor.velocity = direction*maxf(5.0,distance/0.45)+Vector3.UP*3.0
	actor.visual_root.global_rotation.y = atan2(direction.x,direction.z)
	actor.set_meta("river_escape_remaining",0.6)
	return true

func finish_river_escape() -> void:
	for collider in escape_colliders:
		if is_instance_valid(collider): actor.remove_collision_exception_with(collider)
	escape_colliders.clear()

func show_death() -> void:
	if death_open or not is_inside_tree(): return
	death_open = true
	actor.health = 0.0
	actor.velocity = Vector3.ZERO
	actor.set_meta("dead",true)
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var shade := ColorRect.new()
	shade.color = Color(.012,.015,.02,.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.theme = Style.make_theme()
	canvas.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	centre.add_child(column)
	column.add_child(Style.heading("You died",38))
	var checkpoint: int = saves.CHECKPOINT_SLOT if not saves.read_slot(saves.CHECKPOINT_SLOT).is_empty() else saves.newest_slot()
	var reload := Style.button("Load from last checkpoint",func(): saves.start_loaded_game(checkpoint))
	reload.disabled = checkpoint == 0
	column.add_child(reload)
	var back := Style.button("Back to Main Menu",func():
		get_tree().paused = false
		preload("res://systems/scene_retirement.gd").hold_until_exit(get_tree(),get_tree().current_scene)
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	)
	column.add_child(back)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	(back if reload.disabled else reload).grab_focus()
