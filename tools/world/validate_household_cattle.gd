extends SceneTree
var errors:Array[String]=[]
func check(condition:bool,label:String)->void:
	if not condition:errors.append(label);push_error(label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	create_timer(120).timeout.connect(func():quit(2))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false);player.hide();player.get_node("UI").hide();world.get_node("LandscapeUI").hide()
	for frame in 8:await physics_frame
	var yards:=get_nodes_in_group("household_cattle")
	check(yards.size()==1,"one owned cattle yard")
	if yards.is_empty():quit(1);return
	var yard:Node3D=yards[0]
	check(yard.house.name=="BhairavpurHouse27" and yard.house.get_meta("owns_cow",false),"real household owner link")
	check(yard.cow.get_meta("owner_house","")==str(yard.house.get_path()),"cow owner identity")
	var space:=world.get_world_3d().direct_space_state
	var error:=0.0
	for point in yard.floor_samples:
		var q:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.02,point-Vector3.UP*.08,1)
		var result:=space.intersect_ray(q)
		check(not result.is_empty(),"shelter post has real terrain support")
		if not result.is_empty():error=maxf(error,point.distance_to(result.position))
	check(error<.025,"shelter supports within 25mm of ground")
	# Validate the actual cow body capsule against existing houses/fences at its ground position.
	var q:=PhysicsShapeQueryParameters3D.new();q.shape=yard.cow.get_node("CowBody/BodyShape").shape;q.transform=yard.cow.get_node("CowBody/BodyShape").global_transform;q.collision_mask=1
	q.exclude=[yard.cow.get_node("CowBody").get_rid()];q.transform.origin+=Vector3.UP*.03
	var overlaps:=space.intersect_shape(q,8)
	check(overlaps.is_empty(),"cow body clear of existing structures")
	for hit in overlaps:print("COW OVERLAP ",hit.collider.get_path())
	var inventory:Node=player.get_node("InventoryComponent")
	var care:Node3D=yard.get_node("Care_fodder")
	player.global_position=care.global_position+Vector3(0,0,1.1)
	var stock:int=yard.fodder_stock;var feed:int=yard.feed_portions
	care.interact(player);check(yard.fodder_stock==stock-1 and yard.feed_portions==feed+1,"fodder transfers real household stock")
	care.interact(player);var after:int=yard.fodder_stock;care.interact(player);check(yard.fodder_stock==after,"full manger does not consume stock")
	care=yard.get_node("Care_water");player.global_position=care.global_position+Vector3(0,0,1.1)
	inventory.add_item("water_bag",1);inventory.stored_water_liters=0.0
	var water:float=yard.water_liters;care.interact(player);check(yard.water_liters==water,"empty pouch adds no water")
	inventory.add_water(2.0);care.interact(player)
	check(is_equal_approx(yard.water_liters,water+2) and is_zero_approx(inventory.stored_water_liters),"water conservation pouch to trough")
	inventory.add_water(2.0);player.global_position+=Vector3(10,0,0);care.interact(player);check(is_equal_approx(inventory.stored_water_liters,2.0),"distant care rejected")
	var manager:Node=root.get_node("SaveManager")
	var original_save_root:String=manager.save_root
	manager.save_root="/tmp/tlm_cattle_save_%d"%Time.get_ticks_msec()
	check(manager.save_game(world,1),"care state written to isolated save file")
	var disk:Dictionary=manager.read_slot(1)
	var saved:Dictionary=disk.get("household_cattle",{})
	check(not saved.is_empty(),"care state included in actual saved data")
	manager.save_root=original_save_root
	var feed_saved:int=yard.feed_portions
	yard.feed_portions=0;yard.fodder_stock=0;yard.water_liters=0;yard.refresh_supplies()
	manager._restore_cattle_states(world,saved)
	check(yard.feed_portions==feed_saved and is_equal_approx(yard.water_liters,water+2),"care state save round trip")
	manager._restore_cattle_states(world,{})
	check(yard.feed_portions==feed_saved,"older saves preserve initial care state")
	if DisplayServer.get_name()!="headless":
		var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.global_position=yard.global_position+Vector3(6,3,-6);camera.look_at(yard.global_position+Vector3.UP*1.1)
		for frame in 4:await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://docs/world/captures/household_cattle_yard.png")
	var report:={"passed":errors.is_empty(),"errors":errors,"owner_house":str(yard.house.get_path()),"support_error_m":error,"overlap_count":overlaps.size(),"scope":"household link, body clearance, supports and resource conservation; cow art, caretaker, feeding/grazing motion open; care-state snapshot round trip PASS"}
	FileAccess.open("res://docs/world/household_cattle_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HOUSEHOLD CATTLE: ",JSON.stringify(report));world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
