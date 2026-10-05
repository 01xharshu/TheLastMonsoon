extends SceneTree
var errors:Array[String]=[]
func check(value:bool,label:String)->void:
	if not value:errors.append(label);push_error(label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	create_timer(120).timeout.connect(func():quit(2))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world);current_scene=world
	world.get_node("Player").set_physics_process(false);world.get_node("Player").hide();world.get_node("Player/UI").hide();world.get_node("LandscapeUI").hide()
	for frame in 8:await physics_frame
	var streets:Node3D=get_nodes_in_group("village_street_life")[0]
	for journey in streets.journeys:journey.set_physics_process(false)
	check(streets.lanes.size()==9,"nine earth road/foot approach strips")
	var surface_error:=0.0
	var query:=PhysicsRayQueryParameters3D.new();query.collision_mask=1
	var space:=streets.get_world_3d().direct_space_state
	var samples:=0
	for i in range(0,streets.surface_samples.size(),24):
		var point:Vector3=streets.surface_samples[i]
		query.from=point+Vector3.UP*.08;query.to=point-Vector3.UP*.12
		var hit:=space.intersect_ray(query)
		if not hit.is_empty():surface_error=maxf(surface_error,absf(point.y-hit.position.y));samples+=1
	check(surface_error<.025,"lane strips conform within 25 mm of actual ground")
	var clock:Node=world.get_node("GameTimeSystem")
	clock.clock_paused=true;clock.current_hour=12
	var report_paths:Array=[]
	for journey in streets.journeys:
		var actor:Node3D=journey.actor
		var shape:CollisionShape3D=actor.get_node("BodyCollider/BodyShape")
		var clearance:=PhysicsShapeQueryParameters3D.new();clearance.shape=shape.shape;clearance.collision_mask=1;clearance.exclude=[actor.get_node("BodyCollider").get_rid()]
		var blocked:=0;var checks:=0
		for segment in journey.route.size()-1:
			var a:Vector2=journey.route[segment];var b:Vector2=journey.route[segment+1]
			var steps:=maxi(1,ceili(a.distance_to(b)/.4))
			for step in steps+1:
				var p:=a.lerp(b,float(step)/steps)
				clearance.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,streets.layout.height(p.x,p.y)+.03+shape.position.y,p.y))
				var hit:=space.intersect_shape(clearance,1);checks+=1
				if not hit.is_empty():
					blocked+=1
					print("STREET_BLOCK ",actor.name," ",p," ",str(hit[0].collider.get_path()))
		check(blocked==0,str(actor.name)+" complete home/market path clearance")
		journey.wait=0
		var start:Vector3=actor.global_position
		for frame in 240:journey.tick(1.0/60)
		check(actor.global_position.distance_to(start)>1.5,str(actor.name)+" real movement and cadence")
		check(actor.animation_state==&"walk",str(actor.name)+" walk tree active")
		for frame in 1600:journey.tick(.25)
		check(journey.visits>=2,str(actor.name)+" completes market and home visits")
		clock.current_hour=20
		for frame in 800:journey.tick(.25)
		var home:Vector2=journey.route[0]
		check(Vector2(actor.global_position.x,actor.global_position.z).distance_to(home)<.06,str(actor.name)+" returns home at night")
		clock.current_hour=12
		report_paths.append({"actor":str(actor.name),"clearance_samples":checks,"blocked":blocked,"travel_m":journey.distance_walked,"cadence":actor.walk_playback_rate})
	if DisplayServer.get_name()!="headless":
		var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=48
		camera.global_position=Vector3(-331,16,293);camera.look_at(Vector3(-322,7.7,273))
		await _save("village_earth_market")
		# Place the first resident on the validated aisle, then advance a real walk.
		var journey:Node=streets.journeys[0];journey.actor.global_position=Vector3(-348,7.2,275);journey.goal=journey.route.size()-2;journey.direction=1;journey.wait=0;journey.actor.foot_plant.clear()
		for side in ["l","r"]:journey.actor.foot_plant.ankle_height[side]=journey.actor._skeleton.to_global(journey.actor._skeleton.get_bone_global_pose(journey.actor._skeleton.find_bone("foot_"+side)).origin).y
		for frame in 60:journey.tick(1.0/60)
		camera.global_position=journey.actor.global_position+Vector3(3,1.7,3);camera.look_at(journey.actor.global_position+Vector3.UP*.9)
		await _save("village_street_walker")
	var report:={"passed":errors.is_empty(),"errors":errors,"lanes":streets.lanes.size(),"terrain_samples":samples,"maximum_ground_offset_m":surface_error,"routes":report_paths,"scope":"lane ground fit, full corridor capsule clearance, market/home cycles and night return; normal world play, clothing and owner review remain"}
	FileAccess.open("res://docs/world/village_streets_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VILLAGE STREETS: ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
func _save(label:String)->void:
	for frame in 3:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png")
