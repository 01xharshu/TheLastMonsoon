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
	var report:={"passed":errors.is_empty(),"through_houses":through,"paired_passages":paired,"clear_staircases":stairs,"ward_save_treatment":operations.pending.is_empty(),"errors":errors,"scope":"physical paired-leaf openings and medical transfer; world terrain, street population and rendered review separate"}
	print("URBAN_WEST_CHECK ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
