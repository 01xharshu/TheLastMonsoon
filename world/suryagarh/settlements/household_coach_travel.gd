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
var estate_gate:Node3D
var gate_wait_frames:=0

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

# Far routines retain state/time at the same 0.1 s step used by sequence validation.
const FAR_INTERVAL:=.1
const NEAR_RADIUS:=150.0
const FAR_RADIUS:=180.0
var budget_far:=false
var budget_pending:=0.0
var budget_steps:=0
var budget_skipped:=0

func _physics_process(delta:float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null:
		step(delta);return
	advance_budget(delta,camera.global_position)

func advance_budget(delta:float,observer:Vector3) -> void:
	var nearest:=coach.global_position.distance_squared_to(observer)
	for person in residents:nearest=minf(nearest,person.global_position.distance_squared_to(observer))
	if budget_far:
		if nearest<=NEAR_RADIUS*NEAR_RADIUS:budget_far=false
	elif nearest>FAR_RADIUS*FAR_RADIUS:budget_far=true
	# Bound work and motion after a stall; no unbounded catch-up loop.
	budget_pending+=clampf(delta,0,FAR_INTERVAL)
	if budget_far and budget_pending+0.000001<FAR_INTERVAL:
		budget_skipped+=1;return
	var amount:=minf(budget_pending,FAR_INTERVAL)
	budget_pending=maxf(0,budget_pending-amount)
	budget_steps+=1
	step(amount)

var journeys:Array[Node]=[]
var home_path:Array[Vector3]=[]
var office:Node3D
var actions:Dictionary={}

func configure_journeys(points:Array[Vector3],workplace:Node3D) -> void:
	home_path=points;office=workplace
	for i in residents.size():
		var journey:=preload("res://world/suryagarh/settlements/household_resident_journey.gd").new()
		journey.name="ResidentJourney"+str(i);add_child(journey);journey.configure(residents[i],self,i)
		if coach.name=="BritishHouseholdCoach":journey.side=-1.0
		journeys.append(journey)

func _all(state:String) -> bool:
	if journeys.is_empty():return false
	for journey in journeys:
		if journey.state!=state:return false
	return true

func _home_walk(journey:Node,returning:bool) -> Array[Vector3]:
	var points:Array[Vector3]=home_path.duplicate()
	var rear:=coach.to_global(Vector3(journey.side*2.1,0,5.1))
	if coach.name=="BritishHouseholdCoach":points.append(Vector3(rear.x,points[-1].y,points[-1].z))
	points.append(rear);points.append(journey.door_ground())
	if returning:
		points.reverse();points.append(home_positions[journey.actor])
	return points

func _office_walk(journey:Node,returning:bool) -> Array[Vector3]:
	var x:float=-1.6 if journey.office_side<0 else 1.6
	var rear:=coach.to_global(Vector3(journey.side*2.1,0,5.1))
	var approach:=office.to_global(Vector3(0,0,5.1))
	var stage_x:float=x+(-.75 if x<0 else .75)
	var points:Array[Vector3]=[rear,Vector3(rear.x,approach.y,approach.z),approach,office.to_global(Vector3(0,.24,3.6)),office.to_global(Vector3(0,.24,1.6)),office.to_global(Vector3(stage_x,.24,1.6)),office.to_global(Vector3(stage_x,.24,.35))]
	if returning:points.reverse();points.append(journey.door_ground())
	return points

func _phase(next:String) -> void:
	phase=next;dwell=0;actions[phase]=true

func _estate_gate_ready() -> bool:
	if coach.name!="LandownerHouseholdCoach" or phase not in ["departing","returning","turning"]:return true
	if not is_instance_valid(estate_gate):
		estate_gate=get_tree().current_scene.get_node_or_null("Settlement/BhairavpurLandownerEstate/EstateGateFrame/EntranceGate")
	if estate_gate==null:return true
	var gap:=Vector2(coach.global_position.x-estate_gate.global_position.x,coach.global_position.z-estate_gate.global_position.z).length()
	if gap>18:return true
	# Household access uses the existing animated/swept gate. Explicit player lock wins.
	if estate_gate.manual_locked:return false
	estate_gate.open_idle_seconds=0.0
	estate_gate.set_open(true)
	return estate_gate.opened and not estate_gate.moving

func step(delta:float) -> void:
	if driver.get_meta("dead",false) or not coach.can_move():
		coach.set_forward_motion(0.0,delta)
		coach.set_meta("travel_disabled",true)
		return
	if not _estate_gate_ready():
		gate_wait_frames+=1;coach.set_forward_motion(0,delta)
		return
	for journey in journeys:journey.tick(delta)
	if phase=="home":
		dwell+=delta
		if dwell>=12:
			_phase("leaving_home")
			for journey in journeys:journey.walk(_home_walk(journey,false),"leave_home")
	elif phase=="leaving_home" or phase=="boarding_return":
		if _all("seated"):
			if phase=="leaving_home":
				direction=1;target_index=1
				var desired:Vector3=route[1]-coach.global_position
				if coach.name=="BritishHouseholdCoach" and absf(angle_difference(coach.rotation.y,atan2(-desired.x,-desired.z)))>.2:_phase("backing_out")
				else:_phase("departing")
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
	elif phase=="backing_out":
		# Back clear of the narrow home/stair frontage before turning the team.
		var amount:=minf(delta,absf(coach.global_position.z+159))
		var next_at:=coach.global_position+Vector3(0,0,amount)
		if _clear(next_at,coach.global_basis):coach.global_position=next_at;distance_travelled+=amount;coach.set_forward_motion(-1,delta)
		else:blocked_frames+=1;coach.set_forward_motion(0,delta)
		if coach.global_position.z>=-159.02:_phase("departing")
	elif phase=="turning":
		dwell+=delta
		var facing:Vector3=(route[target_index]-coach.global_position).normalized()
		var yaw:=rotate_toward(coach.rotation.y,atan2(-facing.x,-facing.z),delta*2.0)
		if not _clear(coach.global_position,Basis(Vector3.UP,yaw)):blocked_frames+=1;dwell-=delta;return
		coach.rotation.y=yaw
		if dwell>=1.8:_phase("returning")
	elif phase in ["departing","returning"]:
		var target:Vector3=route[target_index];var offset:=target-coach.global_position
		var amount:=minf(offset.length(),delta*preload("res://vehicles/cart_rider.gd").CRUISE_SPEED)
		var desired_heading:=atan2(-offset.x,-offset.z)
		var heading:=rotate_toward(coach.rotation.y,desired_heading,delta*1.2)
		if absf(angle_difference(coach.rotation.y,desired_heading))>.03:amount=0
		var next_basis:=Basis(Vector3.UP,heading)
		var next_at:=coach.global_position+offset.normalized()*amount
		if _clear(next_at,next_basis):
			coach.global_position=next_at;coach.rotation.y=heading;distance_travelled+=amount;coach.set_forward_motion(amount/maxf(delta,.0001),delta)
		else:blocked_frames+=1;coach.set_forward_motion(0,delta)
		if coach.global_position.distance_to(target)<.03:
			if direction==1 and target_index==route.size()-1:
				_phase("office_arrival")
				for journey in journeys:
					if coach.name=="BritishHouseholdCoach":journey.side=-1.0 if coach.global_basis.x.x<0 else 1.0
					journey.disembark()
			elif direction==-1 and target_index==0:
				_phase("home_arrival")
				for journey in journeys:
					if coach.name=="BritishHouseholdCoach":journey.side=-1.0 if coach.global_basis.x.x<0 else 1.0
					journey.disembark()
			else:target_index+=direction
	if phase not in ["departing","returning","backing_out"]:coach.set_forward_motion(0,delta)
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
	if socket_name!="CoachmanSeat":_passenger_cloth(actor,true)
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
		var hits:=space.intersect_shape(query,1)
		if not hits.is_empty():
			if blocked_frames==0:print("COACH_BLOCKED ",coach.name," ",phase," from=",coach.global_position," next=",at," obstacle=",hits[0].collider.get_path()," obstacle_at=",hits[0].collider.global_position)
			return false
	return true

func _passenger_cloth(actor:Node3D,_seated:bool) -> void:
	if not actor.has_meta("household_drape"):
		var drape:=preload("res://characters/npcs/households/household_drape.gd").new()
		actor.add_child(drape)
		if not drape.configure(actor):
			drape.queue_free();actor.set_meta("household_drape",null);return
		actor.set_meta("household_drape",drape)
	var drape:Node=actor.get_meta("household_drape")
	if is_instance_valid(drape):drape.update_pose()
