extends Node
## Reuses the village's full-body MPFB residents; never creates duplicate people.
const Journey = preload("res://world/suryagarh/settlements/street_journey.gd")
var members: Array[Dictionary] = []
var clock: Node
var fire: Node3D
var scan_age := 0.0

class FireJourney extends Journey:
	var arrived := false
	var seat_exclusions: Array[RID]=[]
	var returning_to_seat := false
	func motion_exclusions() -> Array[RID]:
		var exclusions: Array[RID]=super.motion_exclusions()
		if goal==1 or (returning_to_seat and goal==route.size()-1):exclusions.append_array(seat_exclusions)
		return exclusions
	func arrive() -> void:
		if goal == route.size()-1:
			arrived=true;paused=true;actor.travel_speed=0.0
		else: goal+=1

func _ready() -> void:
	clock=get_tree().root.find_child("GameTimeSystem",true,false)

func _physics_process(delta: float) -> void:
	scan_age+=delta
	if members.size()<4 and scan_age>.05:
		scan_age=0.0
		var population:=get_tree().get_first_node_in_group("village_daily_activities")
		if population==null:return
		var candidates: Array[Node3D]=[]
		for resident: Node3D in get_tree().get_nodes_in_group("village_work_residents"):
			if resident.movement_profile==&"male" and resident.household_job in ["social","hoe"]:candidates.append(resident)
		candidates.sort_custom(func(a: Node3D,b: Node3D):
			if a.household_job!=b.household_job:return a.household_job=="social"
			return str(a.name)<str(b.name))
		for actor in candidates:
			if members.size()>=4:break
			var found:=false
			for member in members:
				if member.actor==actor:found=true
			if found:continue
			var same_role: int=members.filter(func(member):return member.actor.household_job==actor.household_job).size()
			if same_role>=2:continue
			var slot: int=same_role+(0 if actor.household_job=="social" else 2)
			var lantern: Node3D=null
			if slot in [0,2]:
				lantern=preload("res://world/suryagarh/settlements/village_carried_lantern.gd").new()
				lantern.configure(actor)
			members.append({"slot":slot,"lantern":lantern,"actor":actor,"activity":actor.get_node("DailyActivity"),"journey":null,"active":false,"returning":false,"prop_visible":true,"return_goal":1})
	if clock==null or not is_instance_valid(fire):return
	var night: bool=clock.current_hour>=18 or clock.current_hour<6
	for member_index in members.size():
		var member: Dictionary=members[member_index]
		var index: int=member.slot
		var actor: Node3D=member.actor
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false) or actor.get_meta("combat_action","")!="":
			if member.lantern!=null:member.lantern.update(delta,false)
			continue
		if night and not member.active:_depart(member,index,false)
		elif not night and member.active and not member.returning:_depart(member,index,true)
		if not member.active:continue
		var journey: FireJourney=member.journey
		journey.tick(delta)
		if not journey.arrived:
			if member.lantern!=null:member.lantern.update(delta,night)
			continue
		if member.returning:
			if member.lantern!=null:member.lantern.update(delta,false)
			journey.queue_free();member.journey=null;member.active=false;member.returning=false
			if member.activity.prop!=null:member.activity.prop.visible=member.prop_visible
			member.activity.set_physics_process(true)
			actor.set_meta("fire_gathering",false)
			continue
		actor.travel_speed=0.0
		var offset:=fire.global_position-actor.global_position
		actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*1.8)
		actor._set_animation(&"idle",delta)
		member.activity.elapsed+=delta
		if member.lantern==null:
			actor.solve_hand_contact("r",actor.to_global(Vector3(-.23,.76+.06*sin(member.activity.elapsed*.8+index),.27)))
		if actor.drape!=null:actor.drape.update()
		if member.lantern!=null:member.lantern.update(delta,night)
		actor.set_meta("daily_activity","gathering_at_fire")

func _depart(member: Dictionary,index: int,returning: bool) -> void:
	var actor: Node3D=member.actor
	var activity: Node=member.activity
	activity.set_physics_process(false)
	if not returning and activity.prop!=null:
		member.prop_visible=activity.prop.visible;activity.prop.hide()
	actor.global_position.y=activity.layout.height(actor.global_position.x,actor.global_position.z)
	var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
	shape.shape.height=1.6;shape.position.y=.8
	actor.body_collider.force_update_transform()
	actor.animation_tree.set("parameters/daily_work/blend_amount",0.0)
	var angle: float=.35+index*PI*.5
	var centre:=Vector2(fire.global_position.x,fire.global_position.z)
	var destination:=centre+Vector2(cos(angle),sin(angle))*2.25
	var here:=Vector2(actor.global_position.x,actor.global_position.z)
	var points: Array[Vector2]=[here]
	if returning:
		# Retrace only the completed approach, including its safe arc around the fire.
		var previous: FireJourney=member.journey
		var last:=previous.route.size()-2 if previous.arrived else maxi(0,previous.goal-1)
		if last<int(member.return_goal):
			# Dawn during the household exit still follows its safe field path.
			for waypoint in range(previous.goal,int(member.return_goal)+1):points.append(previous.route[waypoint])
		else:
			for waypoint in range(last,int(member.return_goal)-1,-1):points.append(previous.route[waypoint])
		points.append(activity.workplace)
	else:
		# Registration can occur while a farmer is already commuting home.
		# Follow that household's surveyed path back to the field first.
		var departure: Vector2=activity.workplace
		if not activity.seated and activity.commute.size()>1:
			var nearest_segment:=1
			var nearest_distance:=INF
			for segment in range(1,activity.commute.size()):
				var a: Vector2=activity.commute[segment-1]
				var b: Vector2=activity.commute[segment]
				var edge:=b-a
				var projection:=a+edge*clampf((here-a).dot(edge)/maxf(edge.length_squared(),.0001),0.0,1.0)
				var distance:=here.distance_squared_to(projection)
				if distance<nearest_distance:nearest_distance=distance;nearest_segment=segment
			if nearest_distance<4.0:
				for waypoint in range(nearest_segment,activity.commute.size()):points.append(activity.commute[waypoint])
			departure=activity.workplace
		var exit_point:=departure+Vector2(0,1.3) if activity.seated else departure
		member.return_goal=points.size()
		# Separate lanes and matching-side fire entries avoid head-on
		# crossings on both the outward and retraced dawn journey.
		var lane: float=-260+index*1.2
		var upper: bool=sin(angle)>0.0
		var entry_angle: float=(PI*.5 if upper else -PI*.5)+(-.35 if index in [0,2] else .35)
		var radius: float=3.5
		var entry:=centre+Vector2(cos(entry_angle),sin(entry_angle))*radius
		var approach_z: float=centre.y+(4.5 if upper else (-4.5 if index==2 else -6.5))
		points.append_array([exit_point,Vector2(lane,exit_point.y),Vector2(lane,approach_z),Vector2(entry.x,approach_z),entry])
		var arc: float=angle_difference(entry_angle,angle)
		var steps:=maxi(1,ceili(absf(arc)/.45))
		for step in range(1,steps+1):
			var phase: float=entry_angle+arc*float(step)/steps
			points.append(centre+Vector2(cos(phase),sin(phase))*radius)
		points.append(destination)
	if member.journey!=null:member.journey.queue_free()
	var journey:=FireJourney.new()
	journey.configure(actor,points,0.0 if returning else index*2.4);add_child(journey)
	if not returning and Vector2(actor.global_position.x,actor.global_position.z).distance_to(activity.workplace)>1.0:
		# A saved resident already along the night route resumes from that
		# segment; retain the full route for a safe dawn return.
		var nearest_distance:=INF
		var resume_goal:=1
		var position_2d:=Vector2(actor.global_position.x,actor.global_position.z)
		for waypoint in range(int(member.return_goal)+1,points.size()):
			var a:=points[waypoint-1]
			var edge:=points[waypoint]-a
			var projection:=a+edge*clampf((position_2d-a).dot(edge)/maxf(edge.length_squared(),.0001),0.0,1.0)
			var distance:=position_2d.distance_squared_to(projection)
			if distance<nearest_distance:nearest_distance=distance;resume_goal=waypoint
		if nearest_distance<.09:journey.goal=resume_goal
	if activity.seated:
		journey.returning_to_seat=returning
		for label in ["BhairavpurWellSeat0","BhairavpurWellSeat2"]:
			var seat:=get_tree().root.find_child(label,true,false)
			if seat!=null and Vector2(seat.global_position.x,seat.global_position.z).distance_to(activity.workplace)<2.0:
				for body: StaticBody3D in seat.find_children("*","StaticBody3D",true,false):journey.seat_exclusions.append(body.get_rid())
	journey.clock=null;journey.set_physics_process(false)
	# Later departures do not catch the resident immediately ahead.
	journey.speed=.88-index*.025
	member.journey=journey;member.active=true;member.returning=returning
	actor.set_meta("fire_gathering",true)
