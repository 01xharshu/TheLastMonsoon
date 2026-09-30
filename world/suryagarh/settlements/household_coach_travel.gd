extends Node
## Bounded household driveway journeys with occupied seats and obstacle stops.
var driver:Node3D
var coach:Node3D
var residents:Array[Node3D]=[]
var route:Array[Vector3]=[]
var home_positions:Dictionary={}
var phase:="home"
var dwell:=0.0
var target_index:=1
var direction:=1
var distance_travelled:=0.0
var completed_trips:=0
var blocked_frames:=0
var driver_lean:=0.0

func configure(vehicle:Node3D,people:Array[Node3D],points:Array[Vector3],coachman:Node3D) -> void:
	coach=vehicle;residents=people;route=points;driver=coachman
	driver.set_process(false);driver.set("foot_plant_enabled",false)
	driver.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
	for part in coach.visual_root.get_children():
		if part.name.begins_with("Coachman"):part.hide()
	for person in residents:
		home_positions[person]=person.global_position
		person.add_to_group("household_resident")
	coach.rotation.y=atan2(-(route[1]-route[0]).x,-(route[1]-route[0]).z)

func _physics_process(delta:float) -> void:
	step(delta)

func step(delta:float) -> void:
	if phase=="home":
		dwell+=delta
		if dwell>=12.0:
			dwell=0.0; phase="departing";direction=1;target_index=1
			for person in residents:
				person.set_process(false);person.set("foot_plant_enabled",false)
				_passenger_cloth(person,true)
				person.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
	elif phase=="turning":
		dwell+=delta
		var facing:Vector3=(route[target_index]-coach.global_position).normalized()
		var yaw:=rotate_toward(coach.rotation.y,atan2(-facing.x,-facing.z),delta*2.0)
		if not _clear(coach.global_position,Basis(Vector3.UP,yaw)):
			blocked_frames+=1;dwell-=delta;return
		coach.rotation.y=yaw
		if dwell>=1.8:phase="returning";dwell=0.0
	else:
		var target:Vector3=route[target_index]
		var offset:Vector3=target-coach.global_position
		var amount:=minf(offset.length(),delta*2.0)
		var heading:=atan2(-offset.x,-offset.z)
		var next_basis:=Basis(Vector3.UP,heading)
		var next_at:=coach.global_position+offset.normalized()*amount
		if _clear(next_at,next_basis):
			coach.global_position=next_at;coach.rotation.y=heading
			distance_travelled+=amount
			coach.set_forward_motion(2.0,delta)
		else:
			blocked_frames+=1;coach.set_forward_motion(0.0,delta)
		if coach.global_position.distance_to(target)<.03:
			if direction==1 and target_index==route.size()-1:
				direction=-1;target_index-=1;phase="turning";dwell=0.0
			elif direction==-1 and target_index==0:
				phase="home";dwell=0.0;completed_trips+=1
				for person in residents:
					person.global_position=home_positions[person]
					person.set("foot_plant_enabled",true)
					_passenger_cloth(person,false)
					person.get_node("BodyCollider/BodyShape").set_deferred("disabled",false)
					person.set_process(true)
			else:target_index+=direction
	if phase=="home" or phase=="turning":coach.set_forward_motion(0.0,delta)
	if phase!="home":
		for i in residents.size():_seat(residents[i],"RearPassengerLeft" if i==0 else "RearPassengerRight",delta)
	_seat(driver,"CoachmanSeat",delta)
	coach.boarding.collision_body.force_update_transform()
	coach.set_meta("travel_phase",phase)

func _seat(actor:Node3D,socket_name:String,delta:float) -> void:
	actor.call("_set_animation",&"idle",delta)
	var skeleton:Skeleton3D=actor.get("_skeleton")
	var bases:Dictionary=actor.get("_base_rotations")
	var axes:Dictionary=actor.get("_pitch_axes")
	for side in ["l","r"]:
		for entry in [["thigh_",-1.5],["calf_",1.5]]:
			var bone:String=entry[0]+side
			var index:=skeleton.find_bone(bone)
			if index>=0:skeleton.set_bone_pose_rotation(index,bases[bone]*Quaternion(axes[bone],entry[1]))
	if socket_name=="CoachmanSeat":
		var spine:=skeleton.find_bone("spine_02")
		skeleton.set_bone_pose_rotation(spine,bases["spine_02"]*Quaternion(axes["spine_02"],driver_lean))
		for side in ["l","r"]:
			for entry in [["upperarm_",-.5],["lowerarm_",-.7]]:
				var bone:String=entry[0]+side
				skeleton.set_bone_pose_rotation(skeleton.find_bone(bone),bases[bone]*Quaternion(axes[bone],entry[1]))
	var socket:Node3D=coach.seat_sockets[socket_name]
	actor.global_rotation.y=socket.global_rotation.y+PI
	var pelvis:=skeleton.find_bone("pelvis")
	var hip:Vector3=skeleton.to_global(skeleton.get_bone_global_pose(pelvis).origin)
	actor.global_position+=socket.global_position-hip
	if socket_name=="CoachmanSeat":
		for side in ["l","r"]:actor.call("solve_hand_contact",side,coach.rein_grip_world(side))

func _clear(at:Vector3,basis:Basis) -> bool:
	var exclusions:Array[RID]=[coach.boarding.collision_body.get_rid(),driver.get_node("BodyCollider").get_rid()]
	for actor in residents:exclusions.append(actor.get_node("BodyCollider").get_rid())
	var space:=coach.get_world_3d().direct_space_state
	for collision in coach.boarding.clearance_shapes:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=collision.shape
		query.transform=Transform3D(basis,at+basis*collision.position)
		query.exclude=exclusions;query.collision_mask=1
		if not space.intersect_shape(query,1).is_empty():return false
	return true

func _passenger_cloth(actor:Node3D,seated:bool) -> void:
	if actor.get("movement_profile")!=&"female":return
	var skirt:MeshInstance3D
	for node in actor.find_children("*","MeshInstance3D",true,false):
		if "gathered skirt" in node.name.to_lower():skirt=node
		if "gathered skirt" in node.name.to_lower() or "fitted waist transition" in node.name.to_lower():node.visible=not seated
	if not actor.has_meta("coach_dress") and skirt!=null:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings:=[Vector3(0,.1,0),Vector3(0,-.07,-.26),Vector3(0,-.28,-.52),Vector3(0,-.42,-.56)]
		var radii:=[Vector2(.20,.17),Vector2(.25,.28),Vector2(.23,.18),Vector2(.25,.17)]
		var points:Array[Vector3]=[]
		for row in rings.size():
			for index in 32:
				var angle:=TAU*index/32.0
				points.append(rings[row]+Vector3(cos(angle)*radii[row].x,0,sin(angle)*radii[row].y))
		for row in 3:
			for index in 32:
				var a:=row*32+index;var b:=row*32+(index+1)%32
				for vertex in [a,b,a+32,b,b+32,a+32]:surface.add_vertex(points[vertex])
		surface.index();surface.generate_normals()
		var dress:=MeshInstance3D.new();dress.name="SeatedDressCandidate";dress.mesh=surface.commit()
		dress.material_override=skirt.get_active_material(0)
		coach.seat_sockets["RearPassengerRight"].add_child(dress)
		actor.set_meta("coach_dress",dress)
	if actor.has_meta("coach_dress"):actor.get_meta("coach_dress").visible=seated
