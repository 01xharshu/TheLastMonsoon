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
var route:Array[Vector3]=[]
var trail:Array[Vector3]=[]
var pending_cart_path:=""
var pending_cart_age:=0.0
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
	var mounted:Node=manager.player.get_meta("mounted_vehicle") if manager.player.has_meta("mounted_vehicle") else null
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
	if not phase.is_empty():return phase!="recovering" and request==id
	if manager.active!=id or manager.stages.get(id,"")!="carrying":return false
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
	trail=[start];route.clear()
	if is_instance_valid(vehicle):route=_route_to(vehicle.to_global(Vector3(-1.8,0,2.65)))
	if goods==null:
		goods=Crate.instantiate();goods.name="EntrustedParcel";goods.scale=Vector3.ONE*.16;add_child(goods)
		goods.global_position=manager.player.global_position+Vector3.UP*.95
	manager._message("The receiver is checking your delivery. Please wait.")
	receiver.set_process(false)
	return true

func _physics_process(delta:float)->void:
	if manager==null:return
	if not pending_cart_path.is_empty():
		pending_cart_age+=delta
		_resolve_saved_cart()
	var endpoint:String=manager.next_endpoint()
	marker.visible=not manager.active.is_empty() and (manager.active=="port_delivery" or manager.JOBS[manager.active].kind=="escort") and manager.targets.has(endpoint) and not manager.player.get_meta("morning_tutorial_active",false) and not manager.player.get_meta("opening_active",false) and not get_tree().paused
	if marker.visible:marker.global_position=parking_position(endpoint)
	if phase.is_empty() and manager.active=="port_delivery" and not get_tree().paused:
		var mounted:Node=manager.player.get_meta("mounted_vehicle") if manager.player.has_meta("mounted_vehicle") else null
		if mounted!=null and mounted.role=="driver" and absf(mounted.speed)<.15 and mounted.transition.is_empty():
			if manager.stages[manager.active]=="accepted" and mounted.cart.global_position.distance_to(parking_position("port_cargo"))<4:
				if pickup(manager.active):manager.stages[manager.active]="carrying";manager._message("Consignment loaded. Return to the marked counting-house bay.")
			elif manager.stages[manager.active]=="carrying" and mounted.cart==vehicle and vehicle.global_position.distance_to(parking_position("office"))<4:begin(manager.active)
	if phase.is_empty() or get_tree().paused:return
	if phase=="recovering":
		age+=delta
		if not is_instance_valid(receiver):phase="";return
		if _follow_route(delta) or age>45:_release_receiver()
		return
	if manager.active!=request or not is_instance_valid(receiver) or receiver.get_meta("dead",false):abort();return
	age+=delta
	if phase=="receiving":
		var target:Vector3=receiver.to_global(Vector3(0,.95,.32))
		if goods.get_parent()!=self:goods.reparent(self,true)
		# The receiver approaches the goods before carrying them back, with swept collision.
		var stand:Vector3=vehicle.to_global(Vector3(-1.8,0,2.65)) if is_instance_valid(vehicle) else goods.global_position
		if not route.is_empty():
			if not _follow_route(delta):
				if age>45:manager._message("The unloading path is blocked. Move the cart and try again.");abort()
				return
		var offset:Vector3=stand-receiver.global_position;offset.y=0
		if offset.length()>(.08 if is_instance_valid(vehicle) else .65):
			if not _step(offset.normalized()*minf(delta*.85,maxf(.02,offset.length()-(.08 if is_instance_valid(vehicle) else .65))),delta):
				if age>45:manager._message("The unloading path is blocked. Move the cart and try again.");abort()
			return
		var facing:=goods.global_position-receiver.global_position;receiver.global_rotation.y=atan2(facing.x,facing.z)
		target=receiver.to_global(Vector3(0,.95,.32))
		goods.global_position=goods.global_position.lerp(target,minf(1,delta*3))
		_hold(delta)
		if age>2.4 and goods.global_position.distance_to(target)<.06:phase="returning";age=0;route=trail.duplicate();route.reverse()
	elif phase=="returning":
		if not route.is_empty() and not _follow_route(delta):
			goods.global_position=receiver.to_global(Vector3(0,.95,.32));_hold(delta)
			if age>45:abort()
			return
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
			var delivered:=goods;goods=null
			if is_instance_valid(delivered):
				var prior:=manager.get_parent().get_node_or_null("ReceivedConsignment_"+id)
				if prior!=null:prior.queue_free()
				delivered.reparent(manager.get_parent(),true);delivered.name="ReceivedConsignment_"+id
				delivered.global_position=receiver.global_position+receiver.global_basis.x*.7
				var solid:=StaticBody3D.new();solid.name="ReceivedCargoCollision";solid.collision_layer=1;delivered.add_child(solid)
				var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.1,.95,1.2)
				collider.shape=box;collider.position.y=.48;solid.add_child(collider)
			clear();_release_receiver();manager._finish(id,true)
			manager._message("Thank you. Delivery received — %d rupees paid."%int(manager.JOBS[id].pay))

func _step(motion:Vector3,delta:float)->bool:
	var body:CollisionObject3D=receiver.body_collider
	var shape:CollisionShape3D=body.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.transform.origin.y+=.30;query.motion=motion;query.collision_mask=1
	query.exclude=[body.get_rid(),manager.targets[manager.JOBS[request].goal].get_rid()]
	var safe:=get_world_3d().direct_space_state.cast_motion(query)
	if safe[0]<.99:return false
	receiver.global_position+=motion
	if phase=="receiving" and (trail.is_empty() or trail[-1].distance_to(receiver.global_position)>.35):trail.append(receiver.global_position)
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
	if is_instance_valid(receiver):
		receiver.set_grip("l",0);receiver.set_grip("r",0)
		route=trail.duplicate();route.reverse()
	if is_instance_valid(vehicle):
		vehicle.remove_meta("errand_transfer")
		if is_instance_valid(goods):goods.reparent(vehicle.visual_root,true);goods.position=Vector3(-.55,1.55,2.65)
	elif is_instance_valid(goods):goods.queue_free();goods=null
	phase="recovering" if is_instance_valid(receiver) and not route.is_empty() else "";age=0
	if phase.is_empty():_release_receiver()

func _release_receiver()->void:
	if is_instance_valid(receiver):receiver.set_process(true)
	phase="";request="";receiver=null;route.clear();trail.clear()

func clear()->void:
	pending_cart_path="";pending_cart_age=0
	abort()
	if is_instance_valid(vehicle):vehicle.remove_meta("errand_cargo")
	if is_instance_valid(goods):goods.queue_free()
	goods=null;vehicle=null

func export_state()->Dictionary:
	return {"cart":str(manager.get_parent().get_path_to(vehicle)) if is_instance_valid(vehicle) else pending_cart_path}

func restore_state(state:Dictionary)->void:
	clear()
	if manager.active!="port_delivery" or manager.stages.get(manager.active,"")!="carrying":return
	var path:String=str(state.get("cart",""))
	if path.is_empty() or path.begins_with("/") or ".." in path:manager.stages[manager.active]="accepted";return
	pending_cart_path=path;pending_cart_age=0
	_resolve_saved_cart()

func _resolve_saved_cart()->void:
	if manager.active!="port_delivery" or manager.stages.get(manager.active,"")!="carrying":pending_cart_path="";return
	vehicle=manager.get_parent().get_node_or_null(NodePath(pending_cart_path))
	if vehicle==null:
		var population:Node=manager.get_parent().get_node_or_null("CityRoutePopulation")
		if pending_cart_age<12 and population!=null and not population.ready_population:return
		pending_cart_path="";manager.stages[manager.active]="accepted";return
	pending_cart_path=""
	if not vehicle.is_in_group("live_travel_carts") or vehicle.get("variant")!=1:
		vehicle=null;manager.stages[manager.active]="accepted";return
	goods=Crate.instantiate();goods.name="EntrustedConsignment";goods.scale=Vector3.ONE*.38;vehicle.visual_root.add_child(goods);goods.position=Vector3(-.55,1.55,2.65)
	vehicle.set_meta("errand_cargo","port_delivery")

func _follow_route(delta:float)->bool:
	while not route.is_empty():
		var offset:=route[0]-receiver.global_position;offset.y=0
		if offset.length()<.08:route.pop_front();continue
		# Keep the clerk at the clear edge of his post if the authored idle point
		# touches furniture; returning must never push his capsule into it.
		if route.size()==1 and phase in ["returning","recovering"] and offset.length()<.40:
			finish=receiver.global_position;route.clear();return true
		_step(offset.normalized()*minf(offset.length(),delta*.85),delta)
		return false
	return true

func _route_to(goal:Vector3)->Array[Vector3]:
	# A bounded local search uses the same complete capsule as the moving clerk.
	# Furniture, walls and the cart remain solid during both search and playback.
	var origin:=receiver.global_position
	var destination:=Vector2i(roundi(goal.x-origin.x),roundi(goal.z-origin.z))
	var pending:Array[Vector2i]=[Vector2i.ZERO]
	var costs:Dictionary={Vector2i.ZERO:0.0}
	var parents:Dictionary={}
	var points:Dictionary={Vector2i.ZERO:origin}
	var body:CollisionObject3D=receiver.body_collider
	var shape:CollisionShape3D=body.get_node("BodyShape")
	var excluded:Array[RID]=[body.get_rid(),manager.targets[manager.JOBS[request].goal].get_rid()]
	for attempt in 1200:
		if pending.is_empty():break
		var best:=0;var score:=INF
		for i in pending.size():
			var cell:Vector2i=pending[i]
			var candidate:float=float(costs[cell])+Vector2(cell-destination).length()
			if candidate<score:score=candidate;best=i
		var cell:Vector2i=pending.pop_at(best)
		if cell==destination:
			var result:Array[Vector3]=[goal]
			while cell!=Vector2i.ZERO:
				result.push_front(points[cell]);cell=parents[cell]
			return result
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			var next:Vector2i=cell+direction
			if absi(next.x)>18 or absi(next.y)>18:continue
			var cost:float=float(costs[cell])+Vector2(direction).length()
			if costs.has(next) and float(costs[next])<=cost:continue
			var at:Vector3=points[cell]
			var to:=origin+Vector3(next.x,0,next.y)
			var ray:=PhysicsRayQueryParameters3D.create(to+Vector3.UP*1.5,to-Vector3.UP*1.0,1,excluded)
			var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or absf(hit.position.y-at.y)>.4:continue
			to.y=hit.position.y
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape
			query.transform=shape.global_transform;query.transform.origin+=at-origin+Vector3.UP*.30
			query.motion=to-at;query.collision_mask=1;query.exclude=excluded
			if get_world_3d().direct_space_state.cast_motion(query)[0]<.99:continue
			costs[next]=cost;parents[next]=cell;points[next]=to
			if not pending.has(next):pending.append(next)
	return []
