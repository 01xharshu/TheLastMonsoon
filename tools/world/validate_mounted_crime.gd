extends "res://tools/world/validate_crime_perception.gd"
## Actual MPFB officer/horse, without unrelated city builders or saved-game writes.
func run() -> void:
	create_timer(60).timeout.connect(func():root.get_node("SaveManager").quit_game(2))
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var camera:=Camera3D.new();camera.position=Vector3(8,5,12);world.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
	var player:=TestPlayer.new();player.name="Player";player.position=Vector3(0,0,12);world.add_child(player)
	var stance:=Stance.new();stance.name="StealthStance";player.add_child(stance)
	var floor_body:=StaticBody3D.new();world.add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,1,100);shape.shape=box;shape.position.y=-.5;floor_body.add_child(shape)
	var crime:Node3D=load("res://tools/world/police_movement_fixture.gd").new();world.add_child(crime);crime.player=player
	var station:=Node3D.new();world.add_child(station);crime.station=station
	var staff:=Node.new();staff.name="ThanaStaff";station.add_child(staff)
	var coordinator:=Coordinator.new();coordinator.name="ArrestCoordinator";staff.add_child(coordinator)
	await sync()
	var actor:Node3D=crime.spawn("MountedProbe","res://characters/npcs/thana/burkundaz_motion.glb",Vector3.ZERO,"police",true)
	var horse:Node3D=crime.install_patrol_mount(actor,Vector3.ZERO);horse.rotation.y=PI
	var marker:=Label3D.new();actor.add_child(marker)
	var patrol:Dictionary={"actor":actor,"points":PackedVector3Array([Vector3.ZERO,Vector3(0,0,15)]),"index":1,"step":1,"state":"patrol","sense":0.0,"attack_age":0.0,"hit":false,"marker":marker,"seen":false,"mount":horse,"horse":horse}
	crime.patrols.append(patrol)
	for frame in 15:await process_frame
	check(actor._skeleton!=null and actor.patrol_mount==horse,"existing MPFB officer uses live horse saddle")
	check(not horse.is_in_group("mountable_vehicles"),"autonomous police horse cannot use player boarding")
	check(not horse.is_in_group("horses") and horse.is_in_group("police_mounts"),"family ownership setup cannot claim or relocate a police mount")
	var pelvis:int=actor._skeleton.find_bone("pelvis")
	var hip:Vector3=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(pelvis).origin)
	check(hip.distance_to(horse.seat_world())<.08,"mounted pelvis remains at live saddle")
	var witnesses:Array[String]=["owner"]
	crime.record_incident("theft",player.position,witnesses,5)
	for frame in 45:
		await physics_frame;crime._tick(1.0/60.0)
	check(patrol.state=="pursue" and horse.commanded_speed>2,"mounted police acquire by sight and chase")
	check(horse.position.z>1,"autonomous horse actually moves toward seen suspect")
	var remembered:Vector3=patrol.last_seen
	var wall:=StaticBody3D.new();world.add_child(wall)
	var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(30,5,.5);wall_shape.shape=wall_box;wall_shape.position=Vector3(0,2.5,horse.position.z+2);wall.add_child(wall_shape)
	player.position.x=6;await sync();crime._tick(.3)
	check(not patrol.seen and horse.goal==remembered,"mounted search retains last seen goal through wall")
	wall.queue_free();await sync()
	horse.commanded_speed=0
	var blocked_exits:Array[Node3D]=[]
	for side in [-1.0,1.0]:
		var barrier:=StaticBody3D.new();world.add_child(barrier)
		barrier.position=horse.position+horse.global_basis.x*side*1.55
		var barrier_shape:=CollisionShape3D.new();var barrier_box:=BoxShape3D.new();barrier_box.size=Vector3(.7,3,3)
		barrier_shape.shape=barrier_box;barrier_shape.position.y=1.5;barrier.add_child(barrier_shape);blocked_exits.append(barrier)
	await sync()
	check(not crime.dismount_patrol(patrol) and patrol.mount==horse,"blocked exits keep rider mounted without landing inside walls")
	for barrier in blocked_exits:barrier.queue_free()
	await sync()
	check(crime.dismount_patrol(patrol),"mounted officer selects supported clear dismount ground")
	for frame in 90:await physics_frame
	check(not actor.get_meta("police_dismounting",false) and actor.body_collider.collision_layer==1 and patrol.mount==null,"dismount finishes with foot collision and combat available")
	actor.begin_mount(horse);patrol.mount=horse
	for frame in 90:await physics_frame
	hip=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(pelvis).origin)
	check(not actor.get_meta("police_mounting",false) and hip.distance_to(horse.seat_world())<.08,"remount transition returns pelvis to saddle")
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	print("MOUNTED CRIME ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
