extends Node3D
## Three independent adult MPFB workers, each tied to a surveyed workplace.
const Actor = preload("res://characters/npcs/activity_actor.gd")
const Props = preload("res://world/suryagarh/settlements/activity_props.gd")
const REPAIR_MODEL := "res://characters/npcs/activity_people/cartmaker.glb"
const REPAIR_SOURCE := "res://WorkingAssets/NPCs/occupation_wardrobe/artisan/cartmaker_repair_workwear.blend"
const Budget = preload("res://systems/simulation_budget.gd")
var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
var workers: Array[Node3D] = []
var records: Array[Dictionary] = []
var viewer: Node3D
var clock: Node
var wait := 0.0
var spawn_index := 0
var saved := {}

func _ready() -> void:
	name="NamedOccupations";add_to_group("independent_npc_activities")
	var world := preload("res://systems/world_context.gd").find_world(self)
	if world!=null:viewer=world.get_node_or_null("Player");clock=world.get_node_or_null("GameTimeSystem")
	preload("res://world/suryagarh/settlements/activity_save.gd").apply_late(self)

func _process(delta: float) -> void:
	if spawn_index>=3:return
	wait-=delta
	if wait>0:return
	var world := preload("res://systems/world_context.gd").find_world(self)
	if world==null or not world.has_node("Settlement/BhairavpurHouse30"):return
	wait=.25
	spawn_worker(spawn_index,world.get_node("Settlement"));spawn_index+=1

func spawn_worker(index: int, settlement: Node, appearance: PackedScene = null) -> void:
	var actor := Actor.new();actor.name=["CartMaker","Milkman","Potter"][index]
	actor.movement_enabled=false;actor.patrol_distance=0
	actor.ground_height=func(x: float,z: float) -> float:return layout.height(x,z)
	var role: String="dairyman" if index==1 else "artisan"
	actor.set_meta("human_source","res://WorkingAssets/NPCs/activity_people/"+role+"/"+role+".blend")
	actor.set_meta("world_role",["cart_maker","milkman","potter"][index])
	var fitted_repair := index == 0 and appearance == null
	if fitted_repair:
		appearance = load(REPAIR_MODEL)
		actor.set_meta("human_source", REPAIR_SOURCE)
	elif appearance == null:
		appearance = load("res://characters/npcs/activity_people/"+role+".glb")
	actor.add_child(appearance.instantiate())
	var station := Node3D.new();station.name=["CartRepairYard","MilkCartBay","PotteryWorkplace"][index];add_child(station)
	var home: Node3D=settlement.get_node("BhairavpurHouse25" if index==0 else "BhairavpurHouse27" if index==1 else "BhairavpurHouse30")
	station.global_transform=home.global_transform
	station.set_meta("assigned_home",str(home.get_path()))
	station.set_meta("occupation",actor.get_meta("world_role"))
	station.add_child(actor);actor.set_process(false)
	preload("res://world/suryagarh/settlements/occupation_wardrobe.gd").apply(actor,actor.get_meta("world_role"))
	var record := {"actor":actor,"station":station,"job":index,"elapsed":float(index)*2.73,"pending":0.0,"blocked":0,"distance":0.0,"direction":1,"pause":0.0}
	if index==0:
		var cart := Props.cart(station,"CartUnderRepair");cart.position=Vector3(5.8,0,5.8)
		cart.global_position.y=layout.height(cart.global_position.x,cart.global_position.z)+.04
		record.cart=cart
		actor.position=cart.position+Vector3(1.30,0,.20);actor.rotation.y=-PI*.5
		var mallet:=Node3D.new();mallet.name="RepairMallet";actor.add_child(mallet)
		Props.cylinder(mallet,"WoodenHandle",Vector3.ZERO,.018,.30,Props.material(Color(.31,.21,.10)))
		Props.box(mallet,"MalletHead",Vector3(0,.14,0),Vector3(.16,.075,.08),Props.material(Color(.28,.17,.08)))
		record.tool=mallet
		actor.seat_height = .45 if fitted_repair else .27
		if fitted_repair:
			actor.global_position += cart.global_basis.x * .02
			actor.global_position.y = layout.height(actor.global_position.x, actor.global_position.z)
			actor.outfit_correctives = preload("res://characters/npcs/occupation_cloth_correctives.gd").new()
			actor.outfit_correctives.setup(actor)
		var seat := Props.box(station,"RepairSeat",actor.position+Vector3(0,actor.seat_height-.05,0),Vector3(.44,.10,.42),Props.material(Color(.27,.17,.08)),true) as MeshInstance3D
		support_repair_seat(seat)
	elif index==1:
		# Local dairy delivery strip beside the cattle household, outside the lane.
		station.global_transform=Transform3D(Basis.IDENTITY,Vector3(-329,layout.height(-329,306),306))
		var cart:=Props.cart(station,"MilkCart");record.cart=cart
		for row in 2:
			for column in 3:Props.balti(cart,Vector3(-.40+column*.40,.78,-.35+row*.65))
		var rope:=Props.material(Color(.44,.34,.20))
		for z in [-.35,.30]:Props.box(cart,"SecuringCrossbar",Vector3(0,.91,z),Vector3(1.25,.035,.035),rope)
		actor.position=Vector3(0,0,-2.30)
		record.travel=0.0
	else:
		var piece: Node3D=home.get_node_or_null("PotteryKit/WheelWorkpiece")
		if piece!=null:record.workpiece=piece
		actor.position=Vector3(2.25,.24,4.08)
		Props.box(station,"PotterSeat",Vector3(2.25,.44,4.08),Vector3(.56,.12,.48),Props.material(Color(.27,.17,.08)),true)
		actor.seat_height=.26
		station.set_meta("drying_pots",3)
	actor.set_meta("assigned_workplace",str(station.get_path()))
	record.home_position=actor.position
	workers.append(actor);records.append(record)
	apply_saved(record)

func support_repair_seat(seat: MeshInstance3D) -> void:
	var previous := seat.get_node_or_null("Legs")
	if previous != null:
		seat.remove_child(previous)
		previous.queue_free()
	var legs := Node3D.new()
	legs.name = "Legs"
	seat.add_child(legs)
	var underside := -.05
	for x in [-.165, .165]:
		for z in [-.155, .155]:
			var foot := seat.to_global(Vector3(x, underside, z))
			foot.y = layout.height(foot.x, foot.z) - .015
			var bottom := seat.to_local(foot).y
			var height := underside - bottom
			if height > .01:
				Props.box(legs, "Leg", Vector3(x, underside - height * .5, z),
					Vector3(.055, height, .055), seat.material_override, true)

func _physics_process(delta: float) -> void:
	for record in records:
		var actor: Node3D=record.actor
		if record.has("tool"):
			var interrupted: bool=actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("civilian_reacting",false)
			var tool: Node3D=record.tool
			if interrupted:
				# Leave the repair tool on the cart before the worker escapes.
				tool.top_level=true;tool.global_transform=record.cart.global_transform*Transform3D(Basis.IDENTITY,Vector3(.55,.82,0))
			else:tool.top_level=false
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("civilian_reacting",false):continue
		if clock!=null and clock.clock_paused:continue
		record.pending+=delta
		if record.pending<Budget.interval(actor,viewer):continue
		# Consume accumulated elapsed time with the same swept movement bounds.
		for slice in 5:
			if record.pending<=0:break
			var step:=minf(record.pending,.1);record.pending-=step
			tick_worker(record,step)

func tick_worker(record: Dictionary, delta: float) -> void:
	var actor: Node3D=record.actor
	record.elapsed+=delta
	if clock!=null and (clock.current_hour<6 or clock.current_hour>=18):
		actor.perform("listen",delta)
		actor.finish_contacts()
		return
	var time: float=record.elapsed
	if record.job==0:
		actor.perform("repair",delta)
		record.tool.visible=actor.activity_age>=.8
		if actor.activity_age<.8:actor.finish_contacts();return
		var cart: Node3D=record.cart
		var strike:=.5-.5*cos(time*TAU/1.4)
		var target:=cart.to_global(Vector3(1.0,.56+.18*strike,.20))
		actor.solve_hand_contact("r",target)
		actor.solve_hand_contact("l",cart.to_global(Vector3(.88,.57,.40)))
		actor.set_grip("r",.7);actor.set_grip("l",.3)
		var tool: Node3D=record.tool
		tool.global_position=actor.palm_world("r");tool.global_rotation=actor.global_rotation+Vector3(.5+.4*strike,0,.2)
	elif record.job==1:
		milk_step(record,delta)
	else:
		actor.perform("shape",delta)
		if actor.activity_age<.8:actor.finish_contacts();return
		var center:=actor.get_parent_node_3d().to_global(Vector3(2.25,.84,4.5))
		var phase:=fposmod(time,12.0)
		for side in ["l","r"]:
			var radius:=.065+.025*sin(time*.8)
			var target:=center+actor.global_basis*Vector3(radius if side=="l" else -radius,.035*sin(time*.7),0)
			if phase<1.6 and side=="r":target=actor.get_parent_node_3d().to_global(Vector3(1.92,.74,4.25+.03*sin(time*3)))
			actor.solve_hand_contact(side,target);actor.set_grip(side,.08)
		if record.has("workpiece"):
			var piece: Node3D=record.workpiece
			piece.rotation.y=fposmod(time*2.4,TAU)
			piece.scale=Vector3(.91+.06*sin(time*.7),.90+.13*sin(time*.35),.91+.06*sin(time*.7))*.75
	actor.finish_contacts()

func milk_step(record: Dictionary, delta: float) -> void:
	var actor: Node3D=record.actor;var cart: Node3D=record.cart
	var speed:=.65
	if record.pause>0:
		record.pause=maxf(0,record.pause-delta);actor.perform("push",delta);speed=0.0
	var motion:=Vector3(0,0,float(record.direction)*speed*delta)
	var candidate:=cart.global_position+motion
	candidate.y=layout.height(candidate.x,candidate.z)+.04
	motion=candidate-cart.global_position
	var shape: CollisionShape3D=cart.get_node("CartBody").get_child(0)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.motion=motion;query.margin=.015;query.collision_mask=1
	query.exclude=[cart.get_node("CartBody").get_rid(),actor.body_collider.get_rid()]
	# Check the entire cart sweep and the worker's endpoint; never remove collision.
	var safe:=get_world_3d().direct_space_state.cast_motion(query)[0]
	query.transform.origin+=motion;query.motion=Vector3.ZERO
	var hits:=get_world_3d().direct_space_state.intersect_shape(query,4)
	var occupied:=not hits.is_empty()
	if occupied:record.obstacle=str(hits[0].collider.get_path())
	var worker_shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
	var worker_target:=candidate+cart.global_basis*Vector3(0,0,-2.30)
	worker_target.y=layout.height(worker_target.x,worker_target.z)
	query.shape=worker_shape.shape;query.transform=worker_shape.global_transform;query.transform.origin.y+=.035
	query.motion=worker_target-actor.global_position
	var worker_clear:=get_world_3d().direct_space_state.cast_motion(query)[0]>=.99
	query.transform.origin+=query.motion;query.motion=Vector3.ZERO
	worker_clear=worker_clear and get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	if safe<.99 or occupied or not worker_clear:
		record.blocked+=1;motion=Vector3.ZERO;speed=0
	else:
		cart.global_position=candidate
		record.travel+=float(record.direction)*speed*delta
		record.distance+=absf(speed*delta)
		for wheel in ["WheelLeft","WheelRight"]:
			var node: Node3D=cart.get_node(wheel)
			node.rotation.x-=motion.dot(cart.global_basis.z)/node.position.y
		if (record.travel>=6.0 and record.direction>0) or (record.travel<=0 and record.direction<0):record.direction=-record.direction;record.pause=5.0
	actor.global_position=cart.to_global(Vector3(0,0,-2.30))
	actor.global_position.y=layout.height(actor.global_position.x,actor.global_position.z)
	actor.travel_speed=speed
	actor.walk_direction=float(record.direction)
	actor._set_animation(&"walk" if speed>0 else &"idle",delta)
	# Upper-body push pose leaves gait/foot contact in charge of the legs.
	actor.animation_tree.set("parameters/work_pose/blend_amount",0.0)
	for side in ["l","r"]:
		actor.solve_hand_contact(side,cart.to_global(Vector3(.46 if side=="l" else -.46,1.0,-2.0)))
		actor.set_grip(side,.55)
	actor.set_meta("activity","milk_delivery" if speed>0 else "milk_delivery_wait")

func export_state() -> Dictionary:
	var result: Dictionary=saved.duplicate(true)
	for record in records:
		result[str(record.actor.name)]={"elapsed":record.elapsed,"travel":record.get("travel",0.0),"direction":record.direction,"pause":record.pause,"distance":record.distance}
	return result

func restore_state(data: Dictionary) -> void:
	saved=data.duplicate(true)
	for record in records:apply_saved(record)

func apply_saved(record: Dictionary) -> void:
	var state: Dictionary=saved.get(str(record.actor.name),{})
	if state.is_empty():return
	record.elapsed=maxf(0,float(state.get("elapsed",0)));record.direction=1 if int(state.get("direction",1))>0 else -1
	record.pause=maxf(0,float(state.get("pause",0)));record.distance=maxf(0,float(state.get("distance",0)))
	if record.job==1:
		record.travel=clampf(float(state.get("travel",0)),0,6)
		record.cart.position.z=record.travel
		var cart: Node3D=record.cart;cart.global_position.y=layout.height(cart.global_position.x,cart.global_position.z)+.04
		tick_worker(record,0)
