extends Node3D
## Staff supplement existing services; each post retains its institution and role.
const Human=preload("res://characters/human_scene.gd")
const Actor=preload("res://characters/npcs/households/household_npc_actor.gd")
const StreetActor=preload("res://characters/npcs/indian/indian_street_actor.gd")
var posts:Array[Dictionary]=[]
var viewer:Node3D
var clock:Node
var elapsed := 0.0
const Budget=preload("res://systems/simulation_budget.gd")
const Startup=preload("res://systems/world_startup.gd")
var startup_task:=-1
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()

func _ready()->void:
	startup_task=Startup.begin("Institution residents")
	name="CivicResidentPosts";add_to_group("civic_resident_posts");prepare.call_deferred()

func prepare()->void:
	await Startup.wait_for(self,"Settlement")
	await get_tree().process_frame
	viewer=get_parent().get_node_or_null("Player");clock=get_parent().get_node_or_null("GameTimeSystem")
	for spec in [
		["MilitaryHospital","HospitalGateGuard","guard",Vector3(-3,0,9),"res://characters/npcs/british/private_man.glb"],
		["MilitaryHospital","HospitalLinenPorter","hospital_attendant",Vector3(3,0,9),"res://characters/npcs/street_residents/workman_02.glb"],
		["MilitarySupplyDepot","DepotStoresPorter","depot_laborer",Vector3(3,0,9),"res://characters/npcs/street_residents/workman_04.glb"],
		["Collectorate","CollectorateGuard","guard",Vector3(3,0,11),"res://characters/npcs/thana/burkundaz_motion.glb"],
		["DistrictTreasury","TreasuryGuard","guard",Vector3(-3,0,13),"res://characters/npcs/thana/daroga_motion.glb"],
		["MilitarySupplyDepot","DepotGateGuard","guard",Vector3(-3,0,9),"res://characters/npcs/british/corporal_man.glb"]
	]:
		var institution:=get_tree().root.find_child(spec[0],true,false) as Node3D
		if institution==null:continue
		var point:Vector3=institution.to_global(spec[3]);point.y=layout.height(point.x,point.z)
		var independent:bool=spec[2] in ["hospital_attendant","depot_laborer"]
		var actor:Node3D=StreetActor.new() if independent else Actor.new()
		actor.name=spec[1];actor.movement_enabled=false;actor.add_child(Human.instantiate(spec[4],false));add_child(actor);actor.global_position=point
		actor.set_meta("social_role",spec[2]);actor.set_meta("assigned_workplace",str(institution.get_path()));actor.set_meta("human_source",spec[4]);actor.set_meta("daily_activity",spec[2])
		actor.add_to_group("institution_post_residents")
		posts.append({"actor":actor,"home":point,"role":spec[2],"phase":float(posts.size())*.71})
		if independent:
			var work:=preload("res://world/suryagarh/settlements/resident_goods_run.gd").new()
			work.work_kind="hospital" if spec[2]=="hospital_attendant" else "depot"
			work.supplier_leg=53.0 if work.work_kind=="hospital" else 30.0
			work.name="LinenDelivery" if work.work_kind=="hospital" else "StoresDelivery"
			work.actor=actor;work.institution=institution;work.viewer=viewer;work.clock=clock;actor.add_child(work)
			while work.waypoints.size()<5:await get_tree().process_frame
		for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=150
		await get_tree().process_frame
	await Startup.wait_for(self,"Port")
	await Startup.wait_for(self,"Western city")
	await Startup.wait_for(self,"Households")
	for job in [
		["CustomsWarehouse","CustomsReceivingPorter","port",Vector3(10,0,5),PI/2,"res://characters/npcs/street_residents/workman_01.glb"],
		["CityTradingMarket","MarketStockWorker","market",Vector3(-24,0,-12),0.0,"res://characters/npcs/street_residents/workman_03.glb"],
		["MerchantHousehold","HouseholdSupplyServant","household",Vector3(23,0,-24),0.0,"res://characters/npcs/street_residents/female_02.glb"]
	]:
		var workplace:=get_tree().root.find_child(job[0],true,false) as Node3D
		if workplace==null:continue
		var station:=Node3D.new();station.name="ResidentReceivingStation";workplace.add_child(station);station.position=job[3];station.rotation.y=job[4]
		var worker:=StreetActor.new();worker.name=job[1];worker.movement_enabled=false
		worker.add_child(Human.instantiate(job[5],false));add_child(worker)
		worker.global_position=station.to_global(Vector3(3,0,15.4));worker.global_position.y=layout.height(worker.global_position.x,worker.global_position.z)
		worker.set_meta("social_role",str(job[2])+"_laborer");worker.set_meta("assigned_workplace",str(workplace.get_path()));worker.set_meta("human_source",job[5]);worker.add_to_group("institution_post_residents")
		var work:=preload("res://world/suryagarh/settlements/resident_goods_run.gd").new()
		work.name="SupplyDelivery";work.work_kind=job[2];work.actor=worker;work.institution=station;work.viewer=viewer;work.clock=clock
		work.supplier_leg={"port":24.0,"market":-24.0,"household":-24.0}[str(job[2])]
		if job[2]=="port":
			work.route_points=[Vector3(4.5,0,15.28),Vector3(3,0,15.4),Vector3(4.5,0,7),Vector3(4.5,0,4),Vector3(0,0,1)]
		elif job[2]=="market":
			work.store_base=Vector3(2.9,1.15,1);work.stand_base=Vector3(2.47,0,1)
			work.route_points=[Vector3(4.5,0,15.28),Vector3(7,0,15.4),Vector3(7,0,7),Vector3(7,0,-1),Vector3(2.47,0,-1),Vector3(0,0,1)]
		elif job[2]=="household":
			work.source_side=1.0
			# Covered rear service bay: goods and the supplier cart stay off the family drive.
			work.route_points=[Vector3(4.5,0,15.28),Vector3(3,0,15.4),Vector3(-.85,0,7),Vector3(.1,.24,4),Vector3(.1,.24,1)]
			work.store_base=Vector3(.53,1.15,1);work.stand_base=Vector3(.1,.24,1)
		worker.add_child(work)
		while work.waypoints.size()<5:await get_tree().process_frame
		await get_tree().process_frame
	Startup.finish(startup_task)

func _exit_tree()->void:
	Startup.finish(startup_task)

func _process(delta:float)->void:
	elapsed+=delta
	for post in posts:
		var actor:Node3D=post.actor
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):continue
		if post.role in ["hospital_attendant","depot_laborer"]:continue # Its persistent work controller owns motion/contact.
		var accumulated:float=float(post.get("age",0.0))+delta
		if accumulated<Budget.interval(actor,viewer):post.age=accumulated;continue
		post.age=0.0
		# Guard watches the approach; the orderly carries linen, never performs field work.
		if post.role=="guard":
			actor.global_rotation.y=.16*sin((elapsed+post.phase)/4)
