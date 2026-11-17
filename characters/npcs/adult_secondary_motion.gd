extends RefCounted
## Cosmetic soft-tissue response for explicitly adult, clothed MPFB characters.
## Dedicated bones deform the complete body and its fitted garments together.

class ElasticState extends RefCounted:
	var offset := Vector3.ZERO
	var velocity := Vector3.ZERO
	func reset() -> void:
		offset=Vector3.ZERO;velocity=Vector3.ZERO
	func advance(delta: float, acceleration: Vector3, frequency: float, damping: float, limit: float) -> void:
		if delta<=0.0 or delta>.12:
			reset();return
		var steps:=maxi(1,ceili(delta*120.0));var step:=delta/float(steps)
		var omega:=TAU*frequency
		for tick in steps:
			velocity+=(-acceleration-offset*omega*omega-velocity*(2.0*damping*omega))*step
			offset+=velocity*step
			if offset.length()>limit:
				var direction:=offset.normalized();offset=direction*limit
				velocity-=direction*maxf(0.0,velocity.dot(direction))

var rig: Skeleton3D
var entries: Array[Dictionary] = []
var clothing_support := .72
var mass_scale := 1.0
var peak_displacement_m := 0.0
var ready_for_motion := false

func configure(actor: Node3D, skeleton: Skeleton3D, individual_mass_scale := 1.0, support := .72) -> void:
	entries.clear();rig=skeleton;ready_for_motion=false
	if not actor.get_meta("adult_character",false) or rig==null:return
	clothing_support=clampf(support,0,1);mass_scale=clampf(individual_mass_scale,.7,1.3)
	for side in ["l","r"]:
		var index:=rig.find_bone("breast_"+side)
		if index<0:continue
		var parent:=rig.get_bone_parent(index)
		if parent<0:continue
		entries.append({"bone":index,"parent":parent,"neutral":rig.get_bone_pose_position(index),"previous":Vector3.ZERO,"previous_velocity":Vector3.ZERO,"spring":ElasticState.new(),"asymmetry":.985 if side=="l" else 1.015})

func limit_m() -> float:
	# More support restrains motion; profile mass describes an individual body.
	return .008*mass_scale*(1.0-.45*clothing_support)

func frequency_hz() -> float:
	return (3.3/sqrt(mass_scale))*(1.0+.30*clothing_support)

func update(delta: float) -> void:
	if entries.is_empty() or not is_instance_valid(rig):return
	rig.force_update_all_bone_transforms()
	for entry in entries:
		var parent: Transform3D=rig.get_bone_global_pose(entry.parent)
		var frame: Basis=rig.global_basis*parent.basis
		var anchor:=rig.to_global(parent*Vector3(entry.neutral))
		var spring: ElasticState=entry.spring
		var jump: float=anchor.distance_to(entry.previous)
		if not ready_for_motion or delta<=0.0 or delta>.12 or jump>.6:
			spring.reset();entry.previous_velocity=Vector3.ZERO
		else:
			var velocity: Vector3=(anchor-Vector3(entry.previous))/delta
			var acceleration: Vector3=((velocity-Vector3(entry.previous_velocity))/delta).limit_length(24.0)
			entry.previous_velocity=velocity
			var local_force: Vector3=frame.inverse()*acceleration*(.60-.35*clothing_support)
			var unit_scale:=maxf(.001,frame.get_scale().length()/sqrt(3.0))
			spring.advance(delta,local_force,frequency_hz()*float(entry.asymmetry),.62+.25*clothing_support,limit_m()/unit_scale)
		entry.previous=anchor
		rig.set_bone_pose_position(entry.bone,Vector3(entry.neutral)+spring.offset)
		peak_displacement_m=maxf(peak_displacement_m,(frame*spring.offset).length())
	ready_for_motion=delta>0.0 and delta<=.12

func reset() -> void:
	ready_for_motion=false;peak_displacement_m=0.0
	for entry in entries:
		entry.spring.reset();entry.previous_velocity=Vector3.ZERO
		if is_instance_valid(rig):rig.set_bone_pose_position(entry.bone,entry.neutral)
