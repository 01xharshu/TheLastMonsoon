extends SceneTree
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
const Reference = preload("res://tools/characters/npc_animation_reference.gd")
const Humans = preload("res://characters/human_scene.gd")
var failed := false
var keys := 0
var maximum_time_error := 0.0
var maximum_rotation_error := 0.0
func check(ok: bool, label: String) -> void:
	if not ok:
		if failed:return
		failed=true
		push_error(label)
func _initialize() -> void: _run.call_deferred()
func create_actor(script: Script, path: String, profile: StringName) -> Node3D:
	var actor: Node3D = script.new()
	actor.movement_profile=profile
	actor.movement_enabled=false
	# Match the errand caller's explicit read-only imported-animation path.
	actor.add_child(Humans.instantiate(path,script==Reference))
	root.add_child(actor)
	actor.set_process(false)
	return actor
func pixels(original: Node3D, cached: Node3D, other: Node3D) -> void:
	original.process_mode=Node.PROCESS_MODE_DISABLED
	cached.process_mode=Node.PROCESS_MODE_DISABLED
	other.hide()
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(480,640)
	viewport.world_3d=root.world_3d
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	camera.position=Vector3(1.6,1.15,3)
	camera.look_at(Vector3(0,.9,0))
	camera.current=true
	var light:=DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees=Vector3(-35,-25,0)
	root.disable_3d=true
	for state in [&"idle",&"walk",&"turn"]:
		original._set_animation(state,.2)
		cached._set_animation(state,.2)
		original.show();cached.hide()
		RenderingServer.force_draw(false)
		var expected:=viewport.get_texture().get_image().get_data()
		RenderingServer.force_draw(false)
		check(expected==viewport.get_texture().get_image().get_data(),"Frozen pixel control changes")
		original.hide();cached.show()
		RenderingServer.force_draw(false)
		check(expected==viewport.get_texture().get_image().get_data(),"Cached NPC pixels differ: "+String(state))
	viewport.free();light.free()
	root.disable_3d=false
func _run() -> void:
	for spec in [["village_farmer",&"male"],["village_woman",&"female"],["errand_passenger",&"male"]]:
		var path := "res://characters/npcs/motion/%s/%s_rigged_candidate.glb" % [spec[0],spec[0]]
		if spec[0]=="errand_passenger":path="res://characters/npcs/motion/errand_passenger/errand_passenger.glb"
		var original := create_actor(Reference,path,spec[1])
		var first := create_actor(Actor,path,spec[1])
		var cached := create_actor(Actor,path,spec[1])
		check(original._skeleton!=first._skeleton and original._skeleton.get_bone_count()==first._skeleton.get_bone_count(),"Caller skeleton is shared or incomplete")
		var original_meshes:=original.find_children("*","MeshInstance3D",true,false)
		var cached_meshes:=first.find_children("*","MeshInstance3D",true,false)
		check(original_meshes.size()==cached_meshes.size(),"Caller loses mesh nodes")
		for index in mini(original_meshes.size(),cached_meshes.size()):
			check(original_meshes[index].mesh==cached_meshes[index].mesh,"Caller body or clothing geometry differs")
		for name in ["idle","walk","turn"]:
			var expected: Animation=original.animation_player.get_animation(name)
			var actual: Animation=cached.animation_player.get_animation(name)
			check(actual!=first.animation_player.get_animation(name),"Actors share mutable "+name)
			check(actual.length==expected.length and actual.get_track_count()==expected.get_track_count(),"Clip layout differs")
			for track in expected.get_track_count():
				check(actual.track_get_path(track)==expected.track_get_path(track),"Rig track path differs")
				for key in expected.track_get_key_count(track):
					keys+=1
					maximum_time_error=maxf(maximum_time_error,absf(actual.track_get_key_time(track,key)-expected.track_get_key_time(track,key)))
					var a:Quaternion=actual.track_get_key_value(track,key)
					var b:Quaternion=expected.track_get_key_value(track,key)
					maximum_rotation_error=maxf(maximum_rotation_error,maxf(absf(a.x-b.x),maxf(absf(a.y-b.y),maxf(absf(a.z-b.z),absf(a.w-b.w)))))
			actual.track_set_key_value(0,0,Quaternion(Vector3.UP,.5))
			check(first.animation_player.get_animation(name).track_get_key_value(0,0)==expected.track_get_key_value(0,0),"Editing one actor changes another")
		check(cached.nominal_walk_speed==original.nominal_walk_speed,"Stride calibration differs")
		if DisplayServer.get_name()!="headless":pixels(original,first,cached)
		var reference_times: Array[int]=[]
		var cached_times: Array[int]=[]
		for round_index in 9:
			for variant in ([0,1] if round_index%2==0 else [1,0]):
				var actor:Node3D=original if variant==0 else first
				var start:=Time.get_ticks_usec()
				for cycle in 6:
					actor._make_clip(false)
					actor._make_clip(true)
					actor._make_clip(false,true)
				(reference_times if variant==0 else cached_times).append(Time.get_ticks_usec()-start)
		var clip:Animation=first.animation_player.get_animation("walk")
		var start:=Time.get_ticks_usec()
		for cycle in 12:original._measure_stride(clip)
		var reference_stride:=Time.get_ticks_usec()-start
		start=Time.get_ticks_usec()
		for cycle in 12:first._measure_stride(clip)
		var cached_stride:=Time.get_ticks_usec()-start
		var original_setup: Array[int]=[]
		var cached_setup: Array[int]=[]
		for round_index in 7:
			var actors: Array[Node3D]=[]
			for variant in ([0,1] if round_index%2==0 else [1,0]):
				start=Time.get_ticks_usec()
				var instance:=create_actor(Reference if variant==0 else Actor,path,spec[1])
				(original_setup if variant==0 else cached_setup).append(Time.get_ticks_usec()-start)
				actors.append(instance)
			await process_frame
			for instance in actors:instance.free()
		original_setup.sort();cached_setup.sort()
		reference_times.sort();cached_times.sort()
		print("NPC ANIMATION CACHE ",JSON.stringify({"model":spec[0],"reference_18_clips_us":reference_times[4],"cached_18_clips_us":cached_times[4],"reference_12_stride_us":reference_stride,"cached_12_stride_us":cached_stride,"reference_actor_setup_us":original_setup[3],"cached_actor_setup_us":cached_setup[3],"setup_scope":"warm base caller setup with read-only imported clips, excludes deferred combat setup and world spawn search"}))
		# Deferred combat setup must finish before freeing its receiver.
		await process_frame
		original.free();first.free();cached.free()
	check(Actor._clip_templates.size()<=Actor.CLIP_TEMPLATE_LIMIT,"Template cache exceeds its bound")
	# Distinct profile keys exercise eviction and must not alter a live actor's
	# private clips. No additional human geometry is created for this check.
	var actor:=create_actor(Actor,"res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb",&"male")
	var preserved:Animation=actor.animation_player.get_animation("idle")
	var preserved_key:Quaternion=preserved.track_get_key_value(0,0)
	for variant in 40:
		actor.movement_profile=StringName("cache_test_%d"%variant)
		actor._make_clip(false)
		check(Actor._clip_templates.size()<=Actor.CLIP_TEMPLATE_LIMIT,"Cache eviction exceeds bound")
	check(preserved.track_get_key_value(0,0)==preserved_key,"Eviction alters a live actor")
	await process_frame
	actor.free()
	print("NPC ANIMATION CACHE ERRORS time ",maximum_time_error," rotation ",maximum_rotation_error)
	if DisplayServer.get_name()!="headless":print("NPC ANIMATION CACHE NATIVE PIXELS: ","FAIL" if failed else "PASS"," | idle/walk/turn on three real rigs; compared in memory")
	check(maximum_time_error==0 and maximum_rotation_error==0,"Animation samples differ")
	print("NPC ANIMATION CACHE: ","FAIL" if failed else "PASS"," | ",keys," exact keys, private clips and calibrated stride across three real rigs")
	await root.get_node("SaveManager").quit_game(1 if failed else 0)
