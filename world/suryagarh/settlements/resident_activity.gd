extends Node
## A resident has a real destination, swept body, personal work tree and prop contact.
var actor: Node3D
var job := "social"
var home := Vector2.ZERO
var workplace := Vector2.ZERO
var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
var clock: Node
var viewer: Node3D
var elapsed := 0.0
var age := 0.0
var prop: Node3D
var hand_error := 0.0
var trips := 0
var visits: Dictionary={}
var ankle_offsets: Dictionary={}
var seated := false
var returning := false
var seeds_sown := 0
var previous_seed_cycle := -1
var seed_bowl: Node3D
var commute: Array[Vector2]=[]
var route_goal := 0
var route_direction := 1
var social_role := "labourer"
const Roles=preload("res://world/suryagarh/settlements/resident_roles.gd")
var animal:Node3D

func _ready() -> void:
	clock=get_tree().get_first_node_in_group("game_time_system")
	if clock==null:clock=get_tree().root.find_child("GameTimeSystem",true,false)
	actor.set_process(false)
	for side in ["l","r"]:ankle_offsets[side]=actor.foot_plant.ankle_height[side]-actor.global_position.y
	_work_tree.call_deferred()
	if job in ["carry","hoe","well","groom"]:_prop()
	elif job=="sow":
		seed_bowl=load("res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf").instantiate()
		seed_bowl.name="SeedBasket";seed_bowl.scale=Vector3.ONE*.18;seed_bowl.position=Vector3(.18,.90,.23);actor.add_child(seed_bowl)

func _work_tree() -> void:
	var clip:=Animation.new();clip.length=4.5;clip.loop_mode=Animation.LOOP_LINEAR
	for bone in ["spine_02","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r"]:
		var path:=NodePath(str(actor.get_path_to(actor._skeleton))+":"+bone)
		var track:=clip.add_track(Animation.TYPE_ROTATION_3D);clip.track_set_path(track,path)
		for i in 33:
			var t:=float(i)/32;var angle:=0.0
			if bone=="spine_02":angle=.10+.12*(.5-.5*cos(t*TAU)) if job in ["hoe","sow"] else .025*sin(t*TAU)
			elif bone=="head":angle=.04*sin(t*TAU)
			elif bone.begins_with("upperarm"):angle=-.24-.12*sin(t*TAU) if job in ["hoe","sow","well"] else -.08-.08*sin(t*TAU)
			elif bone.begins_with("lowerarm"):angle=-.4-.10*sin(t*TAU)
			clip.rotation_track_insert_key(track,t*clip.length,actor._base_rotations[bone]*Quaternion(actor._pitch_axes[bone],angle))
	actor.animation_player.get_animation_library("").add_animation("daily_activity",clip)
	var graph:AnimationNodeBlendTree=actor.animation_tree.tree_root
	var work:=AnimationNodeAnimation.new();work.animation=&"daily_activity";graph.add_node("daily_activity",work)
	var blend:=AnimationNodeBlend2.new();blend.filter_enabled=true
	for track in clip.get_track_count():blend.set_filter_path(clip.track_get_path(track),true)
	graph.add_node("daily_work",blend)
	# Preserve the existing combat branch and its reaction ownership.
	var parent_node: String="combat" if graph.has_node("combat") else "output"
	var previous: String="turning"
	graph.disconnect_node(parent_node,0);graph.connect_node("daily_work",0,previous)
	graph.connect_node("daily_work",1,"daily_activity");graph.connect_node(parent_node,0,"daily_work")
	actor.animation_tree.set("parameters/daily_work/blend_amount",0.0)

func _prop() -> void:
	if job=="carry":
		prop=load("res://assets/props/polyhaven/wooden_crate_02/wooden_crate_02_1k.gltf").instantiate()
		prop.scale=Vector3.ONE*.38
	elif job=="well":
		prop=load("res://assets/props/polyhaven/wooden_bucket_02/wooden_bucket_02_1k.gltf").instantiate();prop.scale=Vector3.ONE*.45
	elif job=="groom":
		prop=MeshInstance3D.new();var brush:=BoxMesh.new();brush.size=Vector3(.10,.055,.16);prop.mesh=brush
		var wood:=StandardMaterial3D.new();wood.albedo_color=Color(.32,.22,.12);prop.material_override=wood
	else:
		prop=Node3D.new()
		var shaft:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.016;cylinder.bottom_radius=.016;cylinder.height=1.70;shaft.mesh=cylinder
		var wood:=StandardMaterial3D.new();wood.albedo_color=Color(.25,.16,.08);shaft.material_override=wood;prop.add_child(shaft)
		var blade:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.16,.025,.22);blade.mesh=box;blade.position=Vector3(0,-.84,.06)
		var iron:=StandardMaterial3D.new();iron.albedo_color=Color(.13,.12,.10);blade.material_override=iron;prop.add_child(blade)
	prop.name="ActivityProp";actor.add_child(prop)

func _physics_process(delta:float) -> void:
	age+=delta;elapsed+=delta
	var distance: float=actor.global_position.distance_squared_to(viewer.global_position) if is_instance_valid(viewer) else 0.0
	var cadence:=.5 if distance>22500 else (.1 if distance>4900 else 0.0)
	if age<cadence:return
	var step:=minf(age,.5);age=0.0;tick(step,distance<22500)

func tick(delta:float, animate:=true) -> void:
	if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false):return
	var working:bool=(clock==null or (clock.current_hour>=6 and clock.current_hour<18)) and Roles.permits(social_role,job)
	if job=="groom":working=working and is_instance_valid(animal) and animal.rider==null and Vector2(animal.global_position.x,animal.global_position.z).distance_to(workplace)<3.0
	var goal:=workplace if working else home
	if job=="carry" and working:
		goal=home if returning else workplace
	var outward:bool=working and (job!="carry" or not returning)
	if commute.size()>1:
		var expected:=1 if outward else -1
		if route_direction!=expected:
			route_goal=clampi(route_goal+expected,0,commute.size()-1);route_direction=expected
		goal=commute[route_goal]
	var offset:=Vector3(goal.x,layout.height(goal.x,goal.y),goal.y)-actor.global_position;offset.y=0
	var moving:=offset.length()>.08
	actor.set_meta("daily_activity",job if working and not moving else ("going_to_"+job if working else "going_home"))
	visits[str(actor.get_meta("daily_activity"))]=true
	actor.animation_tree.set("parameters/daily_work/blend_amount",0.0 if moving or not working else 1.0)
	if moving:
		if seated:
			actor.global_position.y=layout.height(actor.global_position.x,actor.global_position.z)
			var body_shape:CollisionShape3D=actor.body_collider.get_node("BodyShape")
			body_shape.shape.height=1.6;body_shape.position.y=.8;actor.body_collider.force_update_transform()
		var motion:=offset.normalized()*minf(offset.length(),delta*.95)
		var shape:CollisionShape3D=actor.body_collider.get_node("BodyShape")
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform
		query.transform.origin.y+=.03;query.motion=motion;query.collision_mask=1;query.exclude=[actor.body_collider.get_rid()]
		var safe:=actor.get_world_3d().direct_space_state.cast_motion(query)
		if safe[0]>.99:
			actor.global_position+=motion;actor.global_position.y=layout.height(actor.global_position.x,actor.global_position.z)
			actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*2.5);actor.travel_speed=.95
		else:actor.travel_speed=0.0;actor.set_meta("daily_activity","waiting_for_clear_path")
	else:
		actor.travel_speed=0.0
		var endpoint:bool=commute.is_empty() or (route_goal==commute.size()-1 if outward else route_goal==0)
		if not endpoint:route_goal+=route_direction;moving=true
		elif job=="carry" and working and fposmod(elapsed,12.0)<delta:returning=not returning;trips+=1
	for side in ["l","r"]:actor.foot_plant.ankle_height[side]=layout.height(actor.global_position.x,actor.global_position.z)+ankle_offsets[side]
	if animate:
		actor._set_animation(&"walk" if actor.travel_speed>0 else &"idle",delta)
		if not moving and working and seated:_sit()
		if working:_hands(moving)
		if actor.drape!=null and seated and not moving:actor.drape.update()
	actor.body_collider.force_update_transform()

func _sit() -> void:
	var rig:Skeleton3D=actor._skeleton
	actor.global_position.y=layout.height(actor.global_position.x,actor.global_position.z)-.28
	for side in ["l","r"]:
		for pair in [["thigh_",-1.25],["calf_",1.5],["foot_",-.25]]:
			var label:String=pair[0]+side;rig.set_bone_pose_rotation(rig.find_bone(label),actor._base_rotations[label]*Quaternion(actor._pitch_axes[label],pair[1]))
		var ankle:Vector3=actor.to_global(Vector3(.17 if side=="l" else -.17,.07,.40));ankle.y=layout.height(ankle.x,ankle.z)+ankle_offsets[side]
		actor.foot_plant._solve(actor.foot_plant.legs[side],rig.to_local(ankle))
	var collision:CollisionShape3D=actor.body_collider.get_node("BodyShape");collision.shape.height=1.10;collision.position.y=.83

func _hands(moving:bool) -> void:
	hand_error=0.0
	if prop!=null:
		prop.position=Vector3(0,.88,.36)
		if job=="hoe" and not moving:
			prop.position=Vector3(0,.87+.025*sin(elapsed*TAU/4.5),.27);prop.rotation.x=.15*sin(elapsed*TAU/4.5)
		elif job=="well" and not moving:prop.position.y=.83+.10*sin(elapsed*TAU/4.5)
		elif job=="groom" and not moving:prop.position=Vector3(0,1.15+.05*sin(elapsed*TAU/3),.47)
		for side in ["l","r"]:
			var grip:=Vector3(.20 if side=="l" else -.20,.12,0)
			if job=="hoe":grip=Vector3(0,.34 if side=="l" else .18,0)
			if job=="well":grip=Vector3(.12 if side=="l" else -.12,.25,0)
			if job=="groom" and side=="l":continue
			var target:Vector3=prop.to_global(grip);actor.solve_hand_contact(side,target);actor.set_grip(side,.5)
			hand_error=maxf(hand_error,actor.palm_world(side).distance_to(target))
	elif job=="sow" and not moving:
		actor.solve_hand_contact("l",actor.to_global(Vector3(.18,.92,.22)))
		actor.solve_hand_contact("r",actor.to_global(Vector3(-.12-.10*sin(elapsed*TAU/4.5),.76,.36+.10*cos(elapsed*TAU/4.5))))
		var cycle:=int(elapsed/4.5)
		if cycle!=previous_seed_cycle:
			previous_seed_cycle=cycle;seeds_sown+=1;actor.set_meta("seeds_sown",seeds_sown)
	elif job in ["social","inspect"] and not moving:
		actor.solve_hand_contact("r",actor.to_global(Vector3(-.23,.70+.12*sin(elapsed*TAU/5),.25)))

func export_state()->Dictionary:
	var p:Vector3=actor.global_position
	return {"elapsed":elapsed,"position":[p.x,p.y,p.z],"returning":returning,"trips":trips,"seeds_sown":seeds_sown,"route_goal":route_goal,"route_direction":route_direction}

func restore_state(state:Dictionary)->void:
	if state.is_empty():return
	elapsed=maxf(0,float(state.get("elapsed",elapsed)));returning=bool(state.get("returning",false));trips=maxi(0,int(state.get("trips",0)))
	seeds_sown=maxi(0,int(state.get("seeds_sown",0)))
	route_goal=clampi(int(state.get("route_goal",route_goal)),0,maxi(0,commute.size()-1));route_direction=1 if int(state.get("route_direction",1))>=0 else -1
	var p:Variant=state.get("position")
	if p is Array and p.size()==3:
		var at:=Vector3(float(p[0]),float(p[1]),float(p[2]))
		if at.is_finite():actor.global_position=at
