extends SceneTree
var errors:Array[String]=[]
func check(value:bool,label:String)->void:
	if not value:errors.append(label);push_error(label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	create_timer(90).timeout.connect(func():quit(2))
	var scene:=Node3D.new();root.add_child(scene);current_scene=scene
	var owner:=Node3D.new();owner.name="BhairavpurHouse27";scene.add_child(owner);owner.add_to_group("bhairavpur_home")
	var floor:=StaticBody3D.new();floor.position=Vector3(-321,7.15,289);scene.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.1,30);shape.shape=box;floor.add_child(shape)
	var yard:=preload("res://world/suryagarh/settlements/household_cattle.gd").new();scene.add_child(yard)
	for frame in 3:await physics_frame
	yard.motion.enabled=false;yard.caretaker.enabled=false
	check(yard.motion.rig.get_bone_count()==19,"neck/jaw/four hooves articulated")
	check(yard.motion.breath_index>=0,"authored breathing morph imported")
	var breath_min:=1.0;var breath_max:=0.0
	var seen:Dictionary={};var contacts:Dictionary={};var traveled:=0.0
	for frame in 6000:
		var prior:Vector3=yard.cow.global_position
		yard.motion.tick(1.0/30);yard.caretaker.tick(1.0/30)
		var breath_value:float=yard.motion.breathing_mesh.get_blend_shape_value(yard.motion.breath_index)
		breath_min=minf(breath_min,breath_value);breath_max=maxf(breath_max,breath_value)
		traveled+=prior.distance_to(yard.cow.global_position);seen[yard.motion.state]=true
		if yard.motion.state in ["graze","feed","drink"] and yard.motion.head_weight>.999:
			if not contacts.has(yard.motion.state):contacts[yard.motion.state]={"error":0.0,"frames":0}
			contacts[yard.motion.state].error=maxf(contacts[yard.motion.state].error,yard.motion.contact_error);contacts[yard.motion.state].frames+=1
	check(breath_min<.05 and breath_max>.95,"breathing actually cycles during behavior")
	check(traveled>6,"cow actually walks between surfaces")
	for state in ["graze","feed","drink"]:check(contacts.has(state) and contacts[state].frames>15,"reaches "+state+" surface")
	check(yard.motion.maximum_stance_error<.035,"continuous hoof stance within 35mm")
	for state in contacts:check(contacts[state].error<.025,"muzzle to "+state+" within 25mm")
	check(yard.caretaker.transfers>0,"caretaker carries and transfers real fodder")
	check(yard.caretaker.contact_max<.025,"caretaker settled palm contact within 25mm")
	var report:={"passed":errors.is_empty(),"errors":errors,"states":seen.keys(),"distance_m":traveled,"muzzle_contacts":contacts,"hoof_stance_max_m":yard.motion.maximum_stance_error,"caretaker_transfers":yard.caretaker.transfers,"caretaker_palm_max_m":yard.caretaker.contact_max,"final_cow_position":yard.cow.position,"final_stage":yard.motion.stage,"caretaker_stage":yard.caretaker.stage,"scope":"fixed-step complete behavior/contact assertions; rendered motion and final art separate"}
	print("COW MOTION: ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
