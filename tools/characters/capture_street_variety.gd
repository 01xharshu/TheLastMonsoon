extends SceneTree
## Disposable target-renderer review of the exact MPFB street exports.
var output:=OS.get_environment("TLM_VARIETY_OUTPUT")
var only:=OS.get_environment("TLM_VARIETY_ID")
func _initialize()->void:run.call_deferred()
func run()->void:
	if output.is_empty():push_error("Temporary output folder required");quit(2);return
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);world.add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6;world.add_child(environment)
	var builder:Node3D=load("res://world/suryagarh/settlements/settlement_builder.gd").new()
	builder.piece(world,"ReviewFloor",Vector3(0,-.05,0),Vector3(18,.1,18),builder.material(Color(.30,.26,.20)));builder.free()
	var view:=SubViewport.new();view.size=Vector2i(1280,720);view.world_3d=world.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);root.disable_3d=true
	var camera:=Camera3D.new();camera.fov=40;view.add_child(camera);camera.current=true
	var actors:Array[Node3D]=[]
	for sex in ["female","workman"]:
		for index in 4:
			if not only.is_empty() and only!="%s_%02d"%[sex,index+1]:continue
			var actor:Node3D=load("res://characters/npcs/indian/indian_street_actor.gd").new();actor.name="%s_%02d"%[sex,index+1];actor.movement_enabled=false
			actor.movement_profile=&"female" if sex=="female" else &"male"
			actor.add_child(load("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/%s.glb"%actor.name,false));world.add_child(actor);actor.position=Vector3(index*3,0,0 if sex=="female" else 4);actors.append(actor)
			await physics_frame
	
	for actor in actors:
		for side in [-1,1]:
			camera.global_position=actor.global_position+Vector3(.3,1.3,side*3.1);camera.look_at(actor.global_position+Vector3(0,.9,0))
			for frame in 45:
				actor._set_animation(&"walk",1.0/60);await physics_frame
			await process_frame;RenderingServer.force_draw(false)
			view.get_texture().get_image().save_png(output+"/"+actor.name+("_front" if side>0 else "_back")+".png")
	print("STREET_VARIETY_CAPTURE characters=",actors.size()," views=",actors.size()*2)
	world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0)
