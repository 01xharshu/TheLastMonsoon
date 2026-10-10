extends Node
## A bounded daily consignment, physically moved by an existing MPFB worker.
const Budget=preload("res://systems/simulation_budget.gd")
const Route=preload("res://world/suryagarh/settlements/resident_walk_route.gd")
var actor:Node3D
var institution:Node3D
var viewer:Node3D
var clock:Node
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

func _ready()->void:
	add_to_group("institution_operations")
	actor.set_process(false)
	prepare.call_deferred()

func prepare()->void:
	cart=preload("res://vehicles/bullock_cart.gd").new();cart.name="HospitalLinenCart"
	institution.add_child(cart);cart.position=Vector3(5,0,11)
	cart.set_meta("assigned_workplace",str(institution.get_path()))
	cart.set_meta("errand_transfer",true)
	var builder:=preload("res://world/suryagarh/settlements/settlement_builder.gd").new()
	var wood:=builder.material(Color(.28,.19,.11))
	builder.piece(institution,"LinenShelf",Vector3(.85,1.10,1.55),Vector3(.85,.10,2.2),wood)
	for z in [.6,2.5]:builder.piece(institution,"LinenShelfLeg",Vector3(.95,.68,z),Vector3(.1,.88,.1),wood)
	builder.free()
	await get_tree().physics_frame
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
		load_.name="LinenConsignment%d"%i;load_.scale=Vector3.ONE*.38;cart.add_child(load_);load_.position=Vector3(-.5+i*.5,1.185,3.75)
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
	for at in [Vector3(4.5,0,15.28),Vector3(3,0,15.4),Vector3(-.85,0,7),Vector3(-.85,.24,4),Vector3(0,.24,1)]:waypoints.append(institution.to_global(at))
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
		actor.travel_speed=0;actor._set_animation(&"idle",delta);contact();return
	if phase=="rest" and clock!=null and clock.current_day!=day:
		day=clock.current_day;delivered=0;phase="collect";waypoint=1
		for i in goods.size():place(goods[i],cart,Vector3(-.5+i*.5,1.185,3.75))
	var moving:=false
	if phase in ["collect","inside","return"]:
		var goal:Vector3=waypoints[waypoint]
		if waypoint==0:goal=institution.to_global(Vector3(4.5+mini(delivered,2)*.5,0,15.28))
		elif waypoint==4:goal=institution.to_global(Vector3(.1,.24,1+delivered*.55))
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
			var end:=target if phase=="lift" else institution.to_global(Vector3(.53,1.15,1+delivered*.55))
			item.global_position=origin.lerp(end,smoothstep(.2,1,progress) if phase=="lift" else smoothstep(0,1,progress))
			if progress>=1:
				if phase=="lift":place(item,actor,Vector3(0,.91,.34));phase="inside";waypoint=1
				else:place(item,institution,Vector3(.53,1.15,1+delivered*.55));delivered+=1;phase="return";waypoint=waypoints.size()-2
	actor.set_meta("daily_activity","hospital_"+phase)
	var desired_lean:=sin(progress*PI)*.6 if phase=="lift" else (smoothstep(0,.65,progress) if phase=="lower" else 0.0)
	lean_blend=move_toward(lean_blend,desired_lean,delta*3)
	actor.animation_tree.set("parameters/linen_work/blend_amount",lean_blend)
	actor._set_animation(&"walk" if moving else &"idle",delta)
	for side in ["l","r"]:actor.foot_plant.ankle_height[side]=actor.global_position.y+float(ankles.get(side,0.0))
	contact()

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

func walk(goal:Vector3,delta:float)->bool:
	retry_age=maxf(0,retry_age-delta)
	if goal.distance_to(detour_goal)>.05:detour.clear();detour_goal=goal
	while not detour.is_empty() and actor.global_position.distance_to(detour[0])<.035:detour.pop_front()
	var destination:Vector3=detour[0] if not detour.is_empty() else goal
	var offset:=destination-actor.global_position
	if offset.length()<.035:actor.travel_speed=0;return false
	var motion:=offset.limit_length(.95*delta)
	var collider:CollisionObject3D=actor.body_collider
	var shape:CollisionShape3D=collider.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform
	query.transform.origin+=Vector3.UP*.15;query.motion=motion;query.collision_mask=1;query.exclude=collision_excluded;query.margin=.02
	var space:=actor.get_world_3d().direct_space_state
	var fraction:float=space.cast_motion(query)[0]
	query.transform.origin+=motion;query.motion=Vector3.ZERO
	var overlaps:=space.intersect_shape(query,1)
	if fraction<.99 or not overlaps.is_empty():
		actor.travel_speed=0;blocked+=1
		blocked_age+=delta
		if blocked_age>=4 and retry_age<=0:
			retry_age=4.0
			detour=Route.find(actor,goal,collision_excluded)
		if blocked==1:
			for hit in overlaps:print("GOODS_BLOCKER ",hit.collider.get_path()," parent=",hit.collider.get_parent().name," at=",actor.global_position," goal=",goal)
		return false
	blocked_age=0.0
	actor.global_position+=motion
	var floor_y:=Route.support(actor,actor.global_position)
	if is_finite(floor_y):actor.global_position.y=floor_y
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*2.5)
	actor.travel_speed=.95;collider.force_update_transform();return true

func contact()->void:
	if delivered>=goods.size() or phase not in ["lift","inside","lower"]:return
	var item:Node3D=goods[delivered]
	hand_error=0
	for side in ["l","r"]:
		var target:=item.global_position+Vector3.UP*.14+actor.global_basis.x*(.18 if side=="l" else -.18)
		if phase=="lift" and progress<.2:target=actor.palm_world(side).lerp(target,smoothstep(0,.2,progress))
		actor.solve_hand_contact(side,target);actor.set_grip(side,.5)
		hand_error=maxf(hand_error,actor.palm_world(side).distance_to(target))

func place(item:Node3D,parent:Node3D,at:Vector3)->void:
	if item.get_parent()!=parent:item.reparent(parent)
	item.position=at;item.rotation=Vector3.ZERO
	item.get_node("ConsignmentBody").collision_layer=1 if parent==institution else 0

func export_state()->Dictionary:
	return {"phase":phase,"progress":progress,"delivered":delivered,"day":day,"waypoint":waypoint,"position":[actor.position.x,actor.position.y,actor.position.z]}

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
		if point.is_finite():actor.position=point
	for i in goods.size():
		if i<delivered:place(goods[i],institution,Vector3(.53,1.15,1+i*.55))
		elif i==delivered and phase in ["inside","lower"]:place(goods[i],actor,Vector3(0,.91,.34))
		else:place(goods[i],cart,Vector3(-.5+i*.5,1.185,3.75))
