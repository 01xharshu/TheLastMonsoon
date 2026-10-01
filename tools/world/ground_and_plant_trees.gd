extends "res://tools/world/bake_landscape.gd"
var support_space: PhysicsDirectSpaceState3D
var tree_mesh: Mesh
var roots: Dictionary = {}
var checked := 0
var adjusted := 0
var max_before := 0.0
var planted := 0
var added: Array[Transform3D] = []
func bake() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Tree bake requires native renderer")
		quit(1)
		return
	world = load(OUT+"landscape.scn").instantiate()
	root.add_child(world)
	for frame in 3: await physics_frame
	support_space = world.get_world_3d().direct_space_state
	# Exclude vegetation so support always comes from resident landscape collisions.
	for body in world.get_node("NatureTiles").find_children("*","StaticBody3D",true,false): body.collision_layer = 0
	for frame in 2: await physics_frame
	for batch in world.get_node("NatureTiles").find_children("BroadleafTrees","MultiMeshInstance3D",true,false):
		var copy: MultiMesh = batch.multimesh.duplicate()
		tree_mesh = copy.mesh
		for i in copy.instance_count:
			var t := copy.get_instance_transform(i)
			if is_zero_approx(t.basis.determinant()): continue
			var p: Vector3 = batch.global_transform*t.origin
			var floor := ground(p.x,p.z)
			if not is_finite(floor): continue
			var bottom := tree_mesh.get_aabb().position.y*t.basis.get_scale().y
			var gap: float = p.y+bottom-floor
			max_before = maxf(max_before,gap)
			var shift: float = floor-0.12-bottom-p.y
			t.origin.y += shift
			roots[key(p)] = shift
			if absf(shift)>0.02: adjusted += 1
			checked += 1
			copy.set_instance_transform(i,t)
		batch.multimesh = copy
	for body in world.get_node("NatureTiles").find_children("*","StaticBody3D",true,false):
		var p: Vector3 = body.global_position
		if roots.has(key(p)) and body.get_child_count()>0 and body.get_child(0).shape is CylinderShape3D:
			body.position.y += roots[key(p)]
		body.collision_layer = 1
	var nature: Node3D = world.get_node("NatureTiles")
	var old: Node = nature.get_node_or_null("AddedDistrictTrees")
	if old != null:
		nature.remove_child(old)
		old.free()
	var garden := Node3D.new()
	garden.name = "AddedDistrictTrees"
	attach(garden,nature)
	rng.seed = 18571001
	# Shade the garden outer corners, service-yard edges and the avenue verge.
	for cx in [640.0,720.0]:
		for dx in [-25.0,25.0]:
			for z in [214.0,236.0,258.0]: plant(Vector2(cx+dx,z),garden,2.3)
	for x in [600.0,625.0,655.0,680.0,705.0,735.0,760.0]: plant(Vector2(x,301),garden,2.6)
	for x in [606.0,629.0,653.0,675.0]:
		plant(Vector2(x,433),garden,2.0)
		plant(Vector2(x,514),garden,2.0)
	# More grove trees across eligible land; deterministic spacing and route exclusion.
	var attempts := 0
	while planted < 227 and attempts < 10000:
		attempts += 1
		var p := Vector2(rng.randf_range(-800,800),rng.randf_range(-730,610))
		if layout.built_area(p.x,p.y) or layout.road_distance(p.x,p.y)<14: continue
		var h := ground(p.x,p.y)
		if not is_finite(h) or h<3 or h>100: continue
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,300,p.y),Vector3(p.x,-50,p.y),1)
		var hit := support_space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<0.9: continue
		var clear := true
		for point in roots.keys():
			if p.distance_to(point)<14:
				clear = false
				break
		if clear: plant(p,garden,rng.randf_range(1.8,2.8))
	multimesh_batch(tree_mesh,added,garden,"PlantedBroadleafTrees",1400)
	var packed := PackedScene.new()
	assert(packed.pack(world)==OK)
	save_resource(packed,"landscape.scn")
	var file := FileAccess.open("res://docs/world/tree_grounding_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"date":"2026-10-01","existing_checked":checked,"existing_adjusted":adjusted,"max_positive_gap_before_m":max_before,"new_trees":planted,"root_embed_m":0.12,"support":"resident terrain collider","open":"fresh world post-save rays, Metal visual review and routes"},"\t"))
	print("TREE GROUNDING BAKE PASS | checked=",checked," adjusted=",adjusted," max floating gap=",max_before," planted=",planted)
	world.free()
	quit()
func key(p: Vector3) -> Vector2:
	return Vector2(snappedf(p.x,0.01),snappedf(p.z,0.01))
func ground(x: float,z: float) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x,400,z),Vector3(x,-80,z),1)
	var hit := support_space.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else NAN
func plant(p: Vector2, parent: Node3D, size: float) -> void:
	var h := ground(p.x,p.y)
	if not is_finite(h): return
	var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size)
	var bottom := tree_mesh.get_aabb().position.y*size
	added.append(Transform3D(basis,Vector3(p.x,h-0.12-bottom,p.y)))
	roots[Vector2(snappedf(p.x,0.01),snappedf(p.y,0.01))] = 0.0
	var body := StaticBody3D.new()
	body.position = Vector3(p.x,h+size*0.8,p.y)
	attach(body,parent)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = size*0.11
	shape.height = size*1.8
	collision.shape = shape
	attach(collision,body)
	planted += 1
