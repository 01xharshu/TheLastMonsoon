extends SceneTree
const Grass=preload("res://world/suryagarh/grass_render_meshes.gd")
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void:run.call_deferred()
func sample() -> Dictionary:
	for frame in 30:await process_frame
	var samples:Array[float]=[]
	var tick:=Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now:=Time.get_ticks_usec();samples.append((now-tick)/1000.0);tick=now
	samples.sort()
	RenderingServer.force_draw()
	return {"p50":samples[60],"p95":samples[114],"draws":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),"image":root.get_texture().get_image()}
func freeze(code:String) -> String:
	code=code.replace("global uniform vec3 world_wind;","uniform vec3 world_wind = vec3(0.45, 2.5, 0.3);")
	for i in 4:code=code.replace("global uniform vec4 grass_vehicle_%d;"%i,"uniform vec4 grass_vehicle_%d = vec4(0.0);"%i)
	return code
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Grass shader parity requires native rendering");quit(2);return
	var path:=OS.get_environment("TLM_GRASS_BASELINE_SHADER")
	assert(not path.is_empty(),"Set TLM_GRASS_BASELINE_SHADER to a baseline shader in OS-temp")
	var shaders:Array[Shader]=[]
	for code in [FileAccess.get_file_as_string(path),FileAccess.get_file_as_string("res://world/suryagarh/shaders/grass_blades.gdshader")]:
		var shader:=Shader.new();shader.code=freeze(code);shaders.append(shader)
	var world:=Node3D.new();root.add_child(world)
	var landscape:Node3D=load("res://world/suryagarh/generated/landscape.scn").instantiate();world.add_child(landscape)
	await Grass.configure_landscape(landscape)
	var materials:Dictionary={}
	for batch in landscape.get_node("NatureTiles").find_children("Grass*","MultiMeshInstance3D",true,false):
		var mesh:Mesh=batch.multimesh.mesh
		if materials.has(mesh):continue
		var material:ShaderMaterial=mesh.surface_get_material(0).duplicate();mesh.surface_set_material(0,material);materials[mesh]=material
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-32,0);world.add_child(sun)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.far=1500
	var layout:=Layout.new()
	for row in [[-800.0,-600.0],[-500.0,-300.0]]:
		var position:=Vector3(row[0],layout.height(row[0],row[1])+1.65,row[1])
		camera.position=position;camera.look_at(position+Vector3(20,-1.4,-20))
		for active in [false,true]:
			var images:Array[PackedByteArray]=[]
			var times:Array=[]
			for shader in [shaders[0],shaders[1],shaders[0]]:
				for material in materials.values():
					material.shader=shader
					material.set_shader_parameter("grass_vehicle_0",Vector4(position.x,position.y-1.65,position.z-3.0,.8) if active else Vector4.ZERO)
				var result:=await sample();images.append(result.image.get_data());result.erase("image");times.append(result)
			assert(images[0]==images[1] and images[0]==images[2],"Grass shader changed pixels")
			print("GRASS SHADER PASS view=",row," active_wake=",active," exact A/B/A pixels; baseline/candidate/repeat=",times)
	world.free();print("GRASS SHADER ALL PASS");quit()
