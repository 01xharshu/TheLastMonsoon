extends SceneTree
## Actual paired leaves, capsule sweeps, ward stock and existing MPFB bodies; stdout only.
class MapFixture extends Node:
	func refresh_sites() -> void:pass
class Patient extends CharacterBody3D:
	const MAX_HEALTH:=100.0
	var health:=20.0
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world:=Node3D.new();world.name="World";root.add_child(world);current_scene=world
	var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.current_hour=10;clock.current_day=1
	var player:=Patient.new();player.name="Player";world.add_child(player)
	player.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/households/merchant.glb"))
	var inventory:Node=load("res://player/inventory_component.gd").new();inventory.name="InventoryComponent";player.add_child(inventory);inventory.items={"rupees":10}
	var ui:=Node.new();ui.name="UI";player.add_child(ui);var map:=MapFixture.new();map.name="WorldMap";ui.add_child(map)
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.8;collision.shape=capsule;player.add_child(collision)
	var expansion:Node=load("res://world/suryagarh/population_expansion.gd").new();world.add_child(expansion);expansion.set_process(false)
	var stale:=Node.new();expansion.discovery.append(stale);stale.free();expansion._process(0)
	if not expansion.discovery.is_empty():errors.append("freed discovery entry did not drain")
	expansion.free()
	var community:Node=load("res://world/suryagarh/settlements/story_community.gd").new();world.add_child(community)
	var city:Node=load("res://world/suryagarh/settlements/urban_west.gd").new();world.add_child(city)
	for frame in 240:await physics_frame
	if not city.classified:errors.append("student crowd classification failed: residents=%s pending=%s parents=%s"%[community.residents.size(),community.pending.size(),community.residents.map(func(actor):return str(actor.get_parent().name))])
	if city.homes.size()!=26:errors.append("missing dense homes")
	var through:=0
	for home in city.homes:
		player.global_position=home.global_position+Vector3(0,1.145,12)
		await physics_frame
		var hit:=player.move_and_collide(Vector3(0,0,-24))
		if hit!=null:errors.append(str(home.name)+" front-to-rear blocked: "+str(hit.get_collider().get_path()))
		else:through+=1
	var paired:=0
	for pair in city.connected_pairs:
		var home:Node3D=pair[0]
		player.global_position=home.global_position+Vector3(0,1.145,1)
		await physics_frame
		var hit:=player.move_and_collide(Vector3(-12,0,0))
		if hit!=null:errors.append(str(home.name)+" neighbour passage blocked: "+str(hit.get_collider().get_path()))
		else:paired+=1
	var stairs:=0
	for home in city.homes:
		if home.get_meta("storeys",1)!=2:continue
		player.global_position=home.global_position+Vector3(float(home.get_meta("stair_side"))*3.9,1.145,6.05)
		await physics_frame
		var blocked:=false
		for step in 16:
			if player.move_and_collide(Vector3.UP*.19)!=null or player.move_and_collide(Vector3(0,0,-.65))!=null:
				blocked=true;break
		if blocked:errors.append(str(home.name)+" staircase capsule clearance failed")
		else:stairs+=1
	var ward:Node3D=city.get_node("CivilianHospital")
	var service:Node=ward.get_node("HospitalService");var operations:Node=ward.get_node("Operations")
	player.global_position=ward.to_global(Vector3(1.5,.24,4));service.interact(player)
	if operations.pending.is_empty():errors.append("civilian treatment did not start")
	else:
		operations._process(7)
		if player.health!=70 or inventory.get_item_count("rupees")!=8:errors.append("civilian treatment transfer failed")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(operations.export_state()));operations.ledger.clear();operations.restore_state(saved)
	service.interact(player)
	if not operations.pending.is_empty() or inventory.get_item_count("rupees")!=8:errors.append("restored ward repeated daily treatment")
	var ward_save_treatment:bool=operations.pending.is_empty()
	var saver:Node=root.get_node("SaveManager")
	var front:Node=city.homes[0].get_node("FrontDoorFrame/FrontDoor")
	front.manual_locked=true;front.locked=true;front.swing_direction=-1;front.restore_state(false)
	var saved_doors:Dictionary=JSON.parse_string(JSON.stringify(saver._door_states(world)))
	var door_path:="UrbanWest/CityHome0/FrontDoorFrame/FrontDoor"
	if not saved_doors.has(door_path):errors.append("door save path is not stable")
	city.queue_free();await physics_frame;await physics_frame
	city=load("res://world/suryagarh/settlements/urban_west.gd").new();world.add_child(city)
	for frame in 30:await physics_frame
	saver._restore_door_states(world,saved_doors)
	front=city.homes[0].get_node("FrontDoorFrame/FrontDoor")
	if front.opened or not front.manual_locked or front.swing_direction!=-1:errors.append("door state did not survive rebuilding")
	front.manual_locked=false;front.locked=false;front.restore_state(true)
	saver._restore_door_states(world,{"UrbanWest/CityHome0/@Node3D@old/FrontDoor":saved_doors.get(door_path,{})})
	if front.opened or not front.manual_locked:errors.append("legacy automatic jamb path did not restore")
	# Old receiving-room saves retain the carried load when the service bay moves.
	var merchant_fixture:=Node3D.new();merchant_fixture.position=Vector3(-420,8,-405);world.add_child(merchant_fixture)
	var station:=Node3D.new();station.position=Vector3(23,0,-24);merchant_fixture.add_child(station)
	var delivery:Node=load("res://tools/world/house_delivery_restore_probe.gd").new();world.add_child(delivery);delivery.actor=player;delivery.institution=station;delivery.work_kind="household"
	delivery.cart=Node3D.new();station.add_child(delivery.cart)
	for index in 3:
		var item:=Node3D.new();delivery.cart.add_child(item)
		var body:=StaticBody3D.new();body.name="ConsignmentBody";item.add_child(body);delivery.goods.append(item)
	var legacy_point:=merchant_fixture.to_global(Vector3(3.1,.24,2))
	delivery.restore_state({"phase":"inside","delivered":0,"position":[legacy_point.x,legacy_point.y,legacy_point.z],"cart_position":[5,0,11]})
	var expected_point:=station.to_global(Vector3(.1,.24,1))
	if player.global_position.distance_to(expected_point)>.001 or delivery.goods[0].get_parent()!=player:errors.append("service-bay migration lost carried stock/position")
	var delivery_saved:Dictionary=JSON.parse_string(JSON.stringify(delivery.export_state()))
	delivery.restore_state(delivery_saved)
	if player.global_position.distance_to(expected_point)>.001:errors.append("service-bay restore shifted the worker twice")
	for item in delivery.goods:item.queue_free()
	delivery.free();merchant_fixture.queue_free()
	var report:={"passed":errors.is_empty(),"through_houses":through,"paired_passages":paired,"clear_staircases":stairs,"door_save_reload":not front.opened and front.manual_locked,"service_bay_migration":player.global_position.distance_to(expected_point)<.001,"ward_save_treatment":ward_save_treatment,"errors":errors,"scope":"physical paired-leaf openings and medical transfer; world terrain, street population and rendered review separate"}
	print("URBAN_WEST_CHECK ",JSON.stringify(report))
	var folder:=OS.get_environment("TLM_URBAN_ISOLATED_TEMP")
	if not folder.is_empty() and DisplayServer.get_name()!="headless":
		player.global_position=Vector3(-310,8.24,-370)
		var ground:=StaticBody3D.new();world.add_child(ground)
		var ground_visual:=MeshInstance3D.new();var ground_mesh:=BoxMesh.new();ground_mesh.size=Vector3(350,.2,300);ground_visual.mesh=ground_mesh
		var ground_material:=StandardMaterial3D.new();ground_material.albedo_color=Color(.45,.39,.30);ground_visual.material_override=ground_material;ground.add_child(ground_visual);ground.position=Vector3(-330,7.9,-415)
		var sunlight:=DirectionalLight3D.new();sunlight.rotation_degrees=Vector3(-50,-30,0);world.add_child(sunlight)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.58,.66,.69);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;world.add_child(environment)
		saver.apply_options()
		var camera:=Camera3D.new();camera.far=1500;world.add_child(camera);camera.make_current()
		for pose in [["house_blocks",Vector3(-245,65,-295),Vector3(-345,10,-392)],["double_doors",Vector3(-277,10.0,-337),Vector3(-280,9.8,-350)],["stairs_and_rails",Vector3(-280,11.8,-344.8),Vector3(-276.1,11,-351)]]:
			camera.global_position=pose[1];camera.look_at(pose[2])
			for frame in 8:await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(folder.path_join(pose[0]+".png"))
	quit(0 if errors.is_empty() else 1)
