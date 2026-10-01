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
var driver_lean:=.4

func configure(vehicle:Node3D,people:Array[Node3D],points:Array[Vector3],coachman:Node3D) -> void:
	coach=vehicle;residents=people;route=points;driver=coachman
	driver.set_process(false);driver.set("foot_plant_enabled",false)
	driver.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
	for part in coach.visual_root.get_children():
		if str(part.get_meta("part_label",part.name)).begins_with("Coachman"):part.hide()
	for person in [driver]+residents:
		if person.get_node_or_null("Vitality") == null:
			var vitality := preload("res://combat/npc_vitality.gd").new()
			vitality.name = "Vitality"
			person.add_child(vitality)
	for person in residents:
		home_positions[person]=person.global_position
		person.add_to_group("household_resident")
	coach.rotation.y=atan2(-(route[1]-route[0]).x,-(route[1]-route[0]).z)

func _physics_process(delta:float) -> void:
	step(delta)

var journeys:Array[Node]=[]
var home_path:Array[Vector3]=[]
var office:Node3D
var actions:Dictionary={}

func configure_journeys(points:Array[Vector3],workplace:Node3D) -> void:
	home_path=points;office=workplace
	for i in residents.size():
		var journey:=preload("res://world/suryagarh/settlements/household_resident_journey.gd").new()
		journey.name="ResidentJourney"+str(i);add_child(journey);journey.configure(residents[i],self,i);journeys.append(journey)

func _all(state:String) -> bool:
	for journey in journeys:
		if journey.state!=state:return false
	return true

func _home_walk(journey:Node,returning:bool) -> Array[Vector3]:
	var points:Array[Vector3]=home_path.duplicate()
	var rear:=coach.to_global(Vector3(journey.side*2.1,0,5.1))
	points.append(rear);points.append(journey.door_ground())
	if returning:
		points.reverse();points.append(home_positions[journey.actor])
	return points

func _office_walk(journey:Node,returning:bool) -> Array[Vector3]:
	var x:float=-1.6 if journey.side<0 else 1.6
	var points:Array[Vector3]=[coach.to_global(Vector3(journey.side*2.1,0,5.1)),office.to_global(Vector3(0,0,5.1)),office.to_global(Vector3(0,.24,3.6)),office.to_global(Vector3(0,.24,1.6)),office.to_global(Vector3(x+(-.75 if x<0 else .75),.24,.35))]
	if returning:points.reverse();points.append(journey.door_ground())
	return points

func _phase(next:String) -> void:
	phase=next;dwell=0;actions[phase]=true

func step(delta:float) -> void:
	if driver.get_meta("dead",false) or not coach.can_move():
		coach.set_forward_motion(0.0,delta)
		coach.set_meta("travel_disabled",true)
		return
	for journey in journeys:journey.tick(delta)
	if phase=="home":
		dwell+=delta
		if dwell>=12:
			_phase("leaving_home")
			for journey in journeys:journey.walk(_home_walk(journey,false),"leave_home")
	elif phase=="leaving_home" or phase=="boarding_return":
		if _all("seated"):
			if phase=="leaving_home":direction=1;target_index=1;_phase("departing")
			else:direction=-1;target_index=route.size()-2;_phase("turning")
	elif phase=="office_arrival" or phase=="home_arrival":
		if _all("outside_coach"):
			for journey in journeys:
				if phase=="office_arrival":journey.walk(_office_walk(journey,false),"enter_office")
				else:journey.walk(_home_walk(journey,true),"enter_home")
			_phase("entering_office" if phase=="office_arrival" else "entering_home")
	elif phase=="entering_office":
		if _all("work"):_phase("working")
	elif phase=="working":
		dwell+=delta
		if dwell>=18:
			for journey in journeys:journey.walk(_office_walk(journey,true),"leave_office")
			_phase("boarding_return")
	elif phase=="entering_home":
		if _all("home"):completed_trips+=1;_phase("home")
	elif phase=="turning":
		dwell+=delta
		var facing:Vector3=(route[target_index]-coach.global_position).normalized()
		var yaw:=rotate_toward(coach.rotation.y,atan2(-facing.x,-facing.z),delta*2.0)
		if not _clear(coach.global_position,Basis(Vector3.UP,yaw)):blocked_frames+=1;dwell-=delta;return
		coach.rotation.y=yaw
		if dwell>=1.8:_phase("returning")
	elif phase in ["departing","returning"]:
		var target:Vector3=route[target_index];var offset:=target-coach.global_position
		var amount:=minf(offset.length(),delta*2)
		var heading:=atan2(-offset.x,-offset.z);var next_basis:=Basis(Vector3.UP,heading)
		var next_at:=coach.global_position+offset.normalized()*amount
		if _clear(next_at,next_basis):
			coach.global_position=next_at;coach.rotation.y=heading;distance_travelled+=amount;coach.set_forward_motion(2,delta)
		else:blocked_frames+=1;coach.set_forward_motion(0,delta)
		if coach.global_position.distance_to(target)<.03:
			if direction==1 and target_index==route.size()-1:
				_phase("office_arrival")
				for journey in journeys:journey.disembark()
			elif direction==-1 and target_index==0:
				_phase("home_arrival")
				for journey in journeys:journey.disembark()
			else:target_index+=direction
	if phase not in ["departing","returning"]:coach.set_forward_motion(0,delta)
	for journey in journeys:
		if journey.state=="seated":_seat(journey.actor,journey.seat_name,0)
	_seat(driver,"CoachmanSeat",delta)
	coach.boarding.collision_body.force_update_transform();coach.set_meta("travel_phase",phase)

func _seat(actor:Node3D,socket_name:String,delta:float) -> void:
	if actor.get_meta("dead",false): return
	actor.set_meta("seated_coach",coach)
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
		for side in ["l","r"]:
			actor.call("solve_hand_contact",side,coach.rein_grip_world(side))
			actor.call("set_grip",side,.7)

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
