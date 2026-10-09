extends Node3D
## One morning departure per day; physical route, shared river visit, home delivery.
const Woman = preload("res://characters/npcs/indian/river_woman_study.gd")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()
var women: Array[Node3D] = []
var journeys: Array[Dictionary] = []
var clock: Node
var completed_day := 0
var departure_day := 0
var mode := "home"
var visit_seconds := 0.0
var blocked_frames := 0
var ramp: Array[Vector3] = []
var shore := Vector3.ZERO
const SPEED := 1.15
const ROUTE_VERSION := 3

func _ready() -> void:
	name = "VillageRiverRoutine"
	add_to_group("village_river_routine")
	clock = get_tree().root.find_child("GameTimeSystem",true,false)
	_build_ghat()
	for index in 3:
		var woman := Woman.new()
		woman.name = "BhairavpurRiverWoman%d"%index
		woman.member_index = index
		woman.water_level = Layout.WATER_LEVEL
		var start := Vector2(-277.0-index*1.3,208.5)
		woman.home = Vector3(start.x,layout.height(start.x,start.y),start.y)
		woman.bank = shore+Vector3(0,0,(index-1)*1.1)
		woman.travel_override = true
		woman.ground_height = _ground_height
		add_child(woman)
		woman.set_process(false)
		woman.sample(72.0)
		var collider := AnimatableBody3D.new()
		collider.sync_to_physics=false
		collider.name = "BodyCollider";collider.collision_layer=1;collider.collision_mask=0
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.5
		collision.name="BodyShape";collision.shape=capsule;collision.position.y=.8
		collider.add_child(collision);woman.add_child(collider)
		var path: Array[Vector3] = [woman.home]
		var lane := (index-1)*1.1
		for p in [Vector2(start.x,203+lane),Vector2(-250+lane,203+lane),Vector2(-250+lane,210+lane),Vector2(-230,180+lane),Vector2(-230,160+12*sin(-230*.017)+lane)]:
			path.append(Vector3(p.x,layout.height(p.x,p.y),p.y))
		var ramp_start := ramp[0]
		for step in 40:
			var x := lerpf(-230.0,ramp_start.x,float(step+1)/40.0)
			var bank_z := 160+12*sin(x*.017)
			var z := lerpf(bank_z,ramp_start.z,smoothstep(.65,1.0,float(step+1)/40.0))+lane+.12*sin(float(step)*.32+index)
			path.append(Vector3(x,layout.height(x,z),z))
		for point in ramp: path.append(point+Vector3(0,0,(index-1)*1.1))
		path.append(woman.bank)
		women.append(woman)
		journeys.append({"path":path,"goal":1,"position":woman.home,"walk_seconds":index*.31,"delay":index*.65,"arrived":false})

func _physics_process(delta: float) -> void:
	if clock != null and clock.clock_paused: return
	tick(delta)

func tick(delta: float) -> void:
	if mode == "home":
		if clock == null or clock.current_hour<6 or clock.current_hour>=9 or clock.current_day<=completed_day: return
		departure_day=clock.current_day;mode="depart";visit_seconds=0
		for journey in journeys:
			journey.goal=1;journey.arrived=false;journey.walk_seconds=float(journeys.find(journey))*.31;journey.delay=float(journeys.find(journey))*.65
	if mode in ["depart","return"]:
		var all_arrived := true
		for index in women.size():
			var woman = women[index]
			var journey = journeys[index]
			_move(index,delta)
			all_arrived = all_arrived and journey.arrived
			woman.travel_position=journey.position
			var path: Array = journey.path
			var target: Vector3 = path[journey.goal]
			var facing_offset: Vector3=target-journey.position
			facing_offset.y=0.0
			if facing_offset.length()>.01: woman.travel_direction=facing_offset.normalized()
			woman.elapsed=(0.0 if mode=="depart" else 55.0)+fposmod(journey.walk_seconds,9.6)
			woman.travel_gait_time=journey.walk_seconds
			woman.travel_speed=0.0 if journey.arrived or journey.get("delay",0.0)>0.0 else _walking_speed(index)
			if journey.arrived: woman.elapsed=11.0 if mode=="depart" else 65.0
			woman._evaluate(delta)
		if all_arrived:
			mode="visit" if mode=="depart" else "deliver"
			visit_seconds=10.0 if mode=="visit" else 65.0
	elif mode in ["visit","deliver"]:
		visit_seconds+=delta
		for index in women.size():
			var woman=women[index]
			woman.elapsed=visit_seconds-delta-(index*.7 if mode=="visit" else 0.0);woman.tick_routine(delta)
		if mode=="visit" and visit_seconds>=56.4:
			mode="return"
			for journey in journeys:
				journey.goal=journey.path.size()-2;journey.arrived=false;journey.walk_seconds=0.0
		if mode=="deliver" and visit_seconds>=68:
			mode="home";completed_day=departure_day
			for woman in women: woman.sample(72)

func _move(index: int, delta: float) -> void:
	var journey = journeys[index]
	if journey.arrived: return
	if journey.get("delay",0.0)>0.0:
		journey.delay=maxf(0.0,float(journey.delay)-delta)
		return
	var woman = women[index]
	var target: Vector3 = journey.path[journey.goal]
	var offset: Vector3 = target-journey.position
	offset.y=0.0
	var motion := offset.limit_length(_walking_speed(index)*delta)
	var next := Vector3(journey.position)+motion
	next.y=_ground_height(next.x,next.z)
	motion=next-journey.position
	var shape: CollisionShape3D = woman.get_node("BodyCollider/BodyShape")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape.shape;query.transform=shape.global_transform
	query.transform.origin.y+=.12;query.motion=motion;query.margin=.005;query.collision_mask=1
	var exclusions: Array[RID] = []
	for member in women:
		if member.has_node("BodyCollider"): exclusions.append(member.get_node("BodyCollider").get_rid())
	query.exclude=exclusions
	var safe := get_world_3d().direct_space_state.cast_motion(query)
	if safe[0]<.99:
		blocked_frames+=1
		if blocked_frames==1:
			query.transform.origin+=motion
			for hit in get_world_3d().direct_space_state.intersect_shape(query,8): print("RIVER_OBSTACLE ",hit.collider.get_path())
		return
	journey.position+=motion;journey.walk_seconds+=Vector2(motion.x,motion.z).length()/.4
	if Vector2(journey.position.x,journey.position.z).distance_to(Vector2(target.x,target.z))<.001:
		var end: int = journey.path.size()-1 if mode=="depart" else 0
		if journey.goal==end: journey.arrived=true
		else: journey.goal+=1 if mode=="depart" else -1

func _walking_speed(index: int) -> float:
	# Small individual changes keep companions together without marching in lockstep.
	return SPEED*(1.0+.035*sin(float(journeys[index].walk_seconds)*.13+index*2.1))

func _ground_height(x: float,z: float) -> float:
	if x>=ramp[0].x and x<=shore.x+.5 and absf(z-shore.z)<2.3:
		for i in ramp.size()-1:
			if x<=ramp[i+1].x:
				return lerpf(ramp[i].y,ramp[i+1].y,inverse_lerp(ramp[i].x,ramp[i+1].x,x))
		return shore.y
	var expected := layout.height(x,z)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x,expected+1.0,z),Vector3(x,expected-1.0,z),1)
	var exclusions: Array[RID] = []
	for member in women:
		if member.has_node("BodyCollider"): exclusions.append(member.get_node("BodyCollider").get_rid())
	ray.exclude=exclusions
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.normal.y>.6 and absf(hit.position.y-expected)<.5: return hit.position.y
	return expected

func _build_ghat() -> void:
	var z := 185.0
	var edge := layout.river_x(z)-layout.river_width(z)
	var start := edge-43
	var finish := edge+2
	# End where the existing bank actually meets water, before the boating channel.
	for step in 100:
		var candidate := start+float(step)*.5
		var bank_height := maxf(layout.height(candidate,z-2.2),layout.height(candidate,z+2.2))
		if bank_height<=-.03:
			finish=candidate
			break
	for i in 65:
		var x := lerpf(start,finish,float(i)/64)
		var y := maxf(.03,layout.height(x,z)+.06)
		for dz in [-2.2,2.2]: y=maxf(y,layout.height(x,z+dz)+.06)
		ramp.append(Vector3(x,y,z))
	var max_drop := (finish-start)/64*.45
	for i in range(63,-1,-1): ramp[i].y=maxf(ramp[i].y,ramp[i+1].y-max_drop)
	for i in range(1,65): ramp[i].y=maxf(ramp[i].y,ramp[i-1].y-max_drop)
	shore=ramp[-1]
	var material := StandardMaterial3D.new();material.albedo_color=Color(.43,.39,.30);material.roughness=.97
	# A continuous earth surface with shoulders meeting the surveyed terrain.
	# No rectangular seating deck at the collection point.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var widths := [-4.0,-2.2,0.0,2.2,4.0]
	# Support the forward toes as well as the actor origin at the shore endpoint.
	var surface_points: Array[Vector3]=ramp.duplicate()
	surface_points.append(shore+Vector3(.5,0,0))
	for i in surface_points.size()-1:
		for strip in 4:
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,0)]:
				var point: Vector3=surface_points[i+corner.x]
				var side: float=widths[strip+corner.y]
				point.z+=side
				if absf(side)>2.2: point.y=layout.height(point.x,point.z)+.025
				surface.add_vertex(point)
	surface.generate_normals()
	var earth := MeshInstance3D.new();earth.name="ShoreEarthAccess"
	earth.mesh=surface.commit();earth.material_override=material
	add_child(earth);earth.create_trimesh_collision()

func export_state() -> Dictionary:
	var members := []
	for journey in journeys:
		var p: Vector3=journey.position
		members.append({"goal":journey.goal,"position":[p.x,p.y,p.z],"walk_seconds":journey.walk_seconds,"arrived":journey.arrived,"delay":journey.get("delay",0.0)})
	return {"route_version":ROUTE_VERSION,"mode":mode,"completed_day":completed_day,"departure_day":departure_day,"visit_seconds":visit_seconds,"members":members}

func restore_state(state: Dictionary) -> void:
	if state.is_empty(): return
	mode=str(state.get("mode","home"));completed_day=int(state.get("completed_day",0));departure_day=int(state.get("departure_day",0));visit_seconds=float(state.get("visit_seconds",0))
	for i in mini(journeys.size(),state.get("members",[]).size()):
		var saved: Dictionary=state.members[i];var p: Array=saved.position
		journeys[i].position=Vector3(p[0],p[1],p[2]);journeys[i].goal=clampi(int(saved.goal),0,journeys[i].path.size()-1)
		journeys[i].walk_seconds=float(saved.walk_seconds);journeys[i].arrived=bool(saved.arrived)
		journeys[i].delay=float(saved.get("delay",0.0))
		if int(state.get("route_version",1))<ROUTE_VERSION and (mode=="visit" or (mode=="return" and journeys[i].position.x>shore.x)):
			# Old visits used the removed platform; bring them onto the shore route.
			journeys[i].position=women[i].bank
			journeys[i].goal=journeys[i].path.size()-2
		women[i].travel_speed=_walking_speed(i)
		women[i].travel_gait_time=journeys[i].walk_seconds
		women[i].travel_position=journeys[i].position
		var direction: Vector3=journeys[i].path[journeys[i].goal]-journeys[i].position
		if direction.length()>.001: women[i].travel_direction=direction.normalized()
		women[i].elapsed=(0.0 if mode=="depart" else 55.0)+fposmod(journeys[i].walk_seconds,9.6) if mode in ["depart","return"] else visit_seconds-(i*.7 if mode=="visit" else 0.0)
		women[i].sample(women[i].elapsed if mode!="home" else 72.0)
