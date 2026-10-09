extends Node3D
## Physical goods and a receiver own a cancellable, unpaid-until-finished handover.
const Crate=preload("res://assets/props/polyhaven/wooden_crate_02/wooden_crate_02_1k.gltf")
var manager:Node3D
var goods:Node3D
var vehicle:Node3D
var receiver:Node3D
var request := ""
var phase := ""
var age := 0.0
var start := Vector3.ZERO
var finish := Vector3.ZERO
var marker:MeshInstance3D

func configure(owner:Node3D)->void:
	manager=owner
	marker=MeshInstance3D.new();marker.name="DeliveryArrivalArea"
	var lines:=SurfaceTool.new();lines.begin(Mesh.PRIMITIVE_LINES)
	for edge in [[Vector3(-1.5,0,-3),Vector3(1.5,0,-3)],[Vector3(1.5,0,-3),Vector3(1.5,0,3)],[Vector3(1.5,0,3),Vector3(-1.5,0,3)],[Vector3(-1.5,0,3),Vector3(-1.5,0,-3)]]:
		for point in edge:lines.add_vertex(point)
	marker.mesh=lines.commit()
	var gold:=StandardMaterial3D.new();gold.albedo_color=Color(.94,.72,.28);gold.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override=gold;add_child(marker);marker.hide()

func parking_position(endpoint:String)->Vector3:
	var target:Node3D=manager.targets.get(endpoint)
	if target==null:return Vector3.INF
	var at:Vector3=target.global_position
	# Office handover is outside its raised veranda; warehouse has a quay bay.
	if endpoint=="office":at=Vector3(-368,0,320)
	elif endpoint=="port_cargo":at=Vector3(-195,0,681)
	at.y=manager.get_parent().layout.height(at.x,at.z)+.06
	if endpoint=="port_cargo":at.y=manager.floor_levels.get(endpoint,at.y)+.04
	return at

func pickup(id:String)->bool:
	if id!="port_delivery":return true
	var mounted:Node=manager.player.get_meta("mounted_vehicle",null)
	vehicle=mounted.cart if mounted!=null else null
	if vehicle==null:
		for cart:Node3D in get_tree().get_nodes_in_group("live_travel_carts"):
			if cart.get("variant")!=1 or absf(cart.boarding.speed)>.15:continue
			if cart.global_position.distance_to(parking_position("port_cargo"))<5:vehicle=cart;break
	if vehicle==null or vehicle.get("variant")!=1 or absf(vehicle.boarding.speed)>.15 or vehicle.global_position.distance_to(parking_position("port_cargo"))>5:
		vehicle=null;manager._message("Park a goods cart in the warehouse bay to load the consignment.");return false
	goods=Crate.instantiate();goods.name="EntrustedConsignment";goods.scale=Vector3.ONE*.38
	vehicle.visual_root.add_child(goods);goods.position=Vector3(-.55,1.55,2.65)
	vehicle.set_meta("errand_cargo",id)
	return true

func begin(id:String)->bool:
	if not phase.is_empty():return true
	var endpoint:String=manager.JOBS[id].goal
	receiver=manager.targets[endpoint].person
	if receiver==null or receiver.get_meta("dead",false):return false
	if id=="port_delivery":
		if not is_instance_valid(vehicle) or goods==null:
			manager._message("Collect the sealed consignment with a goods cart first.");return false
		if vehicle.global_position.distance_to(parking_position(endpoint))>4 or absf(vehicle.boarding.speed)>.15:
			manager._message("Park in the marked counting-house bay and stop for unloading.");return false
		vehicle.set_meta("errand_transfer",true);vehicle.boarding.speed=0
	request=id;start=receiver.global_position;finish=start
	phase="receiving";age=0
	if goods==null:
		goods=Crate.instantiate();goods.name="EntrustedParcel";goods.scale=Vector3.ONE*.16;add_child(goods)
		goods.global_position=manager.player.global_position+Vector3.UP*.95
	manager._message("The receiver is checking your delivery. Please wait.")
	receiver.set_process(false)
	return true

func _physics_process(delta:float)->void:
	if manager==null:return
	var endpoint:String=manager.next_endpoint()
	marker.visible=not manager.active.is_empty() and manager.JOBS[manager.active].kind in ["delivery","escort"] and manager.targets.has(endpoint)
	if marker.visible:marker.global_position=parking_position(endpoint)
	if phase.is_empty() and manager.active=="port_delivery" and not get_tree().paused:
		var mounted:Node=manager.player.get_meta("mounted_vehicle",null)
		if mounted!=null and mounted.role=="driver" and absf(mounted.speed)<.15 and mounted.transition.is_empty():
			if manager.stages[manager.active]=="accepted" and mounted.cart.global_position.distance_to(parking_position("port_cargo"))<4:
				if pickup(manager.active):manager.stages[manager.active]="carrying";manager._message("Consignment loaded. Return to the marked counting-house bay.")
			elif manager.stages[manager.active]=="carrying" and mounted.cart==vehicle and vehicle.global_position.distance_to(parking_position("office"))<4:begin(manager.active)
	if phase.is_empty() or get_tree().paused:return
	if manager.active!=request or not is_instance_valid(receiver) or receiver.get_meta("dead",false):abort();return
	age+=delta
	if phase=="receiving":
		var target:Vector3=receiver.to_global(Vector3(0,.95,.32))
		if goods.get_parent()!=self:goods.reparent(self,true)
		# The receiver approaches the goods before carrying them back, with swept collision.
		var stand:Vector3=vehicle.to_global(Vector3(-1.35,0,2.65)) if is_instance_valid(vehicle) else goods.global_position
		var offset:Vector3=stand-receiver.global_position;offset.y=0
		if offset.length()>(.08 if is_instance_valid(vehicle) else .65):
			if not _step(offset.normalized()*minf(delta*.85,maxf(.02,offset.length()-(.08 if is_instance_valid(vehicle) else .65))),delta):
				if age>12:manager._message("The unloading path is blocked. Move the cart and try again.");abort()
			return
		var facing:=goods.global_position-receiver.global_position;receiver.global_rotation.y=atan2(facing.x,facing.z)
		target=receiver.to_global(Vector3(0,.95,.32))
		goods.global_position=goods.global_position.lerp(target,minf(1,delta*3))
		_hold(delta)
		if age>2.4 and goods.global_position.distance_to(target)<.06:phase="returning";age=0
	elif phase=="returning":
		var offset:=finish-receiver.global_position;offset.y=0
		if offset.length()>.06:
			if not _step(offset.normalized()*minf(offset.length(),delta*.85),delta) and age>15:abort();return
			goods.global_position=receiver.to_global(Vector3(0,.95,.32));_hold(delta)
		else:phase="thanks";age=0
	elif phase=="thanks":
		receiver._set_animation(&"idle",delta)
		var rig:Skeleton3D=receiver._skeleton;var head:=rig.find_bone("head")
		rig.set_bone_pose_rotation(head,receiver._base_rotations.head*Quaternion(receiver._pitch_axes.head,.12*sin(age*PI)))
		if age>=1.2:
			var id:=request
			clear();manager._finish(id,true)
			manager._message("Thank you. Delivery received — %d rupees paid."%int(manager.JOBS[id].pay))

func _step(motion:Vector3,delta:float)->bool:
	var body:CollisionObject3D=receiver.body_collider
	var shape:CollisionShape3D=body.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.motion=motion;query.collision_mask=1
	query.exclude=[body.get_rid(),manager.targets[manager.JOBS[request].goal].get_rid()]
	var safe:=get_world_3d().direct_space_state.cast_motion(query)
	if safe[0]<.99:return false
	receiver.global_position+=motion
	var ground:=PhysicsRayQueryParameters3D.create(receiver.global_position+Vector3.UP*1.5,receiver.global_position-Vector3.UP*1.0,1,query.exclude)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ground)
	if not hit.is_empty() and absf(hit.position.y-receiver.global_position.y)<.4:receiver.global_position.y=hit.position.y
	receiver.global_rotation.y=atan2(motion.x,motion.z);receiver.travel_speed=.85
	for side in ["l","r"]:receiver.foot_plant.ankle_height[side]=receiver.global_position.y+.08
	receiver._set_animation(&"walk",delta);body.force_update_transform();return true

func _hold(delta:float)->void:
	receiver._set_animation(&"idle" if phase=="receiving" else &"walk",delta)
	for side in ["l","r"]:
		receiver.solve_hand_contact(side,goods.global_position+receiver.global_basis.x*(.18 if side=="l" else -.18))
		receiver.set_grip(side,.5)

func abort()->void:
	if is_instance_valid(receiver):receiver.global_position=start;receiver.set_process(true);receiver.set_grip("l",0);receiver.set_grip("r",0)
	if is_instance_valid(vehicle):
		vehicle.remove_meta("errand_transfer")
		if is_instance_valid(goods):goods.reparent(vehicle.visual_root,true);goods.position=Vector3(-.55,1.55,2.65)
	elif is_instance_valid(goods):goods.queue_free();goods=null
	phase="";request="";receiver=null

func clear()->void:
	abort()
	if is_instance_valid(vehicle):vehicle.remove_meta("errand_cargo")
	if is_instance_valid(goods):goods.queue_free()
	goods=null;vehicle=null

func export_state()->Dictionary:
	return {"cart":str(manager.get_parent().get_path_to(vehicle)) if is_instance_valid(vehicle) else ""}

func restore_state(state:Dictionary)->void:
	clear()
	if manager.active!="port_delivery" or manager.stages.get(manager.active,"")!="carrying":return
	var path:String=str(state.get("cart",""))
	if path.is_empty() or path.begins_with("/") or ".." in path:manager.stages[manager.active]="accepted";return
	vehicle=manager.get_parent().get_node_or_null(NodePath(path))
	if vehicle==null or not vehicle.is_in_group("live_travel_carts") or vehicle.get("variant")!=1:
		vehicle=null;manager.stages[manager.active]="accepted";return
	goods=Crate.instantiate();goods.name="EntrustedConsignment";goods.scale=Vector3.ONE*.38;vehicle.visual_root.add_child(goods);goods.position=Vector3(-.55,1.55,2.65)
	vehicle.set_meta("errand_cargo","port_delivery")
