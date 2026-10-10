extends SceneTree
## Full-world native review and current render-budget sample. Optional captures are OS-temp only.
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false)
	player.global_position=Vector3(-310,8.24,-362)
	world.get_node("Player/UI").hide();world.get_node("LandscapeUI").hide()
	var camera:=Camera3D.new();camera.far=2200;world.add_child(camera);camera.make_current()
	var started:=Time.get_ticks_msec()
	while (not world.has_node("UrbanWest") or not world.get_node("UrbanWest").classified) and Time.get_ticks_msec()-started<120000:await process_frame
	if not world.has_node("UrbanWest") or not world.get_node("UrbanWest").classified:errors.append("city/community setup did not finish")
	var city:Node=world.get_node("UrbanWest")
	if city.homes.size()!=26:errors.append("missing through homes")
	player.global_position=Vector3(-310,8.24,-362)
	var community:Node=world.get_node("StoryCommunity")
	if community.college.global_position.distance_to(community.courtyard.global_position)>40:errors.append("café not beside college")
	var rebels:=0
	for actor in community.residents:
		if actor.get_meta("political_role","")=="educated_rebel":rebels+=1
	if rebels!=2:errors.append("rebel readers missing from student crowd")
	var layout:=preload("res://world/suryagarh/landscape_layout.gd").new()
	for route_name in ["city_front_street","city_rear_lane","city_back_street","city_hospital_road"]:
		for point:Vector2 in layout.ROUTES[route_name]:
			var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,12,point.y),Vector3(point.x,4,point.y),preload("res://world/suryagarh/tree_trunk_collision.gd").TERRAIN_SUPPORT_LAYER)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or absf(hit.position.y-layout.height(point.x,point.y))>.04:errors.append(route_name+": saved terrain mismatch")
	camera.global_position=Vector3(-260,100,-265);camera.look_at(Vector3(-340,8,-415))
	for frame in 60:await process_frame
	var samples:Array[float]=[];var previous:=Time.get_ticks_usec()
	for frame in 180:
		await process_frame
		var now:=Time.get_ticks_usec();samples.append(float(now-previous)/1000);previous=now
	samples.sort()
	var poses:=[
		["city_overview",Vector3(-240,155,-235),Vector3(-340,8,-420)],
		["connected_homes",Vector3(-252,17,-329),Vector3(-315,10,-355)],
		["college_cafe",Vector3(-338,22,-440),Vector3(-385,9,-510)],
		["civilian_hospital",Vector3(-220,14,-358),Vector3(-205,9,-390)]]
	var folder:=OS.get_environment("TLM_URBAN_REVIEW_TEMP")
	for pose in poses:
		camera.global_position=pose[1];camera.look_at(pose[2])
		for frame in 8:await process_frame
		if not folder.is_empty() and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(pose[0]+".png"))
	print("URBAN_WORLD_REVIEW ",JSON.stringify({"passed":errors.is_empty(),"homes":city.homes.size(),"community_residents":community.residents.size(),"community_pending":community.pending.size(),"venues":community.residents.map(func(actor):return str(actor.get_parent().name)),"rebel_readers":rebels,"median_ms":samples[90],"p95_ms":samples[171],"render_scale":root.scaling_3d_scale,"window_pixels":[root.size.x,root.size.y],"city_walkers":world.get_node("CityRoutePopulation").pedestrians.filter(func(actor):return str(actor.get_meta("population_route","")).begins_with("city_")).size(),"errors":errors,"scope":"placed district, saved terrain and full-world native view; FPS and final asset art remain separate"}))
	quit(0 if errors.is_empty() else 1)
