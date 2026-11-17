extends RefCounted
## Explicitly adult, authored four-bone tissue response. No synthetic gait wave.
## Complete body and garments share these bones and their fitted skin weights.
const Dynamics = preload("res://characters/npcs/adult_secondary_motion.gd")
var rig:Skeleton3D
var entries:Array[Dictionary]=[]
var ready_for_motion:=false
var peak_by_family:Dictionary={"breast":0.0,"glute":0.0}

func configure(actor:Node3D,skeleton:Skeleton3D,breast_mass:float=1.0,rear_mass:float=1.0) -> void:
	entries.clear();rig=skeleton;ready_for_motion=false
	if not bool(actor.get_meta("adult_character",false)) or rig==null:return
	for family in ["breast","glute"]:
		var mass:float=clampf(breast_mass if family=="breast" else rear_mass,.7,1.3)
		var support:float=.75 if family=="breast" else .60
		for side in ["l","r"]:
			var bone:int=rig.find_bone(family+"_"+side)
			if bone<0:entries.clear();return
			var parent:int=rig.get_bone_parent(bone)
			if parent<0:entries.clear();return
			entries.append({"bone":bone,"parent":parent,"rest":rig.get_bone_rest(bone),
				"neutral":rig.get_bone_pose_position(bone),"previous":Vector3.ZERO,
				"previous_velocity":Vector3.ZERO,"spring":Dynamics.ElasticState.new(),
				"family":family,"mass":mass,"support":support,
				"asymmetry":.985 if side=="l" else 1.015})

func limit_m(entry:Dictionary) -> float:
	return (.008 if entry.family=="breast" else .006)*float(entry.mass)*(1.0-.45*float(entry.support))

func update(delta:float) -> void:
	if entries.is_empty() or not is_instance_valid(rig):return
	rig.force_update_all_bone_transforms()
	var parents:Dictionary={}
	for entry:Dictionary in entries:
		if not parents.has(entry.parent):parents[entry.parent]=rig.get_bone_global_pose(entry.parent)
	for entry:Dictionary in entries:
		var parent:Transform3D=parents[entry.parent]
		var rest:Transform3D=entry.rest
		var frame:Basis=rig.global_basis*parent.basis*rest.basis
		var anchor:Vector3=rig.to_global(parent*(rest*Vector3(entry.neutral)))
		var spring:Dynamics.ElasticState=entry.spring
		if not ready_for_motion or delta<=0.0 or delta>.12 or anchor.distance_to(entry.previous)>.6:
			spring.reset();entry.previous_velocity=Vector3.ZERO
		else:
			var velocity:Vector3=(anchor-Vector3(entry.previous))/delta
			var acceleration:Vector3=((velocity-Vector3(entry.previous_velocity))/delta).limit_length(24.0)
			entry.previous_velocity=velocity
			var support:float=entry.support
			var force:Vector3=frame.inverse()*acceleration*(.60-.35*support)
			var scale:float=maxf(.001,frame.get_scale().length()/sqrt(3.0))
			var frequency:float=(3.3 if entry.family=="breast" else 3.0)/sqrt(float(entry.mass))*(1.0+.30*support)
			spring.advance(delta,force,frequency*float(entry.asymmetry),.62+.25*support,limit_m(entry)/scale)
		entry.previous=anchor
		rig.set_bone_pose_position(entry.bone,Vector3(entry.neutral)+spring.offset)
		var displacement:float=(frame*spring.offset).length()
		peak_by_family[entry.family]=maxf(float(peak_by_family[entry.family]),displacement)
	ready_for_motion=delta>0.0 and delta<=.12
	rig.force_update_all_bone_transforms()

func reset() -> void:
	ready_for_motion=false;peak_by_family={"breast":0.0,"glute":0.0}
	for entry:Dictionary in entries:
		entry.spring.reset();entry.previous_velocity=Vector3.ZERO
		if is_instance_valid(rig):rig.set_bone_pose_position(entry.bone,entry.neutral)
