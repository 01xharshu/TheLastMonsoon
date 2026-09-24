extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var failures: Array[String] = []
var layout := Layout.new()

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func named_count(parent: Node, name: String) -> int:
	var count := 0
	for child in parent.find_children("*","Node3D",true,false):
		if child.get_meta("part_label","") == name: count += 1
	return count

func capture(camera: Camera3D,path: String) -> void:
	camera.make_current()
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var estate: Node3D = world.get_node("Settlement/GovernmentHouse")
	var main: Node3D = estate.get_node("MainHouse")
	var plot: Dictionary = Layout.PLOTS["GovernmentHouse"]
	check(estate.global_position.distance_to(Vector3(plot.center.x,plot.grade,plot.center.y))<0.01,"Residence departed from surveyed plot")
	check(named_count(estate,"PerimeterWall")==2 and named_count(estate,"NorthWallLeft")==1,"Estate wall is incomplete")
	check(named_count(main,"GlazedWindow")>=50,"Three-storey fenestration is incomplete")
	check(named_count(main,"WalkableStairSlope")==2,"Both stair flights are missing")
	check(named_count(main,"UpperFloorMain")==2,"Upper floors are missing")
	check(estate.has_node("EastWing") and estate.has_node("WestWing"),"Residential wings are missing")
	check(named_count(estate,"ParterrePlanting")==8,"Formal garden beds are missing")
	check(layout.road_distance(-214,-18)<.1 and layout.road_distance(-390,-18)<.1,"Gate road is disconnected")
	check(Layout.SITES.has("Government House") and Layout.SITES["Government House"]==plot.center,"Government House is absent from the field map")
	var space := world.get_world_3d().direct_space_state
	var samples := {"gate":Vector3(-390,12,-21),"avenue":Vector3(-390,12,-70),"portico":Vector3(-390,12,-121),"hall":Vector3(-390,12,-145),"upper_one":Vector3(-390,17,-145),"upper_two":Vector3(-390,22,-145)}
	var support: Dictionary = {}
	for label in samples:
		var origin: Vector3 = samples[label]
		var ray := PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*30)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty(),label+" has no supporting surface")
		if not hit.is_empty(): support[label]=hit.position.y
	check(float(support.get("hall",-1))>8.0,"Hall floor is below surveyed terrain")
	check(float(support.get("upper_one",-1))>12.0,"First floor has no solid surface")
	check(float(support.get("upper_two",-1))>16.0,"Second floor has no solid surface")
	var capsule := CapsuleShape3D.new()
	capsule.radius=.4
	capsule.height=1.8
	var clear_samples := 0
	for z in range(-21,-151,-2):
		var origin := Vector3(-390,11.2,float(z))
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*6))
		if ground.is_empty(): continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=capsule
		query.transform=Transform3D(Basis(),Vector3(-390,ground.position.y+1.08,float(z)))
		query.exclude=[world.get_node("Player").get_rid()]
		if not space.intersect_shape(query,4).is_empty():
			check(false,"Gate-to-hall capsule blocked at z="+str(z))
			break
		clear_samples += 1
	check(clear_samples>=60,"Gate-to-hall path has too few clear samples")
	var stair_clear := 0
	for flight in 2:
		var x := -370.0 if flight==0 else -362.0
		for step in range(1,24):
			var t: float = float(step)/24.0
			var z: float = -133.0-24.0*t if flight==0 else -157.0+24.0*t
			var deck_y: float = float(plot.grade)+flight*4.6+4.6*t+.15
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape=capsule
			query.transform=Transform3D(Basis(),Vector3(x,deck_y+1.08,z))
			query.exclude=[world.get_node("Player").get_rid()]
			if not space.intersect_shape(query,4).is_empty():
				check(false,"Stair flight %d blocked at step %d" % [flight+1,step])
				break
			stair_clear+=1
	check(stair_clear>=44,"Stair flights have too few clear capsule samples")
	var door_clear := 0
	for point in [Vector2(-407.5,-134.5),Vector2(-372.5,-134.5),Vector2(-407.5,-155.5),Vector2(-372.5,-155.5),Vector2(-424,-145),Vector2(-428,-145),Vector2(-356,-145),Vector2(-352,-145)]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=capsule
		query.transform=Transform3D(Basis(),Vector3(point.x,float(plot.grade)+1.4,point.y))
		query.exclude=[world.get_node("Player").get_rid()]
		check(space.intersect_shape(query,4).is_empty(),"Room or wing doorway blocked at "+str(point))
		if space.intersect_shape(query,4).is_empty(): door_clear+=1
	check(door_clear==8,"Some rooms cannot be entered")
	if DisplayServer.get_name() != "headless":
		world.get_node("Player/UI").hide()
		world.get_node("LandscapeUI").hide()
		var camera: Camera3D = world.get_node("SurveyCamera")
		camera.fov=76
		camera.global_position=estate.global_position+Vector3(50,32,138)
		camera.look_at(estate.global_position+Vector3(0,6,-25))
		await capture(camera,"res://docs/world/captures/24_government_house_exterior.png")
		camera.global_position=estate.global_position+Vector3(38,17,54)
		camera.look_at(estate.global_position+Vector3(0,7,-32))
		await capture(camera,"res://docs/world/captures/27_government_house_facade.png")
		camera.global_position=estate.global_position+Vector3(0,2.4,-19)
		camera.look_at(estate.global_position+Vector3(0,2.4,-52))
		await capture(camera,"res://docs/world/captures/25_government_house_hall.png")
		camera.global_position=estate.global_position+Vector3(0,STOREY_VIEW(),-22)
		camera.look_at(estate.global_position+Vector3(0,STOREY_VIEW(),-52))
		await capture(camera,"res://docs/world/captures/26_government_house_upper.png")
		var map: Control = world.get_node("Player/UI/WorldMap")
		world.get_node("Player/UI").show()
		map.set_open(true)
		map.zoom=2.0
		map.map_center=plot.center
		map.queue_redraw()
		await capture(camera,"res://docs/world/captures/28_government_house_map.png")
		map.set_open(false)
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","plot":plot.center,"window_count":named_count(main,"GlazedWindow"),"room_tables":named_count(main,"RoomTable"),"stair_flights":named_count(main,"WalkableStairSlope"),"static_bodies":estate.find_children("*","StaticBody3D",true,false).size(),"clear_gate_to_hall_samples":clear_samples,"clear_stair_samples":stair_clear,"clear_door_samples":door_clear,"support_heights":support,"failures":failures}
	var file := FileAccess.open("res://docs/world/government_house_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("GOVERNMENT HOUSE VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func STOREY_VIEW() -> float:
	return 4.6+2.2
