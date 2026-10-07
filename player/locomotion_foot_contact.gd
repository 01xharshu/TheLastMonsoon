extends Node
## Pin a low, rearward-moving stance foot; raycast only on a new contact.
var visual: Node3D
var actor: CharacterBody3D
var combat: Node
var visual_root: Node3D
var stance: Node
var solver:=preload("res://characters/npcs/british/british_foot_plant.gd").new()
var previous: Dictionary={}
var contacts: Dictionary={}
var sound_armed: Dictionary={"l":true,"r":true}
var ankle_lift:=.07
var sole_points: Dictionary={"l":PackedVector3Array(),"r":PackedVector3Array()}
var last_root:=Vector3.ZERO
var last_yaw:=0.0
var contact_error:=0.0
var contact_samples:=0
func _ready() -> void:
	visual=get_parent();actor=visual.actor;process_priority=80
	combat=actor.get_node("CombatInput")
	visual_root=actor.get_node("VisualRoot")
	stance=actor.get_node("StealthStance")
	solver.configure(visual.skeleton)
	_cache_soles()
	last_root=actor.global_position;last_yaw=visual_root.global_rotation.y
func _process(delta: float) -> void:
	var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
	var yaw: float=visual_root.global_rotation.y
	var allowed: bool=actor.is_on_floor() and not actor.is_swimming and not actor.get_meta("climbing",false) and not actor.get_meta("paired_combat",false) and not actor.has_meta("mounted_vehicle") and actor.get_meta("detention_action","")=="" and actor.get_meta("rest_action","")=="" and not stance.is_low()
	var can_plant: bool=speed>.25 and combat.kick_time<0 and combat.dodge_time<0
	var discontinuity: bool=last_root.distance_to(actor.global_position)>1 or absf(angle_difference(last_yaw,yaw))>.12
	if not allowed or not can_plant or discontinuity:
		contacts.clear();previous.clear()
	last_root=actor.global_position;last_yaw=yaw
	actor.set_meta("audio_contact_active",allowed and can_plant and not discontinuity)
	if not allowed:
		sound_armed={"l":true,"r":true}
		return
	var rig: Skeleton3D=visual.skeleton
	for side in ["l","r"]:
		if combat.kick_time>=0 and side=="r":continue
		var bones: Array=solver.legs[side]
		var ankle:=rig.to_global(rig.get_bone_global_pose(bones[2]).origin)
		var relative: Vector3=visual_root.to_local(ankle)
		var rearward: bool=previous.has(side) and relative.z<float(previous[side].z)-.0001
		previous[side]=relative
		var floor_height:=actor.global_position.y-.9
		var bottom: float=-ankle_lift
		if not sole_points[side].is_empty():
			bottom=INF
			var foot_basis: Basis=rig.global_basis*rig.get_bone_global_pose(bones[2]).basis
			for point in sole_points[side]:bottom=minf(bottom,(foot_basis*point).y)
		# Preserve the swing in X/Z while keeping its visible sole out of terrain.
		if ankle.y+bottom<floor_height+.008:
			var clearance:=Vector3(ankle.x,floor_height+.008-bottom,ankle.z)
			solver._solve(bones,rig.to_local(clearance))
			ankle=rig.to_global(rig.get_bone_global_pose(bones[2]).origin)
		if ankle.y+bottom>floor_height+.025:sound_armed[side]=true
		if not can_plant or discontinuity or not rearward or ankle.y+bottom>floor_height+.06:
			contacts.erase(side);continue
		var new_contact: bool=not contacts.has(side)
		if new_contact:
			var query:=PhysicsRayQueryParameters3D.create(ankle+Vector3.UP*.2,ankle-Vector3.UP*.3,1)
			query.exclude=[actor.get_rid()]
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.normal.y<.7:continue
			contacts[side]=Vector3(ankle.x,hit.position.y,ankle.z)
		var target: Vector3=contacts[side]
		target.y+=.008-bottom
		var hip:=rig.to_global(rig.get_bone_global_pose(bones[0]).origin)
		var knee:=rig.to_global(rig.get_bone_global_pose(bones[1]).origin)
		var reach:=hip.distance_to(knee)+knee.distance_to(ankle)-.004
		if hip.distance_to(target)>reach:
			contacts.erase(side);continue
		solver._solve(bones,rig.to_local(target))
		if new_contact and sound_armed[side]:
			WorldAudio.foot_contact(actor,side,contacts[side])
			sound_armed[side]=false
		var solved:=rig.to_global(rig.get_bone_global_pose(bones[2]).origin)
		contact_error=maxf(contact_error,solved.distance_to(target));contact_samples+=1

func _cache_soles() -> void:
	# Read actual boot/outsole geometry once. Stance height follows heel/toe roll,
	# instead of a fixed ankle height that can push the visible boot into ground.
	var rig: Skeleton3D=visual.skeleton
	for mesh in visual.model.find_children("*Boot*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var side:="r" if str(mesh.name).ends_with("-1") else "l"
		var foot: Transform3D=rig.global_transform*rig.get_bone_global_pose(solver.legs[side][2])
		var palette: Array[Transform3D]=[]
		for bind in mesh.skin.get_bind_count():
			var index: int=rig.find_bone(mesh.skin.get_bind_name(bind)) if mesh.skin.get_bind_name(bind)!=&"" else mesh.skin.get_bind_bone(bind)
			palette.append(rig.global_transform*rig.get_bone_global_pose(index)*mesh.skin.get_bind_pose(bind))
		var vertices_world: Array[Vector3]=[]
		var minimum:=INF
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var slots: int=weights.size()/vertices.size()
			for vertex in vertices.size():
				var point:=Vector3.ZERO
				for slot in slots:
					var offset:=vertex*slots+slot
					if weights[offset]>0:point+=(palette[bones[offset]]*vertices[vertex])*weights[offset]
				vertices_world.append(point);minimum=minf(minimum,point.y)
		for point in vertices_world:
			if point.y<=minimum+.014:sole_points[side].append(foot.affine_inverse()*point)
