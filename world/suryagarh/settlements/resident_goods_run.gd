extends Node
## A bounded daily consignment, physically moved by an existing MPFB worker.
const Budget=preload("res://systems/simulation_budget.gd")
const Route=preload("res://world/suryagarh/settlements/resident_walk_route.gd")
var actor:Node3D
var institution:Node3D
var viewer:Node3D
var clock:Node
var work_kind:="hospital"
var cart:Node3D
var goods:Array[Node3D]=[]
var waypoints:Array[Vector3]=[]
var ankles:Dictionary={}
var phase:="collect"
var progress:=0.0
var delivered:=0
var day:=-1
var waypoint:=1
var age:=0.0
var elapsed:=0.0
var blocked:=0
var hand_error:=0.0
var pending:Dictionary={}
var collision_excluded:Array[RID]=[]
var lean_blend:=0.0
var detour:Array[Vector3]=[]
var detour_goal:=Vector3.INF
var retry_age:=0.0
var blocked_age:=0.0
var navigation_pending:=false
var freight_phase:="parked"
var freight_distance:=0.0
var shipment:=0
var source_side:=-1.0
var freight_loaded:=0
var freight_waypoint:=0
var route_points:Array[Vector3]=[]
var receiving_door:Node3D
var supply_bench:Node3D
var loading_steps:Array[Node3D]=[]
var store_base:=Vector3(.53,1.15,1)
var stand_base:=Vector3(.1,.24,1)

func _ready()->void:
	add_to_group("institution_operations")
	actor.set_process(false)
	prepare.call_deferred()

func prepare()->void:
	var linen:bool=work_kind=="hospital"
	cart=preload("res://vehicles/bullock_cart.gd").new();cart.name="HospitalLinenCart" if linen else "DepotReceivingCart"
	institution.add_child(cart);cart.position=Vector3(5,0,11)
	cart.set_meta("assigned_workplace",str(institution.get_path()))
	cart.set_meta("errand_transfer",true)
	var builder:=preload("res://world/suryagarh/settlements/settlement_builder.gd").new()
	var wood:=builder.material(Color(.28,.19,.11))
	var shelf_name:String="LinenShelf" if linen else "StoresReceivingShelf"
	builder.piece(institution,shelf_name,Vector3(store_base.x+.32,store_base.y-.05,store_base.z+.55),Vector3(.85,.10,2.2),wood)
	for z in [.6,2.5]:builder.piece(institution,shelf_name+"Leg",Vector3(store_base.x+.42,.68,z),Vector3(.1,.88,.1),wood)
	supply_bench=builder.piece(institution,"SupplierLoadingBench",Vector3(5+source_side*3.3,.85,21),Vector3(2,.1,.35),wood)
	for x in [-.85,.85]:builder.piece(supply_bench,"LoadingBenchLeg",Vector3(x,-.45,0),Vector3(.12,.80,.15),wood)
	for index in 8:
		var step:=builder.piece(institution,"SupplierLoadingStep",Vector3(5,0,17+4.15+index*.28),Vector3(2,.05,.28),wood)
		step.visible=false
		step.get_child(1).collision_layer=0
		loading_steps.append(step)
	builder.free()
	await get_tree().physics_frame
	var bench_at:=institution.to_global(Vector3(5+source_side*3.3,0,21))
	var bench_excluded:Array[RID]=[]
	for collider in supply_bench.find_children("*","CollisionObject3D",true,false):bench_excluded.append(collider.get_rid())
	var bench_ray:=PhysicsRayQueryParameters3D.create(bench_at+Vector3.UP*3,bench_at-Vector3.UP*5,1,bench_excluded)
	var bench_ground:=actor.get_world_3d().direct_space_state.intersect_ray(bench_ray)
	if not bench_ground.is_empty():supply_bench.global_position.y=bench_ground.position.y+.85
	for child in cart.visual_root.get_children():
		if str(child.name).begins_with("ProduceBundle") or str(child.name)=="LoadTie":child.queue_free()
		elif str(child.name).begins_with("EndBoard") and child.position.z>3:
			var hinge:=Node3D.new();hinge.name="OpenTailboard";cart.visual_root.add_child(hinge);hinge.position=Vector3(0,1.185,3.95)
			child.reparent(hinge,true);hinge.rotation.x=PI
	collision_excluded.append(actor.body_collider.get_rid())
	for handle in get_tree().get_nodes_in_group("cart_boarding_handles"):
		if cart.is_ancestor_of(handle) and handle is CollisionObject3D:collision_excluded.append(handle.get_rid())
	for i in 3:
		var load_:Node3D=load("res://assets/props/polyhaven/wooden_crate_02/wooden_crate_02_1k.gltf").instantiate()
		load_.name=("LinenConsignment%d" if linen else "StoresConsignment%d")%i;load_.scale=Vector3.ONE*.38;cart.add_child(load_);load_.position=Vector3(-.5+i*.5,1.185,3.75)
		load_.set_meta("contents",{"hospital":"hospital linen","depot":"commissariat stores","port":"customs freight","market":"market merchandise","household":"household provisions"}.get(work_kind,"provisions"))
		var body:=StaticBody3D.new();body.name="ConsignmentBody";body.collision_layer=0;body.collision_mask=0;load_.add_child(body)
		var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.1,.95,1.2);collision.shape=box;collision.position.y=.475;body.add_child(collision)
		# The carrier owns manipulation clearance; other people retain goods collision.
		collision_excluded.append(body.get_rid())
		for mesh:GeometryInstance3D in load_.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=150
		goods.append(load_)
		await get_tree().process_frame
	for side in ["l","r"]:ankles[side]=actor.foot_plant.ankle_height[side]-actor.global_position.y
	work_tree()
	# The open central aisle lies between the existing ward beds and divisions.
	# The receiving orderly owns the center of the broad entrance. The porter
	# uses its left side, so his mandatory stop never coincides with that body.
	var points:Array=route_points if route_points.size()==5 else [Vector3(4.5,0,15.28),Vector3(3,0,15.4),Vector3(-.85,0,7),Vector3(-.85,.24,4),Vector3(0,.24,1)]
	for at in points:waypoints.append(institution.to_global(at))
	if not pending.is_empty():restore_state(pending);pending.clear()
	elif clock!=null:day=clock.current_day

func _physics_process(delta:float)->void:
	if goods.size()!=3 or waypoints.size()!=5 or ankles.size()!=2:return
	age+=delta
	if age<Budget.interval(actor,viewer):return
	# Consume remote elapsed time without jumping through an obstacle or dropping clocks.
	for slice_index in 5:
		if age<=0:break
		var slice:=minf(age,.1);age-=slice;tick(slice)

func tick(delta:float)->void:
	if waypoints.size()!=5:return
	if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false):return
	elapsed+=delta
	if clock!=null and (clock.current_hour<7 or clock.current_hour>=18):
		if cart.boarding.rider==null:cart.boarding.speed=0;cart.set_forward_motion(0,delta)
		actor.travel_speed=0;actor._set_animation(&"idle",delta);contact();return
	if phase=="rest":
		var waiting_spot:Vector3=institution.to_global(Vector3(8,0,15.4))
		var loading:bool=freight_phase.begins_with("loading_")
		var stepping_aside:=walk(waiting_spot,delta) if not loading else false
		if loading or actor.global_position.distance_to(waiting_spot)<.04:freight_tick(delta)
		actor._set_animation(&"walk" if actor.travel_speed>0 else &"idle",delta)
		for side in ["l","r"]:actor.foot_plant.ankle_height[side]=actor.global_position.y+float(ankles.get(side,0.0))
		contact()
		actor.set_meta("daily_activity",work_kind+"_"+freight_phase)
		return
	var moving:=false
	if phase in ["collect","inside","return"]:
		if receiving_door!=null and waypoint in [2,3] and not receiving_door.get("locked"):receiving_door.set_open(true)
		var goal:Vector3=waypoints[waypoint]
		if waypoint==0:goal=institution.to_global(Vector3(4.5+mini(delivered,2)*.5,0,15.28))
		elif waypoint==4:goal=institution.to_global(stand_base+Vector3(0,0,delivered*.55))
		var supported_y:=destination_floor(goal)
		if is_finite(supported_y):goal.y=supported_y
		moving=walk(goal,delta)
		if actor.global_position.distance_to(goal)<.035:
			match phase:
				"collect":
					if waypoint>0:waypoint-=1
					else:phase="lift";progress=0;actor.global_rotation.y=PI
				"inside":
					if waypoint<waypoints.size()-1:waypoint+=1
					else:phase="lower";progress=0;actor.global_rotation.y=PI/2
				"return":
					if waypoint>0:waypoint-=1
					else:phase="rest" if delivered>=3 else "lift";progress=0;actor.global_rotation.y=PI
	else:
		actor.travel_speed=0
		if phase in ["lift","lower"]:
			progress=minf(1,progress+delta/2.0)
			var item:Node3D=goods[delivered]
			var target:=actor.to_global(Vector3(0,.91,.34))
			var origin:=cart.to_global(Vector3(-.5+delivered*.5,1.185,3.75)) if phase=="lift" else target
			var end:=target if phase=="lift" else institution.to_global(store_base+Vector3(0,0,delivered*.55))
			item.global_position=origin.lerp(end,smoothstep(.2,1,progress) if phase=="lift" else smoothstep(0,1,progress))
			if progress>=1:
				if phase=="lift":place(item,actor,Vector3(0,.91,.34));phase="inside";waypoint=1
				else:place(item,institution,store_base+Vector3(0,0,delivered*.55));delivered+=1;phase="return";waypoint=waypoints.size()-2
	actor.set_meta("daily_activity",work_kind+"_"+phase)
	var desired_lean:=sin(progress*PI)*.6 if phase=="lift" else (smoothstep(0,.65,progress) if phase=="lower" else 0.0)
	lean_blend=move_toward(lean_blend,desired_lean,delta*3)
	actor.animation_tree.set("parameters/linen_work/blend_amount",lean_blend)
	actor._set_animation(&"walk" if moving else &"idle",delta)
	for side in ["l","r"]:actor.foot_plant.ankle_height[side]=actor.global_position.y+float(ankles.get(side,0.0))
	contact()

func freight_tick(delta:float)->void:
	# The empty cart leaves before another consignment can be loaded. Its own
	# draft team and boarding clearance remain authoritative during the trip.
	if freight_phase=="parked":freight_phase="departing"
	if freight_phase=="awaiting_supply":
		cart.boarding.speed=0;cart.set_forward_motion(0,delta)
		if clock==null or clock.current_day==day:return
		# Yesterday's linen has gone to laundry / stores have been issued. Reuse
		# the bounded crate pool only at the supplier end of the visible journey.
		day=clock.current_day;shipment+=1;delivered=0
		position_supply_bench()
		for i in goods.size():
			place(goods[i],cart,cart.to_local(supply_point(i)))
			goods[i].get_node("ConsignmentBody").collision_layer=1
			goods[i].set_meta("shipment",shipment)
		freight_loaded=0;freight_waypoint=0;progress=0;freight_phase="loading_collect"
	if freight_phase.begins_with("loading_"):
		load_supply(delta);return
	if freight_phase not in ["departing","arriving"]:return
	if cart.boarding.rider!=null or not cart.can_move():
		cart.boarding.speed=0;cart.set_forward_motion(0,delta);return
	var distance:float=minf(.65*delta,6.0-freight_distance) if freight_phase=="departing" else minf(.95*delta,freight_distance)
	var next:Vector3=cart.global_position+institution.global_basis.z*distance*(1 if freight_phase=="departing" else -1)
	var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*2,next-Vector3.UP*3,1,cart.boarding._vehicle_exclusions())
	var ground:=cart.get_world_3d().direct_space_state.intersect_ray(ray)
	if not ground.is_empty():next.y=ground.position.y
	if ground.is_empty() or absf(next.y-cart.global_position.y)>.35 or not cart.boarding._clearance_at(next):
		cart.boarding.speed=0;cart.set_forward_motion(0,delta);return
	cart.global_position=next
	freight_distance+=distance*(1 if freight_phase=="departing" else -1)
	cart.boarding.speed=-.65 if freight_phase=="departing" else .95
	cart.set_forward_motion(cart.boarding.speed,delta)
	if freight_phase=="departing" and freight_distance>=5.99:
		freight_phase="awaiting_supply";cart.boarding.speed=0;cart.set_forward_motion(0,delta)
	elif freight_phase=="arriving" and freight_distance<=.01:
		freight_distance=0;freight_phase="parked";phase="collect";waypoint=1
		cart.boarding.speed=0;cart.set_forward_motion(0,delta)

func position_supply_bench()->void:
	var at:=cart.to_global(Vector3(source_side*3.3,0,4))
	var excluded:Array[RID]=collision_excluded.duplicate()
	excluded.append_array(cart.boarding._vehicle_exclusions())
	for collider in supply_bench.find_children("*","CollisionObject3D",true,false):excluded.append(collider.get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at-Vector3.UP*5,1,excluded)
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():at.y=hit.position.y
	supply_bench.global_position=at+Vector3.UP*.85
	for index in loading_steps.size():
		var point:=cart.to_global(Vector3(0,0,4.15+index*.28))
		var step_excluded:Array[RID]=excluded.duplicate()
		for step in loading_steps:step_excluded.append(step.get_child(1).get_rid())
		var ground_ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*5,1,step_excluded)
		var ground:=actor.get_world_3d().direct_space_state.intersect_ray(ground_ray)
		if ground.is_empty():continue
		var height:float=maxf(.04,(cart.global_position.y-ground.position.y)*(1.0-float(index)/7.0))
		var step:Node3D=loading_steps[index]
		step.global_position=Vector3(point.x,ground.position.y+height*.5,point.z)
		step.get_child(0).mesh.size=Vector3(2,height,.28)
		step.get_child(1).get_child(0).shape.size=Vector3(2,height,.28)
		step.get_child(1).collision_layer=1;step.visible=true

func supply_point(index:int)->Vector3:
	return supply_bench.to_global(Vector3(source_side*(.5-index*.5),.05,0))

func load_supply(delta:float)->void:
	if freight_phase=="loading_clear":
		var exits:Array=[cart.to_global(Vector3(.5,0,6.7)),cart.to_global(Vector3(3,0,6.7)),institution.to_global(Vector3(8,0,15.4))]
		var exit:Vector3=exits[freight_waypoint]
		var height:=destination_floor(exit)
		if is_finite(height):exit.y=height
		walk(exit,delta)
		if actor.global_position.distance_to(exit)<.035:
			if freight_waypoint<2:freight_waypoint+=1
			else:freight_phase="arriving";freight_waypoint=0
		return
	var item:Node3D=goods[freight_loaded]
	var source:=supply_point(freight_loaded)
	var bay:=cart.to_global(Vector3(-.5+freight_loaded*.5,1.185,3.75))
	if freight_phase in ["loading_collect","loading_carry"]:
		var pickup_x:float=source_side*(3.8-freight_loaded*.5)
		var bay_x:float=-.5+freight_loaded*.5
		var exit_x:float=3.0 if freight_loaded==0 else -.5+(freight_loaded-1)*.5
		var points:Array=[Vector3(exit_x,0,6.7),Vector3(pickup_x,0,6.7),Vector3(pickup_x,0,4.5)] if freight_phase=="loading_collect" else [Vector3(pickup_x,0,6.7),Vector3(bay_x,0,6.7),Vector3(bay_x,0,4.28)]
		var goal:Vector3=cart.to_global(points[freight_waypoint])
		var floor_y:=destination_floor(goal)
		if is_finite(floor_y):goal.y=floor_y
		walk(goal,delta)
		if actor.global_position.distance_to(goal)<.035:
			if freight_waypoint<2:freight_waypoint+=1;return
			freight_waypoint=0
			freight_phase="loading_lift" if freight_phase=="loading_collect" else "loading_lower"
			progress=0;actor.global_rotation.y=PI
		return
	actor.travel_speed=0;progress=minf(1,progress+delta/2)
	var held:=actor.to_global(Vector3(0,1.0,.30))
	item.global_position=source.lerp(held,smoothstep(0,1,progress)) if freight_phase=="loading_lift" else held.lerp(bay,smoothstep(0,1,progress))
	if progress<1:return
	if freight_phase=="loading_lift":
		place(item,actor,Vector3(0,1.0,.30));freight_phase="loading_carry"
	else:
		place(item,cart,Vector3(-.5+freight_loaded*.5,1.185,3.75));freight_loaded+=1
		freight_phase="loading_clear" if freight_loaded>=goods.size() else "loading_collect"
		progress=0

func work_tree()->void:
	var clip:=Animation.new();clip.length=1
	for entry in [["spine_01",.24],["spine_02",.20]]:
		var bone:String=entry[0]
		if not actor._base_rotations.has(bone):continue
		var track:=clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath(str(actor.get_path_to(actor._skeleton))+":"+bone))
		clip.rotation_track_insert_key(track,0,actor._base_rotations[bone]*Quaternion(actor._pitch_axes[bone],float(entry[1])))
	actor.animation_player.get_animation_library("").add_animation("linen_work",clip)
	var graph:AnimationNodeBlendTree=actor.animation_tree.tree_root
	var work:=AnimationNodeAnimation.new();work.animation=&"linen_work";graph.add_node("linen_activity",work)
	var blend:=AnimationNodeBlend2.new();blend.filter_enabled=true
	for track in clip.get_track_count():blend.set_filter_path(clip.track_get_path(track),true)
	graph.add_node("linen_work",blend)
	var parent_node:String="combat" if graph.has_node("combat") else "output"
	graph.disconnect_node(parent_node,0);graph.connect_node("linen_work",0,"turning");graph.connect_node("linen_work",1,"linen_activity");graph.connect_node(parent_node,0,"linen_work")
	actor.animation_tree.set("parameters/linen_work/blend_amount",0.0)

func destination_floor(at:Vector3)->float:
	var height:=Route.support(actor,at)
	if is_finite(height):return height
	# Long freight waypoints can lie lower than the initial cart platform.
	# Find their real ground without treating characters or cart handles as it.
	var excluded:Array[RID]=collision_excluded.duplicate()
	excluded.append_array(cart.boarding._vehicle_exclusions())
	excluded.append_array(Route.floor_excluded)
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at-Vector3.UP*5,1,excluded)
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else INF

func walk(goal:Vector3,delta:float)->bool:
	retry_age=maxf(0,retry_age-delta)
	if goal.distance_to(detour_goal)>.05:detour.clear();detour_goal=goal
	while not detour.is_empty() and actor.global_position.distance_to(detour[0])<.035:detour.pop_front()
	var destination:Vector3=detour[0] if not detour.is_empty() else goal
	var offset:=destination-actor.global_position
	offset.y=0
	if offset.length()<.035:
		var resting_floor:=destination_floor(actor.global_position)
		if is_finite(resting_floor) and absf(resting_floor-actor.global_position.y)<.30:
			actor.global_position.y=resting_floor;actor.body_collider.force_update_transform()
		actor.travel_speed=0;return false
	var motion:=offset.limit_length(.95*delta)
	var collider:CollisionObject3D=actor.body_collider
	var shape:CollisionShape3D=collider.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform
	var next_floor:=destination_floor(actor.global_position+motion)
	if phase=="rest" and freight_phase=="loading_carry" and freight_waypoint==2:
		var leading_floor:=destination_floor(actor.global_position+motion+motion.normalized()*.40)
		if is_finite(leading_floor) and is_finite(next_floor):next_floor=maxf(next_floor,leading_floor)
	var rise:float=maxf(0,next_floor-actor.global_position.y) if is_finite(next_floor) else 0.0
	query.transform.origin+=Vector3.UP*.15;query.collision_mask=1;query.exclude=collision_excluded;query.margin=.02
	if rise>.30:actor.travel_speed=0;return false
	# Step onto a real low stair; test the raised capsule before crossing its
	# edge. Tall walls and overhead obstructions still stop the whole body.
	if rise>0:
		query.motion=Vector3.UP*rise
		if actor.get_world_3d().direct_space_state.cast_motion(query)[0]<.99:actor.travel_speed=0;return false
		query.transform.origin+=Vector3.UP*rise
	query.motion=motion
	var space:=actor.get_world_3d().direct_space_state
	var fraction:float=space.cast_motion(query)[0]
	query.transform.origin+=motion;query.motion=Vector3.ZERO
	var overlaps:=space.intersect_shape(query,1)
	if fraction<.99 or not overlaps.is_empty():
		actor.travel_speed=0;blocked+=1
		blocked_age+=delta
		if blocked_age>=4 and retry_age<=0:
			retry_age=4.0
			if not navigation_pending:request_detour.call_deferred(goal)
		if blocked==1:
			for hit in overlaps:print("GOODS_BLOCKER ",hit.collider.get_path()," parent=",hit.collider.get_parent().name," at=",actor.global_position," goal=",goal)
		return false
	blocked_age=0.0
	actor.global_position+=motion
	var floor_y:=Route.support(actor,actor.global_position)
	if is_finite(floor_y):actor.global_position.y=maxf(floor_y,next_floor) if rise>0 else floor_y
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*2.5)
	actor.travel_speed=.95;collider.force_update_transform();return true

func request_detour(goal:Vector3)->void:
	if navigation_pending or not is_instance_valid(actor) or not actor.is_inside_tree():return
	navigation_pending=true
	preload("res://systems/navigation_work_queue.gd").request(self,actor,goal)

func receive_navigation(path:Array[Vector3],goal:Vector3)->void:
	navigation_pending=false
	if is_instance_valid(actor) and actor.is_inside_tree() and goal.distance_to(detour_goal)<.05:detour=path

func contact()->void:
	var loading:bool=phase=="rest" and freight_phase in ["loading_lift","loading_carry","loading_lower"]
	if not loading and (delivered>=goods.size() or phase not in ["lift","inside","lower"]):return
	var item:Node3D=goods[freight_loaded if loading else delivered]
	hand_error=0
	for side in ["l","r"]:
		var target:=item.global_position+Vector3.UP*.14+actor.global_basis.x*((.17 if side=="l" else -.17) if loading else (.18 if side=="l" else -.18))
		if phase=="lift" and progress<.2:target=actor.palm_world(side).lerp(target,smoothstep(0,.2,progress))
		actor.solve_hand_contact(side,target)
		if loading and actor.palm_world(side).distance_to(target)>.02:actor.solve_hand_contact(side,target)
		actor.set_grip(side,.5)
		hand_error=maxf(hand_error,actor.palm_world(side).distance_to(target))

func place(item:Node3D,parent:Node3D,at:Vector3)->void:
	if item.get_parent()!=parent:item.reparent(parent)
	item.position=at;item.rotation=Vector3.ZERO
	item.get_node("ConsignmentBody").collision_layer=1 if parent==institution else 0

func export_state()->Dictionary:
	return {"institution_anchor":[institution.global_position.x,institution.global_position.y,institution.global_position.z],"phase":phase,"progress":progress,"delivered":delivered,"day":day,"waypoint":waypoint,"position":[actor.position.x,actor.position.y,actor.position.z],"freight_phase":freight_phase,"freight_distance":freight_distance,"shipment":shipment,"freight_loaded":freight_loaded,"freight_waypoint":freight_waypoint,"cart_position":[cart.position.x,cart.position.y,cart.position.z]}

func restore_state(data:Dictionary)->void:
	if data.is_empty():return
	if goods.size()!=3:pending=data.duplicate(true);return
	phase=str(data.get("phase","collect"))
	if phase not in ["collect","lift","inside","lower","return","rest"]:phase="collect"
	delivered=clampi(int(data.get("delivered",0)),0,3);day=int(data.get("day",-1));waypoint=clampi(int(data.get("waypoint",0)),0,4);progress=clampf(float(data.get("progress",0)),0,1)
	if delivered>=3 and phase in ["lift","inside","lower"]:phase="return"
	var at:Variant=data.get("position",[])
	if at is Array and at.size()==3:
		var point:=Vector3(float(at[0]),float(at[1]),float(at[2]))
		if point.is_finite():
			if work_kind=="household":
				var old_anchor:Vector3=institution.get_parent().to_global(Vector3(3,0,1))
				var saved_anchor:Variant=data.get("institution_anchor",[])
				if saved_anchor is Array and saved_anchor.size()==3:old_anchor=Vector3(float(saved_anchor[0]),float(saved_anchor[1]),float(saved_anchor[2]))
				if old_anchor.is_finite():point+=actor.get_parent().global_basis.inverse()*(institution.global_position-old_anchor)
			actor.position=point
	freight_phase=str(data.get("freight_phase","parked"))
	if freight_phase not in ["parked","departing","awaiting_supply","arriving","loading_collect","loading_lift","loading_carry","loading_lower","loading_clear"]:freight_phase="parked"
	freight_distance=clampf(float(data.get("freight_distance",0)),0,6)
	shipment=maxi(0,int(data.get("shipment",0)))
	freight_loaded=clampi(int(data.get("freight_loaded",0)),0,3)
	freight_waypoint=clampi(int(data.get("freight_waypoint",0)),0,2)
	var cart_at:Variant=data.get("cart_position",[])
	if cart_at is Array and cart_at.size()==3:
		var cart_point:=Vector3(float(cart_at[0]),float(cart_at[1]),float(cart_at[2]))
		if cart_point.is_finite():cart.position=cart_point
	if freight_phase.begins_with("loading_"):position_supply_bench()
	for i in goods.size():
		if freight_phase.begins_with("loading_"):
			if i<freight_loaded:place(goods[i],cart,Vector3(-.5+i*.5,1.185,3.75))
			elif i==freight_loaded and freight_phase in ["loading_carry","loading_lower"]:place(goods[i],actor,Vector3(0,1.0,.30))
			else:
				place(goods[i],cart,cart.to_local(supply_point(i)));goods[i].get_node("ConsignmentBody").collision_layer=1
		elif i<delivered:place(goods[i],institution,store_base+Vector3(0,0,i*.55))
		elif i==delivered and phase in ["inside","lower"]:place(goods[i],actor,Vector3(0,.91,.34))
		else:place(goods[i],cart,Vector3(-.5+i*.5,1.185,3.75))
