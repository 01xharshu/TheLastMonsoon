extends Node3D
## Staff supplement existing services; each post retains its institution and role.
const Human=preload("res://characters/human_scene.gd")
const Actor=preload("res://characters/npcs/households/household_npc_actor.gd")
const StreetActor=preload("res://characters/npcs/indian/indian_street_actor.gd")
var posts:Array[Dictionary]=[]
var viewer:Node3D
var clock:Node
var elapsed := 0.0
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()

func _ready()->void:
	name="CivicResidentPosts";add_to_group("civic_resident_posts");prepare.call_deferred()

func prepare()->void:
	await get_tree().process_frame
	viewer=get_parent().get_node_or_null("Player");clock=get_parent().get_node_or_null("GameTimeSystem")
	for spec in [
		["MilitaryHospital","HospitalGateGuard","guard",Vector3(-3,0,9),"res://characters/npcs/british/private_man.glb"],
		["MilitaryHospital","HospitalLinenPorter","hospital_attendant",Vector3(3,0,9),"res://characters/npcs/street_residents/workman_02.glb"],
		["Collectorate","CollectorateGuard","guard",Vector3(3,0,11),"res://characters/npcs/thana/burkundaz_motion.glb"],
		["DistrictTreasury","TreasuryGuard","guard",Vector3(-3,0,13),"res://characters/npcs/thana/daroga_motion.glb"],
		["MilitarySupplyDepot","DepotGateGuard","guard",Vector3(-3,0,9),"res://characters/npcs/british/corporal_man.glb"]
	]:
		var institution:=get_tree().root.find_child(spec[0],true,false) as Node3D
		if institution==null:continue
		var point:Vector3=institution.to_global(spec[3]);point.y=layout.height(point.x,point.z)
		var actor:Node3D=StreetActor.new() if spec[2]=="hospital_attendant" else Actor.new()
		actor.name=spec[1];actor.movement_enabled=false;actor.add_child(Human.instantiate(spec[4],false));add_child(actor);actor.global_position=point
		actor.set_meta("social_role",spec[2]);actor.set_meta("assigned_workplace",str(institution.get_path()));actor.set_meta("human_source",spec[4]);actor.set_meta("daily_activity",spec[2])
		actor.add_to_group("institution_post_residents")
		posts.append({"actor":actor,"home":point,"role":spec[2],"phase":float(posts.size())*.71})
		if spec[2]=="hospital_attendant":
			var basket:Node3D=load("res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf").instantiate();basket.name="HospitalLinenBasket";basket.scale=Vector3.ONE*.22;basket.position=Vector3(0,.92,.30);actor.add_child(basket)
		for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=150
		await get_tree().process_frame

func _process(delta:float)->void:
	elapsed+=delta
	for post in posts:
		var actor:Node3D=post.actor
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):continue
		var near:bool=viewer==null or viewer.global_position.distance_squared_to(actor.global_position)<4900
		actor.animation_tree.active=near;actor.set_process(near)
		if not near:continue
		# Guard watches the approach; the orderly carries linen, never performs field work.
		if post.role=="guard":
			actor.global_rotation.y=.16*sin((elapsed+post.phase)/4)
		else:
			actor.set_process(false);actor._set_animation(&"idle",delta)
			for side in ["l","r"]:actor.solve_hand_contact(side,actor.to_global(Vector3(.18 if side=="l" else -.18,.95,.30)))
