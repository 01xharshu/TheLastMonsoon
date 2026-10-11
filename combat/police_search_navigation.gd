extends Node
## One chase owns one queued search. Only remembered/visible goals enter this node.
var path: Array[Vector3] = []
var path_index := 0
var target := Vector3.INF
var pending := false
var retry_age := 0.0
var blocked_age := 0.0

func receive_navigation(points: Array[Vector3], goal: Vector3) -> void:
	pending=false
	if goal.distance_to(target)>1.0:return
	path=points;path_index=0
	retry_age=2.0

func move(encounters: Node3D, actor: Node3D, goal: Vector3, speed: float, delta: float) -> bool:
	retry_age=maxf(0.0,retry_age-delta)
	if not target.is_finite() or target.distance_to(goal)>1.0:
		target=goal;path.clear();path_index=0;blocked_age=0.0
	while path_index<path.size() and actor.global_position.distance_to(path[path_index])<.2:
		path_index+=1
	var waypoint: Vector3=path[path_index] if path_index<path.size() else goal
	var before:=actor.global_position
	var reached: bool=encounters.move_actor(actor,waypoint,speed,delta)
	if reached and path_index<path.size():path_index+=1;return false
	if reached:return true
	if before.distance_to(actor.global_position)<.005 and not actor.get_meta("patrol_turning",false):blocked_age+=delta
	else:blocked_age=0.0
	if blocked_age>=.6 and not pending and retry_age<=0.0:
		pending=true;blocked_age=0.0
		preload("res://systems/navigation_work_queue.gd").request(self,actor,target)
	return false
