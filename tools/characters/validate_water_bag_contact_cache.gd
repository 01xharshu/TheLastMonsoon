extends SceneTree
## Compare cached contact skinning with the pre-cache calculation on real Arjun.
var failures: Array[String] = []
var reference_samples: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func stop_scripts(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): stop_scripts(child)
func prepare_reference(bag: Node3D) -> void:
	var visual: Node3D = bag.get_parent().get_parent().get_node("CharacterVisual")
	var cloth := visual.model.find_child("Arjun_Kurta_SplitHem",true,false) as MeshInstance3D
	var inverse: Transform3D = bag.pouch.global_transform.affine_inverse()
	for surface in cloth.mesh.get_surface_count():
		var arrays := cloth.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var slots: int = weights.size()/vertices.size()
		for index in vertices.size():
			var point: Vector3 = inverse*cloth.to_global(vertices[index])
			if absf(point.x)>.24 or point.y<-.12 or point.y>.39: continue
			var sample := {"point":vertices[index],"bones":[],"binds":[],"weights":[]}
			for slot in slots:
				var weight := weights[index*slots+slot]
				if weight<.001: continue
				var bind := bones[index*slots+slot]
				var bone_index: int = visual.skeleton.find_bone(cloth.skin.get_bind_name(bind))
				if bone_index<0: bone_index = cloth.skin.get_bind_bone(bind)
				sample.bones.append(bone_index)
				sample.binds.append(cloth.skin.get_bind_pose(bind))
				sample.weights.append(weight)
			reference_samples.append(sample)
func exact_unique_samples(bag: Node3D) -> int:
	# Inventory only: compare binary position and ordered influence data.
	# No rounding, approximate welding, skin/material or query changes.
	var seen := {}
	for sample in bag.contact_points.size():
		var key := PackedVector3Array([bag.contact_points[sample]]).to_byte_array()
		for slot in range(bag.contact_offsets[sample],bag.contact_offsets[sample+1]):
			key.append_array(PackedInt32Array([bag.contact_indices[slot]]).to_byte_array())
			key.append_array(PackedFloat32Array([bag.contact_weights[slot]]).to_byte_array())
		seen[key.hex_encode()] = true
	return seen.size()

func reference(bag: Node3D) -> float:
	var inverse: Transform3D = bag.pouch.global_transform.affine_inverse() * bag.cloth_rig.global_transform
	var poses := {}
	var required := 0.0
	for sample in reference_samples:
		var vertex := Vector3.ZERO
		for slot in sample.bones.size():
			var index: int = sample.bones[slot]
			if not poses.has(index): poses[index] = bag.cloth_rig.get_bone_global_pose(index)
			vertex += (poses[index] * sample.binds[slot] * sample.point) * sample.weights[slot]
		var point: Vector3 = inverse * vertex
		if point.y < .005 or point.y > .285 or absf(point.x) > bag._radius_at(point.y)*.84+.018: continue
		var blend := smoothstep(0.0,1.0,clampf((.41-point.y)/.29,0.0,1.0))
		required = maxf(required,(point.z+.018)/maxf(blend,.1)-bag.HIP_SUPPORT)
	return required
func shader_support(bag: Node3D, value: float) -> void:
	bag.leather_material.set_shader_parameter("cloth_support",value)
	for material in bag.contact_materials: material.set_shader_parameter("cloth_support",value)
func rendered_parity(stage: Node3D, bag: Node3D, actor: CharacterBody3D) -> void:
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	root.disable_3d = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.16,.18,.20)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.8,.8,.8)
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 40
	viewport.add_child(camera)
	var target: Vector3 = bag.pouch.to_global(Vector3(0,.17,0))
	camera.global_position = target + bag.pouch.global_basis.orthonormalized()*Vector3(.35,.08,.6)
	camera.look_at(target)
	camera.make_current()
	bag.held = false
	for liters in [0.0,1.0,2.0]:
		actor.inventory.consume_water(2.0)
		actor.inventory.add_water(liters)
		bag._process(1.0)
		var expected := clampf(reference(bag),0.0,.30)
		var actual := clampf(bag._cloth_contact_required(),0.0,.30)
		shader_support(bag,expected)
		for frame in 3: await process_frame
		RenderingServer.force_draw(false)
		var before := viewport.get_texture().get_image().get_data()
		for frame in 3: await process_frame
		RenderingServer.force_draw(false)
		var control := viewport.get_texture().get_image().get_data()
		check(before==control,"Frozen native reference changed between frames at %s litres" % liters)
		shader_support(bag,actual)
		for frame in 3: await process_frame
		RenderingServer.force_draw(false)
		var after := viewport.get_texture().get_image().get_data()
		check(control==after,"Native pouch contact pixels changed at %s litres" % liters)
	print("WATER BAG NATIVE PIXEL PARITY: ","PASS" if failures.is_empty() else "FAIL"," | empty/half/full at 640 x 640; images compared in memory")
func conservative_bounds_check() -> void:
	var probe: Node3D=load("res://player/water_bag_visual.gd").new()
	var random:=RandomNumberGenerator.new();random.seed=33129
	for sample in 128:
		probe.contact_points.append(Vector3(random.randf_range(-.5,.5),random.randf_range(-.3,.7),random.randf_range(-.3,.3)))
		var first:=random.randf_range(.01,.99)
		var total:=random.randf_range(.6,1.4)
		for index in 2:
			probe.contact_indices.append(index)
			probe.contact_weights.append(total*(first if index==0 else 1.0-first))
		probe.contact_offsets.append(probe.contact_indices.size())
	probe._prepare_contact_groups(Transform3D.IDENTITY)
	var rejected:=0
	for trial in 64:
		var palette: Array[Transform3D]=[]
		for index in 2:
			var basis:=Basis.from_euler(Vector3(random.randf_range(-1,1),random.randf_range(-1,1),random.randf_range(-1,1)))
			basis=basis.scaled(Vector3(random.randf_range(.5,1.5)*(-1 if trial%3==0 else 1),random.randf_range(.5,1.5),random.randf_range(.5,1.5)))
			palette.append(Transform3D(basis,Vector3(random.randf_range(-.4,.4),random.randf_range(-.4,.4),random.randf_range(-.4,.4))))
		var inverse:=Transform3D(Basis.from_euler(Vector3(.2,trial*.13,-.1)),Vector3(.1,.05,-.08))
		for group in probe.contact_groups:
			if not probe._contact_group_rejected(group,palette,inverse):continue
			for sample in group.samples:
				var vertex:=Vector3.ZERO
				for slot in range(probe.contact_offsets[sample],probe.contact_offsets[sample+1]):
					vertex+=(palette[probe.contact_indices[slot]]*probe.contact_points[sample])*probe.contact_weights[slot]
				var point:=inverse*vertex
				check(point.y<.005 or point.y>.285 or absf(point.x)>probe.contact_width_limit,"Bounds rejected an eligible sample under varied weights/transforms")
				rejected+=1
	# Independently check support pruning, including nonunit retained weights.
	var support_rejections:=0
	var palette: Array[Transform3D]=[Transform3D.IDENTITY,Transform3D(Basis.from_euler(Vector3(.2,.4,-.1)),Vector3(.05,-.03,.04))]
	for threshold in [0.0,.03,.1,.3,1.0]:
		for group in probe.contact_groups:
			if not probe._contact_group_rejected(group,palette,Transform3D.IDENTITY,threshold):continue
			for sample in group.samples:
				var point:=Vector3.ZERO
				for slot in range(probe.contact_offsets[sample],probe.contact_offsets[sample+1]):
					point+=(palette[probe.contact_indices[slot]]*probe.contact_points[sample])*probe.contact_weights[slot]
				if point.y<.005 or point.y>.285 or absf(point.x)>probe.contact_width_limit:continue
				var blend:=maxf(smoothstep(0.0,1.0,clampf((.41-point.y)/.29,0.0,1.0)),.1)
				check((point.z+.018)/blend-probe.HIP_SUPPORT<=threshold,"Support bound discarded a larger maximum")
				support_rejections+=1
	probe.free()
	check(support_rejections>10,"Support bound pruning was not exercised")
	check(rejected>1000,"Conservative bounds fixture did not exercise rejection")
	print("CONTACT CONSERVATIVE BOUNDS ",JSON.stringify({"rejected_samples_checked":rejected,"trials":64,"support_rejections":support_rejections,"status":"PASS" if failures.is_empty() else "FAIL"}))
func _run() -> void:
	conservative_bounds_check()
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	stage.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	var equipment: Node3D = actor.get_node("VisualRoot/EquipmentVisuals")
	var bag: Node3D = equipment.get_node("WaterBagVisual")
	bag.set_process(false)
	for frame in 3: await process_frame
	stop_scripts(stage)
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	# Match the main OpeningSequence garment replacement before first contact.
	preload("res://player/arjun_complete_fit.gd").new().apply(visual)
	# The real first query uses the authored standing attachment, before sway.
	bag.transform = Transform3D(Basis.IDENTITY,Vector3(.13,.175,-.09))
	bag.set_sway(0.0,0.0)
	if not bag.contact_ready: bag._prepare_cloth_contact()
	prepare_reference(bag)
	bag.use_contact_width_bound = true
	if "--trace-bag-contact" in OS.get_cmdline_user_args():
		print("CONTACT INIT UNIQUE ",JSON.stringify({"samples":bag.contact_points.size(),"exact_unique":exact_unique_samples(bag),"scope":"inventory only; original query unchanged"}))
	check(not reference_samples.is_empty(),"No real coat contact samples")
	check(reference_samples.size()==bag.contact_offsets.size()-1,"Contact sample selection changed")
	var maximum_error := 0.0
	var poses_checked := 0
	var scanned: Array[int]=[]
	var maximum_required:=0.0
	var maximum_pin_error:=0.0
	for spec in [[0.0,false],[1.0,false],[1.7,false],[1.0,true]]:
		for frame in 60:
			visual.motion_tree.update_motion(1.0/60.0,spec[0],spec[0],spec[1],not spec[1],0.0)
			actor.rotation.y = frame*.07
			actor.position = Vector3(640,12,235)
			actor.velocity = Vector3(0,0,spec[0]*4.0)
			equipment._process(1.0/60.0)
			var expected := reference(bag)
			var original: float = bag._cloth_contact_required(true)
			var actual: float = bag._cloth_contact_required()
			scanned.append(bag.contact_samples_scanned)
			maximum_required=maxf(maximum_required,actual)
			bag.use_contact_groups=false
			var ungrouped:float=bag._cloth_contact_required()
			bag.use_contact_groups=true
			check(ungrouped==actual,"Grouped bounds changed exact support at pose %d" % poses_checked)
			check(original==actual,"Width rejection changed exact cached contact at pose %d" % poses_checked)
			maximum_error = maxf(maximum_error,absf(expected-actual))
			check(absf(expected-actual)<.00002,"Cached coat contact changed at pose %d" % poses_checked)
			bag.cloth_support = 0.0
			bag._update_cloth_contact(1.0/60.0)
			check(absf(bag.cloth_support-clampf(expected,0,.30))<.00002,"Immediate coat support changed")
			var pin_error:float=bag.belt_pin_world().distance_to(bag.global_position)
			maximum_pin_error=maxf(maximum_pin_error,pin_error)
			# World x=640 uses float32 coordinates (~61 micrometre ULP).
			# Check the attachment itself in local space as well as world rounding.
			check((bag.pouch.transform*bag.BELT_PIN).length()<.000001,"Local sash carry loop detached")
			check(pin_error<.0001,"World sash pin exceeds float32 rounding: %s" % pin_error)
			poses_checked += 1
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	for round_index in 9:
		for variant in ([0,1] if round_index%2==0 else [1,0]):
			var started := Time.get_ticks_usec()
			for repeat in 30:
				if variant == 0: reference(bag)
				else: bag._cloth_contact_required()
			(old_times if variant==0 else new_times).append(Time.get_ticks_usec()-started)
	old_times.sort()
	new_times.sort()
	var bound_times: Array[int] = []
	var full_times: Array[int] = []
	for round_index in 9:
		for full_scan in ([true,false] if round_index%2==0 else [false,true]):
			var started := Time.get_ticks_usec()
			for repeat in 30: bag._cloth_contact_required(full_scan)
			(full_times if full_scan else bound_times).append(Time.get_ticks_usec()-started)
	full_times.sort()
	bound_times.sort()
	print("CONTACT INIT WIDTH COST ",JSON.stringify({"full_30_calls_us":full_times[4],"bounded_30_calls_us":bound_times[4],"width_m":bag.contact_width_limit,"exact_parity":failures.is_empty()}))
	var grouped_times: Array[int]=[]
	var ungrouped_times: Array[int]=[]
	for round_index in 9:
		for grouped in ([true,false] if round_index%2==0 else [false,true]):
			bag.use_contact_groups=grouped
			var started:=Time.get_ticks_usec()
			for repeat in 30:bag._cloth_contact_required()
			(grouped_times if grouped else ungrouped_times).append(Time.get_ticks_usec()-started)
	bag.use_contact_groups=true
	grouped_times.sort();ungrouped_times.sort();scanned.sort()
	print("CONTACT GROUP COST ",JSON.stringify({"original_30_calls_us":ungrouped_times[4],"grouped_30_calls_us":grouped_times[4],"groups":bag.contact_groups.size(),"samples":bag.contact_points.size(),"scanned_min_median_max":[scanned[0],scanned[120],scanned[-1]],"maximum_required":maximum_required,"maximum_world_pin_error_m":maximum_pin_error,"exact_parity":failures.is_empty()}))
	bag.held = true
	bag.cloth_support = .1
	bag._update_cloth_contact(.2)
	check(is_equal_approx(bag.cloth_support,.07),"Held pouch recovery changed")
	var rebuilds: int = bag.mesh_rebuilds
	bag._update_cloth_contact(.1)
	check(bag.mesh_rebuilds==rebuilds,"Contact update rebuilt the pouch mesh")
	if DisplayServer.get_name()!="headless": await rendered_parity(stage,bag,actor)
	print("WATER BAG CONTACT CACHE ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","poses":poses_checked,"samples":reference_samples.size(),"influencing_bones":bag.contact_bones.size(),"max_support_error_m":maximum_error,"reference_30_calls_us":old_times[4],"cached_30_calls_us":new_times[4],"scope":"real rig idle/walk/run/swim, contact calculation parity; timings are same-run subsystem costs"}))
	await root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
