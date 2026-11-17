extends SceneTree
const Index = preload("res://world/suryagarh/grass_render_meshes.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Grass geometry/pixel validation requires native rendering");quit(2);return
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(0,1.3,3)
	camera.look_at(Vector3(0,.25,0))
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-30,0)
	world.add_child(sun)
	RenderingServer.global_shader_parameter_set("world_wind",Vector3.ZERO)
	for path in ["res://world/suryagarh/generated/wilderness_expansion/grass_bermuda_01.res","res://world/suryagarh/generated/wilderness_expansion/grass_detail.res"]:
		var source: ArrayMesh=load(path)
		var candidate := Index.indexed(source)
		var material: ShaderMaterial=source.surface_get_material(0).duplicate()
		material.shader=Shader.new()
		material.shader.code=source.surface_get_material(0).shader.code.replace("global uniform vec3 world_wind;","uniform vec3 world_wind = vec3(0.0);")
		source.surface_set_material(0,material)
		candidate.surface_set_material(0,material)
		var old := source.surface_get_arrays(0)
		var fresh := candidate.surface_get_arrays(0)
		var indices: PackedInt32Array=fresh[Mesh.ARRAY_INDEX]
		var old_indices: PackedInt32Array=old[Mesh.ARRAY_INDEX] if old[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var triangles: int = old_indices.size() if not old_indices.is_empty() else old[Mesh.ARRAY_VERTEX].size()
		assert(indices.size()==triangles)
		for index in triangles:
			var original: int = old_indices[index] if not old_indices.is_empty() else index
			for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:
				if attribute == Mesh.ARRAY_NORMAL:
					assert(old[attribute][original].distance_to(fresh[attribute][indices[index]])<.0002,"Normal quantization exceeded tolerance")
				else: assert(old[attribute][original]==fresh[attribute][indices[index]],"Changed grass attribute")
		assert(candidate.get_aabb()==source.get_aabb())
		assert(fresh[Mesh.ARRAY_VERTEX].size()<old[Mesh.ARRAY_VERTEX].size())
		var batch := MultiMeshInstance3D.new()
		batch.multimesh=MultiMesh.new()
		batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.instance_count=10000
		for i in 10000: batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3((i%100-50)*.06,0,(i/100-50)*.06)))
		world.add_child(batch)
		var images: Array[PackedByteArray]=[]
		var times: Array=[]
		for mesh in [source,candidate,source]:
			batch.multimesh.mesh=mesh
			for frame in 30: await process_frame
			var samples: Array[float]=[]
			var tick := Time.get_ticks_usec()
			for frame in 120:
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append((now-tick)/1000.0)
				tick=now
			samples.sort()
			times.append([samples[60],samples[114]])
			RenderingServer.force_draw()
			images.append(root.get_texture().get_image().get_data())
		var maximum_delta := 0
		var changed_bytes := 0
		for byte in images[0].size():
			var difference := absi(int(images[0][byte])-int(images[1][byte]))
			maximum_delta=maxi(maximum_delta,difference)
			if difference>0: changed_bytes+=1
		print("PIXELS max channel delta=",maximum_delta," changed bytes=",changed_bytes," repeat=",images[0]==images[2])
		assert(maximum_delta<=2,"Visible render regression")
		assert(images[0]==images[2],"Baseline unstable")
		print("GRASS INDEX PASS ",path," vertices ",old[Mesh.ARRAY_VERTEX].size()," -> ",fresh[Mesh.ARRAY_VERTEX].size()," indices ",indices.size()," positions/UV/colors exact; normals within0.0002; bounds exact; baseline/candidate/repeat p50,p95ms ",times)
		batch.free()
	for path in ["res://world/suryagarh/generated/landscape.scn","res://world/suryagarh/generated/wilderness_expansion/wilderness_expansion.scn"]:
		var landscape: Node3D=load(path).instantiate()
		world.add_child(landscape)
		var records: Dictionary={}
		for batch in landscape.get_node("NatureTiles").find_children("Grass*","MultiMeshInstance3D",true,false): records[batch]=[batch.multimesh.buffer,batch.multimesh.mesh,batch.multimesh.get_aabb()]
		var start := Time.get_ticks_usec()
		var count := await Index.configure_landscape(landscape)
		var setup_ms := (Time.get_ticks_usec()-start)/1000.0
		for batch in records:
			assert(records[batch][0]==batch.multimesh.buffer,"Placement changed")
			assert(records[batch][1]==batch.multimesh.mesh,"Shared mesh identity changed")
			assert(records[batch][2]==batch.multimesh.get_aabb(),"Culling bounds changed")
		var mesh_arrays:Dictionary={}
		for batch in records:
			var mesh: ArrayMesh=batch.multimesh.mesh
			if not mesh_arrays.has(mesh):mesh_arrays[mesh]=mesh.surface_get_arrays(0)
		await Index.configure_landscape(landscape)
		for mesh in mesh_arrays:assert(mesh_arrays[mesh]==mesh.surface_get_arrays(0),"Repeated setup changed mesh")
		print("ACTUAL LANDSCAPE PASS ",path," batches=",count," unchanged buffers/mesh identities/bounds; idempotent setup ms=",setup_ms)
		landscape.free()
	world.free()
	quit()
