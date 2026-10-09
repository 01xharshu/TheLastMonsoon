extends SceneTree
const Trunks = preload("res://world/suryagarh/tree_trunk_collision.gd")
var failures := 0
var scene: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Tree instance validation requires the native renderer")
		quit(1)
		return
	scene = Node3D.new()
	root.add_child(scene)
	var source: Node3D = load("res://assets/nature/models/island_tree_02.glb").instantiate()
	scene.add_child(source)
	var mesh: Mesh = source.find_children("*","MeshInstance3D",true,false)[0].mesh
	var segments := Trunks.profile(mesh)
	check(segments.size()==3,"actual woody geometry produces three trunk segments")
	check(Vector2(segments[0].centre.x,segments[0].centre.z).length()>.5,"off-centre imported trunk is measured")
	var transforms: Array[Transform3D] = []
	for index in 4:
		var transform := Transform3D(Basis(Vector3.UP,index*PI*.5).scaled(Vector3(2,2.5,2)),Vector3(index*9,0,0))
		transforms.append(transform)
		var tree: Node3D = source.duplicate()
		scene.add_child(tree)
		tree.transform = transform
	source.hide()
	var solid := Trunks.add_batch(scene,transforms,segments)
	for tick in 3: await physics_frame
	var space := scene.get_world_3d().direct_space_state
	for tree in transforms:
		for segment in segments:
			var centre: Vector3 = tree*segment.centre
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(centre+Vector3.RIGHT*3,centre-Vector3.RIGHT*3))
			check(not hit.is_empty() and hit.collider==solid,"ray hits rotated/scaled visible trunk segment")
		var empty_origin: Vector3 = tree*Vector3(0,segments[0].centre.y,0)
		var ray := PhysicsRayQueryParameters3D.create(empty_origin+Vector3.UP*.03,empty_origin-Vector3.UP*.03)
		check(space.intersect_ray(ray).is_empty(),"asset origin has no displaced invisible trunk wall")
		var capsule := CapsuleShape3D.new()
		capsule.radius=.28; capsule.height=1.6
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=capsule
		var contact: Vector3 = tree*segments[0].centre
		query.transform=Transform3D(Basis.IDENTITY,contact+Vector3.RIGHT*3+Vector3.UP*.5)
		query.motion=Vector3.LEFT*6
		check(space.cast_motion(query)[0]<.5,"player-sized swept capsule cannot pass through trunk")
	var landscape: Node3D = load("res://world/suryagarh/generated/landscape.scn").instantiate()
	scene.add_child(landscape)
	for tick in 3: await physics_frame
	var count := await Trunks.repair_landscape(landscape)
	check(count>1800,"saved landscape repairs existing broadleaf trunks")
	for tick in 3: await physics_frame
	var terrain_ray := PhysicsRayQueryParameters3D.new()
	var exclusions: Array[RID] = []
	for body in scene.find_children("*","StaticBody3D",true,false):
		if body.name != "GroundCollision": exclusions.append(body.get_rid())
	terrain_ray.exclude = exclusions
	var floating_roots := 0
	var maximum_root_gap := -INF
	var verified := 0
	var misplaced := 0
	for candidate in landscape.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		if not "BroadleafTrees" in str(candidate.name): continue
		var batch := candidate as MultiMeshInstance3D
		var batch_segments := Trunks.profile(batch.multimesh.mesh)
		var body := batch.get_parent().get_node(str(batch.name)+"SolidTrunks")
		for index in batch.multimesh.instance_count:
			var transform: Transform3D = batch.global_transform*batch.multimesh.get_instance_transform(index)
			if is_zero_approx(transform.basis.determinant()): continue
			var base: Vector3 = batch_segments[0].centre
			base.y -= float(batch_segments[0].height)*.5
			var root_position: Vector3 = transform*base
			terrain_ray.from = root_position+Vector3.UP*300
			terrain_ray.to = root_position-Vector3.UP*300
			var ground := space.intersect_ray(terrain_ray)
			if not ground.is_empty():
				var gap: float = root_position.y-ground.position.y
				maximum_root_gap = maxf(maximum_root_gap,gap)
				if gap > .05: floating_roots += 1
			var query := PhysicsPointQueryParameters3D.new()
			query.position = transform*batch_segments[1].centre
			var found := false
			for hit in space.intersect_point(query,8):
				if hit.collider == body: found = true
			if not found: misplaced += 1
			verified += 1
	print("TREE ROOT SUPPORT floating=",floating_roots," max_gap=",maximum_root_gap," adjusted=",landscape.get_meta("tree_root_adjustments",0))
	check(floating_roots==0 and absf(maximum_root_gap+.12)<.025,"actual woody roots settle on resident terrain")
	check(verified==count and misplaced==0,"every repaired saved tree has physics at its visible trunk")
	check(await Trunks.repair_landscape(landscape)==0,"tree collision repair is idempotent")
	var forest := preload("res://world/suryagarh/forest_shrine.gd").new()
	scene.add_child(forest)
	for tick in 4: await physics_frame
	var grove: MultiMeshInstance3D = forest.get_node("SecludedBroadleafForest")
	var forest_body: StaticBody3D = forest.get_node("SolidTreeTrunks")
	var forest_roots := 0
	var forest_floating := 0
	var forest_missing_collision := 0
	exclusions.clear()
	for body in scene.find_children("*","StaticBody3D",true,false):
		if body.name != "GroundCollision": exclusions.append(body.get_rid())
	terrain_ray.exclude = exclusions
	for index in grove.multimesh.instance_count:
		var tree: Transform3D = grove.global_transform*grove.multimesh.get_instance_transform(index)
		var base: Vector3 = segments[0].centre
		base.y -= float(segments[0].height)*.5
		var root_position: Vector3 = tree*base
		terrain_ray.from=root_position+Vector3.UP*50;terrain_ray.to=root_position-Vector3.UP*50
		var ground := space.intersect_ray(terrain_ray)
		if ground.is_empty() or absf(root_position.y-ground.position.y+.10)>.025: forest_floating += 1
		var query := PhysicsPointQueryParameters3D.new();query.position=tree*segments[1].centre
		var found := false
		for hit in space.intersect_point(query,8):
			if hit.collider==forest_body: found=true
		if not found: forest_missing_collision += 1
		forest_roots += 1
	check(forest_roots==int(forest.get_meta("new_forest_trees",0)) and forest_roots>0 and forest_floating==0,"shrine forest woody roots are grounded on saved terrain")
	check(forest_missing_collision==0,"shrine forest trunks block physical passage")
	print("SHRINE FOREST trees=",forest_roots," root_failures=",forest_floating," collision_failures=",forest_missing_collision)
	forest.hide()

	if DisplayServer.get_name() != "headless":
		landscape.hide()
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-35,-40,0);light.light_energy=1.3;scene.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color(.20,.27,.32)
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color(.75,.8,.9)
		environment.environment.ambient_light_energy=.65
		scene.add_child(environment)
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new();plane.size=Vector2(90,90);floor.mesh=plane
		var grass := StandardMaterial3D.new();grass.albedo_color=Color(.26,.34,.19);floor.material_override=grass;scene.add_child(floor)
		var outline := StandardMaterial3D.new()
		outline.albedo_color=Color(.2,.65,1,.30);outline.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		for collision in solid.get_children():
			var shape: CylinderShape3D = collision.shape
			var visual := MeshInstance3D.new()
			var cylinder := CylinderMesh.new();cylinder.top_radius=shape.radius;cylinder.bottom_radius=shape.radius;cylinder.height=shape.height
			visual.mesh=cylinder;visual.material_override=outline;visual.position=collision.position;scene.add_child(visual)
		var camera := Camera3D.new();scene.add_child(camera)
		camera.position=Vector3(2.5,2.0,4.5);camera.look_at(Vector3(-.2,1.25,-1.7));camera.make_current()
		root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,540);root.show()
		await process_frame
		await RenderingServer.frame_post_draw
		var folder := ""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--output-dir="): folder=argument.trim_prefix("--output-dir=")
		if not folder.is_empty():
			root.get_texture().get_image().save_png(folder.path_join("tree_inspection.png"))
			print("TEMPORARY TREE REVIEW ",folder)
		await create_timer(10.0).timeout
	print("TREE SOLIDITY ","PASS" if failures==0 else "FAIL"," repaired=",count," failures=",failures)
	scene.queue_free()
	for tick in 3: await physics_frame
	await root.get_node("SaveManager").quit_game(1 if failures else 0)
