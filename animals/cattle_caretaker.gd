extends Node3D
var yard:Node3D
var actor:Node3D
var bundle:Node3D
var stage:="wait"
var elapsed:=0.0
var contact_max:=0.0
var last_contact_error:=0.0
var release_targets:Dictionary={}
var transfers:=0
var enabled:=true
var ankle_offsets:Dictionary={}
var home:=Vector3(1.85,0,1.35)
var approach:=Vector3(1.64,0,-1.36)
var lean_bone:=-1
var lean_rest:=Quaternion.IDENTITY
var lean_axis:=Vector3.RIGHT
func _ready()->void:
	actor=preload("res://characters/npcs/households/household_npc_actor.gd").new();actor.name="NorthLaneCattleKeeper"
	actor.movement_enabled=false;actor.household_job="CattleKeeper"
	actor.add_child(preload("res://characters/npcs/street_residents/landowner.glb").instantiate())
	actor.position=home;actor.position.y=yard.ground(home.x,home.z);add_child(actor);actor.set_process(false)
	lean_bone=actor._skeleton.find_bone("spine_01");lean_rest=actor._skeleton.get_bone_pose_rotation(lean_bone);lean_axis=actor._skeleton.get_bone_global_rest(lean_bone).basis.inverse()*Vector3.RIGHT
	actor.set_meta("owner_house",str(yard.house.get_path()));actor.add_to_group("cattle_caretakers")
	for side in ["l","r"]:ankle_offsets[side]=actor.foot_plant.ankle_height[side]-actor.global_position.y
	for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not ("cotton upper" in mesh.name.to_lower() or "shawl" in mesh.name.to_lower()):continue
		var cloth:=ShaderMaterial.new();cloth.shader=preload("res://characters/npcs/households/household_cloth.gdshader")
		cloth.set_shader_parameter("cloth_color",Color(.33,.29,.21) if "upper" in mesh.name.to_lower() else Color(.42,.32,.16));mesh.material_override=cloth
	bundle=Node3D.new();bundle.name="CarriedFodder";add_child(bundle)
	var straw:=CylinderMesh.new();straw.top_radius=.003;straw.bottom_radius=.003;straw.height=.37;straw.radial_segments=5
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.42,.36,.16);material.roughness=.95;straw.material=material
	var fibres:=MultiMesh.new();fibres.transform_format=MultiMesh.TRANSFORM_3D;fibres.mesh=straw;fibres.instance_count=32
	for i in 32:
		var angle:=i*2.4;var radius:=.037*sqrt(float(i+1)/32)
		fibres.set_instance_transform(i,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(0,sin(angle)*radius,cos(angle)*radius)))
	var visual:=MultiMeshInstance3D.new();visual.multimesh=fibres;bundle.add_child(visual);bundle.hide()
func _physics_process(delta:float)->void:
	if enabled:tick(delta)
func _walk(target:Vector3,delta:float)->bool:
	var point:=yard.to_global(target);point.y=yard.layout.height(point.x,point.z)
	var offset:=point-actor.global_position;offset.y=0
	if offset.length()<.035:return true
	var amount:=minf(offset.length(),delta*.6)
	var desired:=atan2(offset.x,offset.z);actor.global_rotation.y=rotate_toward(actor.global_rotation.y,desired,delta*2.5)
	actor.global_position+=offset.normalized()*amount;actor.global_position.y=yard.layout.height(actor.global_position.x,actor.global_position.z)
	actor.travel_speed=amount/delta
	for side in ["l","r"]:actor.foot_plant.ankle_height[side]=actor.global_position.y+ankle_offsets[side]
	actor._set_animation(&"walk",delta);actor.get_node("BodyCollider").force_update_transform();return false
func _lean(amount:float)->void:
	actor._skeleton.set_bone_pose_rotation(lean_bone,lean_rest*Quaternion(lean_axis.normalized(),amount))
	actor._skeleton.force_update_all_bone_transforms()
func tick(delta:float)->void:
	if actor.get_meta("dead",false):bundle.hide();return
	elapsed+=delta
	_lean(0)
	if stage=="wait":
		actor.travel_speed=0;actor._set_animation(&"idle",delta);bundle.hide()
		if elapsed>4 and yard.fodder_stock>0 and yard.feed_portions<3:stage="carry";elapsed=0;bundle.show()
	elif stage=="carry":
		if _walk(approach,delta):stage="offer";elapsed=0;actor.foot_plant.clear()
	elif stage=="offer":
		actor.travel_speed=0;actor._set_animation(&"idle",delta)
		var focus: Vector3 = yard.fodder.global_position-actor.global_position
		actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(focus.x,focus.z),delta*2)
		var lower:=smoothstep(0,1,minf(elapsed/1.3,1))*.40
		actor.position.y=yard.ground(approach.x,approach.z)-lower
		_lean(smoothstep(0,1,minf(elapsed/1.3,1))*.65)
		for side in ["l","r"]:
			var target:=actor.global_position;var foot:int=actor.foot_plant.legs[side][2]
			target=actor._skeleton.to_global(actor._skeleton.get_bone_global_rest(foot).origin)
			target.y=yard.global_position.y+yard.ground(approach.x,approach.z)+ankle_offsets[side]
			actor.foot_plant._solve(actor.foot_plant.legs[side],actor._skeleton.to_local(target))
		if elapsed>3.5 and last_contact_error<.025:
			if yard.fodder_stock>0 and yard.feed_portions<3:yard.fodder_stock-=1;yard.feed_portions+=1;yard.refresh_supplies();transfers+=1
			for side in ["l","r"]:release_targets[side]=bundle.to_global(Vector3(.145 if side=="l" else -.145,0,0))
			stage="rise";elapsed=0;bundle.hide()
	elif stage=="rise":
		actor.travel_speed=0;actor._set_animation(&"idle",delta)
		actor.position.y=yard.ground(approach.x,approach.z)-.40*(1-smoothstep(0,1,minf(elapsed,1)))
		_lean(.65*(1-smoothstep(0,1,minf(elapsed,1))))
		for side in ["l","r"]:
			var foot:int=actor.foot_plant.legs[side][2]
			var sole:Vector3=actor._skeleton.to_global(actor._skeleton.get_bone_global_rest(foot).origin)
			sole.y=yard.global_position.y+yard.ground(approach.x,approach.z)+ankle_offsets[side]
			actor.foot_plant._solve(actor.foot_plant.legs[side],actor._skeleton.to_local(sole))
			var target:Vector3=release_targets[side].lerp(actor.palm_world(side),smoothstep(0,1,minf(elapsed/.8,1)))
			actor.solve_hand_contact(side,target);actor.set_grip(side,.5*(1-minf(elapsed/.8,1)))
		if elapsed>1:stage="return";elapsed=0
	elif stage=="return":
		if _walk(home,delta):stage="wait";elapsed=0
	if stage in ["carry","offer"]:
		var carried:=actor.to_global(Vector3(0,1.0,.30))
		var placed: Vector3 = yard.fodder.global_position+Vector3.UP*.13
		var mix_amount:=smoothstep(0,1,minf(elapsed/1.7,1)) if stage=="offer" else 0.0
		bundle.global_position=carried.lerp(placed,mix_amount);bundle.global_basis=actor.global_basis
		last_contact_error=0
		for side in ["l","r"]:
			var target:=bundle.to_global(Vector3(.145 if side=="l" else -.145,0,0))
			actor.solve_hand_contact(side,target);actor.set_grip(side,.5)
			last_contact_error=maxf(last_contact_error,actor.palm_world(side).distance_to(target))
			if stage=="offer" and elapsed>3:contact_max=maxf(contact_max,last_contact_error)
