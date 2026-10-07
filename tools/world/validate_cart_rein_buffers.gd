extends SceneTree
## Real cart variants: fixed topology, triangle parity, attachment and distance LOD.
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(0,3,8)
	camera.look_at(Vector3(0,1,0))
	camera.make_current()
	for kind in 3:
		var cart: Node3D=load("res://vehicles/family_carriage_candidate.gd" if kind==2 else "res://vehicles/horse_cart_candidate.gd").new()
		if kind<2: cart.variant=kind
		world.add_child(cart)
		await process_frame
		var reins: Node3D=cart.get_node("FlexibleReins")
		reins.set_process(false)
		reins.distance_lod_enabled=false
		var buffers: Array[RID]=[]
		for entry in reins.reins: buffers.append(entry.strip.multimesh.get_rid())
		for frame in 120:
			reins._process(1.0/60.0)
			await process_frame
		for i in reins.reins.size():
			var entry: Dictionary=reins.reins[i]
			var batch: MultiMesh=entry.strip.multimesh
			check(batch.get_rid()==buffers[i],"Rein buffer was replaced")
			check(batch.instance_count==reins.SEGMENTS,"Rein topology changed")
			check(entry.points[0].distance_to(entry.rendered_pins[0])<.0001 and entry.points[-1].distance_to(entry.rendered_pins[1])<.0001,"Rein endpoints detached")
			for segment in reins.SEGMENTS:
				# Dummy rendering has no MultiMesh transform readback.
				if DisplayServer.get_name()=="headless": break
				var a: Vector3=reins.to_local(entry.points[segment])
				var b: Vector3=reins.to_local(entry.points[segment+1])
				var across: Vector3=(b-a).cross(Vector3.UP).normalized()*.009
				var transform:=batch.get_instance_transform(segment)
				check((transform*Vector3(-.5,-.5,0)).distance_to(a-across)<.00001 and (transform*Vector3(.5,.5,0)).distance_to(b+across)<.00001,"Rein quad differs from original strip")
		reins.distance_lod_enabled=true
		camera.position=Vector3(0,0,260)
		for frame in 30: reins._process(1.0/60.0)
		var before: int=reins.detail_updates
		for frame in 30: reins._process(1.0/60.0)
		check(not reins.visible and reins.detail_updates==before,"Far reins continued updates")
		camera.position=Vector3(0,3,8)
		for frame in 30: reins._process(1.0/60.0)
		check(reins.visible and reins.detail_updates>before,"Near reins did not resume")
		cart.queue_free()
		await process_frame
	print("CART REIN BUFFERS: ","FAIL" if failed else "PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(1 if failed else 0)
