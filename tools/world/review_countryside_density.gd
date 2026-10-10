extends SceneTree
## Native appearance/contact review. Caller owns/deletes all temporary output.
const Density=preload("res://world/suryagarh/settlements/countryside_density.gd")
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var main:=not "--isolated" in OS.get_cmdline_user_args()
	var world:Node3D
	if main:world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	else:
		world=Node3D.new();world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate());world.add_child(load("res://world/suryagarh/generated/countryside_density.scn").instantiate())
	root.add_child(world);current_scene=world
	var camera:=Camera3D.new();world.add_child(camera);camera.far=1800;camera.make_current()
	if not main:
		var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-48,-30,0);sun.light_energy=1.3;sun.shadow_enabled=true
		var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.47,.59,.68)
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.7,.75,.8);env.environment.ambient_light_energy=.65;world.add_child(env)
	else:
		world.get_node("Player").set_physics_process(false);world.get_node("Player").position=Vector3(-464,10,200)
		world.get_node("Player/UI").hide();world.get_node("LandscapeUI").hide()
	var started:=Time.get_ticks_msec()
	if main:
		while not world.get_node("Settlement").has_meta("bhairavpur_home_count") and Time.get_ticks_msec()-started<90000:await process_frame
	for i in 30:await process_frame
	var homes:=get_nodes_in_group("density_home");var fields:=get_nodes_in_group("density_field")
	if homes.size()!=25:errors.append("expected 25 additional rural buildings")
	if fields.size()!=24:errors.append("expected 24 cultivated plots")
	# Test the real capsule walking from the terrain approach into every new house.
	var capsule:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var cs:=CapsuleShape3D.new();cs.radius=.3;cs.height=1.7;shape.shape=cs;capsule.add_child(shape);capsule.floor_snap_length=.3;world.add_child(capsule)
	var ground:=preload("res://tools/world/density_ground.gd").new();ground.configure(world.get_node("Landscape"))
	var density:Node3D=world.get_node("CountrysideDensity")
	var road_samples:=0
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=cs;query.collision_mask=1
	var routes:Array=preload("res://world/suryagarh/landscape_layout.gd").ROUTES.values()+Density.lanes()
	for route in routes:
		for segment in range(route.size()-1):
			var a:Vector2=route[segment];var b:Vector2=route[segment+1]
			var side:=Vector2(-(b-a).y,(b-a).x).normalized()
			var count:=ceili(a.distance_to(b)/3)
			for step in count+1:
				for offset in [-1.2,0.0,1.2]:
					var p:Vector2=a.lerp(b,float(step)/maxi(1,count))+side*offset
					if p.x < -800 or p.x > -230 or p.y < -450 or p.y > 420:continue
					query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,ground.height(p.x,p.y)+.96,p.y))
					for hit in world.get_world_3d().direct_space_state.intersect_shape(query,32):
						if density.is_ancestor_of(hit.collider) and not "DoorApproach" in str(hit.collider.get_path()):
							var issue:="road obstructed by "+str(hit.collider.get_path())
							if not errors.has(issue):errors.append(issue)
					road_samples+=1
	print("DENSITY_ROAD samples=",road_samples," errors=",errors)
	var contacts:=0
	for house:Node3D in homes:
		if "--views-only" in OS.get_cmdline_user_args():break
		var ramp:Node3D=house.find_children("DoorApproach","Node3D",true,false)[0]
		var box:BoxShape3D=ramp.find_children("*","CollisionShape3D",true,false)[0].shape
		var outside:Vector3=ramp.to_global(Vector3(0,.09,box.size.z*.5+.15))
		capsule.position=Vector3(outside.x,ground.height(outside.x,outside.z)+1.2,outside.z)
		var target:Vector3=house.to_global(Vector3(0,1.1,0))
		for frame in 300:
			await physics_frame
			var delta:=target-capsule.position;delta.y=0
			if delta.length()<.3:break
			var direction:=delta.normalized();capsule.velocity.x=direction.x*5;capsule.velocity.z=direction.z*5
			capsule.velocity.y-=18.0/60;capsule.move_and_slide()
		if Vector2(capsule.position.x-target.x,capsule.position.z-target.z).length()>1:errors.append(str(house.name)+": blocked approach at "+str(capsule.position)+" target "+str(target))
		else:contacts+=1
	capsule.queue_free()
	print("DENSITY_CONTACT walked=",contacts," errors=",errors)
	if "--contact-only" in OS.get_cmdline_user_args():
		await root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1);return
	var folder:=OS.get_environment("TLM_DENSITY_TEMP")
	var poses:=[
		["village",Vector3(-498,36,352),Vector3(-437,7,242)],
		["village_lane",Vector3(-464,13,226),Vector3(-464,7,310)],
		["farmland",Vector3(-675,75,160),Vector3(-550,9,-95)],
		["farm_lane",Vector3(-570,15,121),Vector3(-570,7,65)],
		["city_edge",Vector3(-487,25,-300),Vector3(-437,8,-396)]]
	for pose in poses:
		camera.position=pose[1];camera.look_at(pose[2])
		for frame in 15:await process_frame
		await RenderingServer.frame_post_draw
		if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(pose[0]+".png"))
	camera.position=Vector3(-500,16,230);camera.look_at(Vector3(-450,7,260))
	var samples:Array[float]=[];var previous:=Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now:=Time.get_ticks_usec();samples.append(float(now-previous)/1000);previous=now
	samples.sort();print("DENSITY_REVIEW ",JSON.stringify({"main_world":main,"homes":homes.size(),"fields":fields.size(),"walked_entrances":contacts,"median_ms":samples[60],"p95_ms":samples[114],"viewport":root.size,"road_samples":road_samples,"shelterbelt_trees":density.get_meta("shelterbelt_trees",0),"render_scale":root.scaling_3d_scale,"errors":errors}))
	await root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1)
