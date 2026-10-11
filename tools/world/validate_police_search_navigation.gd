extends "res://tools/world/validate_crime_perception.gd"
## Meshless probes verify real police capsule motion and queued searches.
class Walker extends Probe:
	var _turn_progress := 0.0
	func _ready() -> void:
		super._ready()
		body_collider.collision_layer=1
		var shape:=CollisionShape3D.new();shape.name="BodyShape"
		var capsule:=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.8
		shape.shape=capsule;shape.position.y=.9;body_collider.add_child(shape)
func run() -> void:
	create_timer(60).timeout.connect(func():root.get_node("SaveManager").quit_game(2))
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var player:=TestPlayer.new();player.name="Player";player.position=Vector3(0,0,4);world.add_child(player)
	var stance:=Stance.new();stance.name="StealthStance";player.add_child(stance)
	var actor:=Walker.new();actor.position=Vector3(0,0,-4);world.add_child(actor);actor.add_to_group("combat_actors");actor.set_meta("combat_faction","police")
	var floor_body:=StaticBody3D.new();world.add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(100,1,100);floor_shape.shape=floor_box;floor_shape.position.y=-.5;floor_body.add_child(floor_shape)
	var crime:Node3D=load("res://tools/world/police_movement_fixture.gd").new();world.add_child(crime);crime.player=player
	var station:=Node3D.new();world.add_child(station);crime.station=station
	var staff:=Node.new();staff.name="ThanaStaff";station.add_child(staff)
	var coordinator:=Coordinator.new();coordinator.name="ArrestCoordinator";staff.add_child(coordinator)
	await sync()
	var witnesses:Array[String]=["owner"]
	crime.record_incident("theft",player.position,witnesses,5);crime.recruit_visible_police()
	check(crime.patrols.size()==1,"real walker recruited before wall conceals suspect")
	var patrol:Dictionary=crime.patrols[0]
	var wall:=StaticBody3D.new();world.add_child(wall)
	var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(3,3,.5);wall_shape.shape=wall_box;wall_shape.position.y=1.5;wall.add_child(wall_shape)
	await sync()
	check(not crime.visible_to(actor),"wall removes sight before remembered search")
	var routed:=false;var crossed:=false
	for frame in 1800:
		await physics_frame
		if crime.navigate_patrol(patrol,Vector3(0,0,4),2.8,1.0/60.0):break
		if patrol.has("navigation") and not patrol.navigation.path.is_empty():routed=true
		if absf(actor.position.x)<1.77 and absf(actor.position.z)<.50:crossed=true
	check(routed,"blocked search receives budgeted obstacle route")
	check(actor.position.distance_to(Vector3(0,0,4))<.2 and not crossed,"police physically reach remembered location around wall")
	crime.advance_wanted(24,false)
	check(patrol.state=="return" and not actor.movement_enabled,"cleared stars retain officer until walk back")
	for frame in 2000:
		await physics_frame
		crime._tick(1.0/60.0)
		if crime.patrols.is_empty():break
	check(crime.patrols.is_empty() and actor.position.distance_to(Vector3(0,0,-4))<.2,"return route physically reaches original duty position")
	check(actor.movement_enabled and not actor.get_meta("external_combat_motion",true),"arrival restores original movement owner")
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	print("POLICE SEARCH NAVIGATION ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
