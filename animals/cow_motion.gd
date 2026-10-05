extends Node
## Four independent stance targets, neck/head contact and a finite care loop.
var yard:Node3D
var cow:Node3D
var rig:Skeleton3D
var rest:Dictionary={}
var body_rest_position:=Vector3.ZERO
var feet:Dictionary={}
var planted:Dictionary={}
var phase:=0.0
var time:=0.0
var state:="idle"
var stage:=0
var head_weight:=0.0
var speed:=.34
var contact_error:=0.0
var maximum_stance_error:=0.0
var contact_seconds:=0.0
var elapsed:=0.0
var ground_override:=NAN
var enabled:=true
const ORDER=["Hind.L","Front.L","Hind.R","Front.R"]
const OFFSETS={"Hind.L":0.0,"Front.L":.25,"Hind.R":.5,"Front.R":.75}
func configure(owner_yard:Node3D,animal:Node3D)->void:yard=owner_yard;cow=animal
func _ready()->void:
	process_priority=100
	rig=cow.find_children("*","Skeleton3D",true,false)[0]
	var anim:=cow.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim:anim.stop()
	for i in rig.get_bone_count():rest[i]=rig.get_bone_pose_rotation(i)
	body_rest_position=rig.get_bone_pose_position(rig.find_bone("Body"))
	for tag in ORDER:
		var end:="Back" if tag.begins_with("Hind") else "Front"
		# Export calls the hind limb Hind, unlike the horse rig.
		end="Hind" if tag.begins_with("Hind") else "Front"
		var side: String = tag.get_slice(".",1)
		feet[tag]=[rig.find_bone(end+"Upper."+side),rig.find_bone(end+"Lower."+side),rig.find_bone(end+"Foot."+side)]
func _physics_process(delta:float)->void:
	if enabled:tick(delta)
func floor_y(at:Vector3)->float:
	return ground_override if is_finite(ground_override) else yard.layout.height(at.x,at.z)
func mouth_world()->Vector3:
	var bone:=rig.find_bone("Head")
	return rig.to_global(rig.get_bone_global_pose(bone)*rig.get_bone_global_rest(bone).affine_inverse()*Vector3(0,.93,-1.735))
func hoof_world(tag:String)->Vector3:
	var bone:int=feet[tag][2]
	return rig.to_global(rig.get_bone_global_pose(bone).origin)-Vector3.UP*.076
func _rotate(bone:int,from:Vector3,to:Vector3)->void:
	if minf(from.length_squared(),to.length_squared())<.0000001:return
	var current:=rig.get_bone_global_pose(bone)
	var desired:=Basis(Quaternion(from.normalized(),to.normalized()))*current.basis
	var parent:=rig.get_bone_parent(bone)
	if parent>=0:desired=rig.get_bone_global_pose(parent).basis.inverse()*desired
	rig.set_bone_pose_rotation(bone,desired.orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
func _solve_leg(bones:Array,target_world:Vector3)->void:
	var target:=rig.to_local(target_world)
	var hip:=rig.get_bone_global_pose(bones[0]).origin
	var knee:=rig.get_bone_global_pose(bones[1]).origin
	var ankle:=rig.get_bone_global_pose(bones[2]).origin
	var upper:=hip.distance_to(knee);var lower:=knee.distance_to(ankle)
	var direction:=(target-hip).normalized();var distance:=clampf(hip.distance_to(target),absf(upper-lower)+.001,upper+lower-.001)
	target=hip+direction*distance
	var along:=(upper*upper-lower*lower+distance*distance)/(2*distance)
	var height:=sqrt(maxf(0,upper*upper-along*along))
	var axis:=Vector3.BACK if str(rig.get_bone_name(bones[0])).begins_with("Hind") else Vector3.FORWARD
	var pole:=axis-direction*direction.dot(axis)
	if pole.length_squared()<.001:pole=Vector3.RIGHT
	var desired_knee:=hip+direction*along+pole.normalized()*height
	_rotate(bones[0],knee-hip,desired_knee-hip)
	knee=rig.get_bone_global_pose(bones[1]).origin;ankle=rig.get_bone_global_pose(bones[2]).origin
	_rotate(bones[1],ankle-knee,target-knee)
	# Foot remains level instead of inheriting the calf angle into the hoof.
	var desired:=rig.get_bone_global_rest(bones[2]).basis
	var parent:=rig.get_bone_parent(bones[2]);desired=rig.get_bone_global_pose(parent).basis.inverse()*desired
	rig.set_bone_pose_rotation(bones[2],desired.orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
func _head_contact(target:Vector3)->void:
	var start:=mouth_world();var goal:=start.lerp(target,head_weight)
	for iteration in 60:
		for name in ["Head","Neck"]:
			var bone:=rig.find_bone(name);var pivot:=rig.to_global(rig.get_bone_global_pose(bone).origin)
			var from:=rig.global_basis.inverse()*(mouth_world()-pivot)
			var to:=rig.global_basis.inverse()*(goal-pivot)
			_rotate(bone,from,to)
		if mouth_world().distance_to(goal)<.001:break
	contact_error=mouth_world().distance_to(target)
func _destination()->Vector3:
	var p:=Vector3.ZERO
	match stage:
		1:p=Vector3(0,0,1.8)
		2:p=Vector3(1.1,0,-.12)
		3:p=Vector3(-1.1,0,-.25)
	p.y=yard.ground(p.x,p.z)
	return yard.to_global(p)
func tick(delta:float)->void:
	time+=delta;elapsed+=delta
	for bone in rest:rig.set_bone_pose_rotation(bone,rest[bone])
	var previous_yaw:=cow.rotation.y
	var previous_position:=cow.global_position
	var moving:=state=="walk"
	rig.set_bone_pose_position(rig.find_bone("Body"),body_rest_position+Vector3.DOWN*(.06 if moving else .02))
	if moving:
		var target:=_destination();var offset:=target-cow.global_position;offset.y=0
		if offset.length()<.035:
			state=["idle","graze","feed","drink"][stage];time=0;moving=false;planted.clear()
		else:
			var yaw:=atan2(-offset.x,-offset.z)
			cow.global_rotation.y=rotate_toward(cow.global_rotation.y,yaw,delta*.25)
			# Turn before translating; prevent sideways sliding at the destination.
			if absf(angle_difference(cow.global_rotation.y,yaw))<.18:
				var motion:=offset.normalized()*minf(offset.length(),speed*delta)
				var body:AnimatableBody3D=cow.get_node("CowBody")
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=body.get_child(0).shape;query.transform=body.get_child(0).global_transform;query.motion=motion;query.exclude=[body.get_rid()];query.collision_mask=1
				if cow.get_world_3d().direct_space_state.cast_motion(query)[0]>.99:cow.global_position+=motion
			cow.global_position.y=floor_y(cow.global_position)
	else:
		var facing:=PI if state=="graze" else 0.0
		cow.rotation.y=rotate_toward(cow.rotation.y,facing,delta*.25)
		if absf(angle_difference(cow.rotation.y,facing))>.08:time=0
		var duration:=8.0 if state=="graze" else (5.0 if state in ["feed","drink"] else 4.0)
		if time>duration:
			if state=="feed" and contact_seconds>1:yard.feed_portions=maxi(0,yard.feed_portions-1);yard.refresh_supplies()
			stage=(stage+1)%4;state="walk";time=0;contact_seconds=0;planted.clear()
	# Solve all four feet every step. A stance hoof stays at its world position.
	var turning:=absf(angle_difference(previous_yaw,cow.rotation.y))>.0001
	var stepping:=moving or turning
	var translating:=cow.global_position.distance_to(previous_position)>.0001
	# Small idle weight shifts are solved before the hooves, preserving contact.
	var weight_shift:=Vector3(sin(elapsed*.43)*.004,sin(elapsed*1.65)*.0015,0) if not stepping else Vector3.ZERO
	rig.set_bone_pose_position(rig.find_bone("Body"),body_rest_position+Vector3.DOWN*(.07 if stepping else .02)+weight_shift)
	phase=fmod(phase+delta/(1.6 if turning else 2.4),1)
	for tag in ORDER:
		var local_phase:=fmod(phase+OFFSETS[tag],1)
		var bone:int=feet[tag][2]
		var origin:=rig.to_global(rig.get_bone_global_rest(bone).origin)
		var target:=origin
		var stance_fraction:=.50 if turning else .66
		var stance:=not stepping or local_phase<stance_fraction
		if stance:
			if not planted.has(tag):planted[tag]=Vector3(origin.x,floor_y(origin)+.085,origin.z)+(-cow.global_basis.z*.20 if translating else Vector3.ZERO)
			target=planted[tag]
		else:
			planted.erase(tag)
			var swing:=(local_phase-stance_fraction)/(1-stance_fraction)
			target+=cow.global_basis*Vector3(0,0,lerpf(.16,-.16,swing))
			target.y=floor_y(target)+.085+sin(swing*PI)*.075
		_solve_leg(feet[tag],target)
		if stance:maximum_stance_error=maxf(maximum_stance_error,rig.to_global(rig.get_bone_global_pose(bone).origin).distance_to(target))
	var target:=mouth_world()
	var aligned:bool=absf(angle_difference(cow.rotation.y,PI if state=="graze" else 0.0))<.08
	var feeding:bool=state=="feed" and yard.feed_portions>0 and aligned
	var drinking:bool=state=="drink" and yard.water_liters>0 and aligned
	var grazing:=state=="graze" and aligned
	head_weight=move_toward(head_weight,1.0 if feeding or drinking or grazing else 0.0,delta*.55)
	if grazing:target=cow.to_global(Vector3(0,.075,-.93))
	if feeding:target=yard.fodder.global_position+Vector3.UP*.055*yard.fodder.scale.y
	if drinking:target=yard.water_surface.global_position+Vector3.UP*.008
	if head_weight>0:_head_contact(target)
	if feeding or grazing:
		var jaw:=rig.find_bone("Jaw")
		rig.set_bone_pose_rotation(jaw,rest[jaw]*Quaternion(Vector3.RIGHT,sin(elapsed*TAU*1.1)*.035*head_weight))
	if (feeding or drinking or grazing) and contact_error<.025 and head_weight>.999:
		contact_seconds+=delta
		if drinking:
			yard.water_liters=maxf(0,yard.water_liters-delta*.16);yard.refresh_supplies()
	# Offset ear flicks and occasional swishes avoid a constant metronome loop.
	for side in ["L","R"]:
		var ear:=rig.find_bone("Ear."+side)
		var ear_cycle:=fmod(elapsed+(2.8 if side=="R" else 0.0),9.7)
		var flick:=sin(ear_cycle*TAU/1.1)*sin(ear_cycle*PI/1.1)*.12 if ear_cycle<1.1 else 0.0
		rig.set_bone_pose_rotation(ear,rest[ear]*Quaternion(Vector3.UP,flick))
	var swish_cycle:=fmod(elapsed,12.3)
	var swish:=sin(swish_cycle*3.6)*sin(swish_cycle*PI/3.5)*.18 if swish_cycle<3.5 else 0.0
	var tail:=rig.find_bone("Tail");rig.set_bone_pose_rotation(tail,rest[tail]*Quaternion(Vector3.UP,swish))
	cow.get_node("CowBody").force_update_transform()
