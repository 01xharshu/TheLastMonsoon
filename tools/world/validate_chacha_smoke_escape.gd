extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
	create_timer(45).timeout.connect(func():quit(2))
func check(value: bool, label: String) -> void:
	if not value:failures.append(label);push_error(label)
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var settlement:=Node3D.new();settlement.name="Settlement";world.add_child(settlement)
	var station=load("res://world/suryagarh/settlements/civic_building.gd").new();station.name="DistrictPolice";station.police=true;settlement.add_child(station)
	var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
	player.global_position=station.to_global(Vector3(9.5,.9,9))
	for i in 15:await physics_frame
	player.set_physics_process(false)
	var coordinator: Node=station.get_node("ThanaStaff/ArrestCoordinator");coordinator.set_physics_process(false)
	check(coordinator.report_crime(player,"assault",player.global_position),"police witness begins pursuit")
	if coordinator.officer == null:quit(1);return
	var old_goal: Vector3=coordinator.last_chase_goal
	var eye: Vector3=coordinator.officer.global_position+Vector3.UP*1.3
	var cloud=load("res://combat/escape_smoke.gd").new();world.add_child(cloud);cloud.set_process(false)
	cloud.global_position=(eye+player.global_position+Vector3.UP*.4)*.5
	var away: Vector3=(player.global_position-coordinator.officer.global_position).normalized();away.y=0
	player.global_position+=away*3
	coordinator.chase_age=1
	coordinator._physics_process(.1)
	check(coordinator.last_chase_goal.is_equal_approx(old_goal),"smoke prevents tracking the new player position")
	var trace=load("res://combat/ballistic_trace.gd")
	var exclusions: Array[RID]=[player.get_rid()]
	var obscured: Dictionary=trace.sight(world.get_world_3d().direct_space_state,self,eye,player.global_position+Vector3.UP*.4,exclusions)
	check(not obscured.is_empty() and obscured.collider==cloud,"fort sight trace sees smoke cover")
	cloud.age=10
	coordinator.chase_age=1
	coordinator._physics_process(.1)
	check(coordinator.last_chase_goal.is_equal_approx(player.global_position),"pursuit reacquires position after smoke expires")
	print("CHACHA SMOKE ESCAPE: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)

func finish(status: int) -> void:
	quit(status)
