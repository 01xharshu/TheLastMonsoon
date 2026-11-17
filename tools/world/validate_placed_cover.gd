extends SceneTree
## Test cover against generated objects in the actual Suryagarh world.
const Trace = preload("res://combat/ballistic_trace.gd")
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
var failures: Array[String] = []
var world: Node3D
var actor: CharacterBody3D
var stance: Node
var space: PhysicsDirectSpaceState3D
var terrain_excluded: Array[RID] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func ground_at(point: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*30,point-Vector3.UP*30,Ground.TERRAIN_SUPPORT_LAYER)
	ray.exclude = terrain_excluded
	var hit := space.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else NAN

func try_position(hit: Dictionary, ground_y: float, kind: String) -> bool:
	if not is_finite(ground_y): return false
	var normal: Vector3 = hit.normal
	normal.y = 0
	if normal.length_squared() < .5: return false
	normal = normal.normalized()
	var at: Vector3 = hit.position + normal*.80
	actor.global_position = Vector3(at.x,ground_y+1.0,at.z)
	actor.velocity = Vector3.ZERO
	actor.get_node("CameraPivot").global_rotation = Vector3(0,atan2(normal.x,normal.z),0)
	for frame in 18: await physics_frame
	if not actor.is_on_floor() or not stance.try_cover(): return false
	var valid: bool = stance.cover_body == hit.collider
	var origin: Vector3 = actor.global_position-Vector3.UP*.18
	var forward: Vector3 = -actor.get_node("CameraPivot").global_basis.z
	forward.y = 0
	var shot := Trace.shoot(space,self,origin,origin+forward.normalized()*1.5,38.0,[actor.get_rid()],actor)
	valid = valid and shot.get("collider") == stance.cover_body
	if valid: print("PLACED COVER ",kind," ",stance.cover_body.get_path())
	stance.stand()
	for frame in 3: await physics_frame
	return valid

func _run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	actor = world.get_node("Player")
	stance = actor.get_node("StealthStance")
	space = world.get_world_3d().direct_space_state
	var deadline := Time.get_ticks_msec()+150000
	while (world.get_node_or_null("RoadsideShadeTrees") == null or not world.get_node("RoadsideShadeTrees").has_meta("roots") or world.get_node_or_null("RemoteMountains") == null or not world.get_node("RemoteMountains").ready_for_exploration) and Time.get_ticks_msec()<deadline:
		await process_frame
	var trees := world.get_node_or_null("RoadsideShadeTrees")
	var mountain := world.get_node_or_null("RemoteMountains")
	if trees == null or mountain == null or not mountain.ready_for_exploration:
		check(false,"Placed trees or mountain rocks did not finish loading")
		await root.get_node("SaveManager").quit_game(1)
		return
	Ground.configure_terrain_support(world)
	terrain_excluded = [actor.get_rid()]
	var tree_ok := false
	var roots: Array = trees.get_meta("roots",[])
	for tree_root: Vector3 in roots.slice(0,40):
		for side: Vector3 in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]:
			var near := tree_root + side*3.0 + Vector3.UP*.72
			var query := PhysicsRayQueryParameters3D.create(near,tree_root+Vector3.UP*.72)
			query.exclude = [actor.get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty() or not hit.collider.has_meta("tree_trunk_geometry"): continue
			var support := ground_at(hit.position+side*.8)
			if await try_position(hit,support,"roadside tree"):
				tree_ok = true
				break
		if tree_ok: break
	check(tree_ok,"No actual roadside tree supported player cover and stopped a shot")
	var rock_ok := false
	for rock in mountain.get_children():
		if not rock is MeshInstance3D or not rock.has_node("RockCollision") or rock.scale.x > 15: continue
		var bounds: AABB = rock.global_transform * rock.get_aabb()
		var target := bounds.get_center()
		for side: Vector3 in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]:
			var reach := maxf(bounds.size.x,bounds.size.z)*.7+2.0
			var outside := target+side*reach
			var support := ground_at(outside)
			if not is_finite(support): continue
			var from := Vector3(outside.x,support+.72,outside.z)
			var to := Vector3(target.x,from.y,target.z)
			var query := PhysicsRayQueryParameters3D.create(from,to)
			query.exclude = [actor.get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty() or hit.collider != rock.get_node("RockCollision"): continue
			var at_support := ground_at(hit.position+side*.8)
			if await try_position(hit,at_support,"mountain rock"):
				rock_ok = true
				break
		if rock_ok: break
	check(rock_ok,"No actual mountain rock supported player cover and stopped a shot")
	print("PLACED WORLD COVER ",JSON.stringify({"passed":failures.is_empty(),"tree":tree_ok,"rock":rock_ok,"failures":failures}))
	await root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
