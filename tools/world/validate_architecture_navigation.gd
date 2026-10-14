extends "res://tools/world/validate_crime_perception.gd"
const Walk=preload("res://world/suryagarh/settlements/resident_walk_route.gd")
class ClearanceProbe extends Node3D:
	# Invisible physics query fixture, not a human asset or gameplay placeholder.
	var body_collider:=AnimatableBody3D.new()
	func _ready() -> void:
		body_collider.collision_layer=8;body_collider.sync_to_physics=false;add_child(body_collider)
		var shape:=CollisionShape3D.new();shape.name="BodyShape";shape.shape=CapsuleShape3D.new()
		shape.shape.radius=.24;shape.shape.height=1.6;shape.position.y=.8;body_collider.add_child(shape)
class Receiver extends Node:
	var result: Array[Vector3]=[]
	var received:=false
	func receive_navigation(path: Array[Vector3],_goal: Vector3) -> void:result=path;received=true
func run() -> void:
	create_timer(30).timeout.connect(func():root.get_node("SaveManager").quit_game(2))
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:=GameTimeSystem.new();clock.name="GameTimeSystem";world.add_child(clock);clock.set_process(false)
	var floor_body:=StaticBody3D.new();world.add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(60,.2,60);floor_shape.position.y=-.1;floor_body.add_child(floor_shape)
	var actor:=ClearanceProbe.new();world.add_child(actor)
	var wall:=StaticBody3D.new();wall.position=Vector3(0,1,2);world.add_child(wall)
	var wall_shape:=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(3,2,.3);wall.add_child(wall_shape)
	await sync()
	var path:=Walk.find(actor,Vector3(0,0,4))
	check(not path.is_empty() and path[-1]==Vector3(0,0,4),"local heap search reaches goal around wall")
	var detours:=false
	for point in path:
		if absf(point.x)>1.6:detours=true
	check(detours,"navigation does not cut through wall")
	var receiver:=Receiver.new();world.add_child(receiver)
	preload("res://systems/navigation_work_queue.gd").request(receiver,actor,Vector3(0,0,4))
	var frames:=0
	while not receiver.received and frames<180:
		await physics_frame;frames+=1
	check(receiver.received and receiver.result==path,"queued search preserves synchronous collision-checked path")
	check(frames>0,"search executes through physics scheduling rather than caller tick")
	var pending_owner:=Receiver.new();world.add_child(pending_owner)
	preload("res://systems/navigation_work_queue.gd").request(pending_owner,actor,Vector3(15,0,15))
	pending_owner.queue_free()
	for frame in 3:await physics_frame
	check(world.has_node("NavigationWorkQueue"),"destroyed request owner does not destroy shared service")
	var removed_actor:=ClearanceProbe.new();world.add_child(removed_actor)
	var survivor:=Receiver.new();world.add_child(survivor)
	preload("res://systems/navigation_work_queue.gd").request(survivor,removed_actor,Vector3(5,0,5))
	removed_actor.queue_free()
	for frame in 3:await physics_frame
	check(not survivor.received,"actor removed before deferred search is cancelled safely")
	preload("res://systems/navigation_work_queue.gd").request(survivor,actor,Vector3(0,0,4))
	frames=0
	while not survivor.received and frames<180:await physics_frame;frames+=1
	check(survivor.received and survivor.result==path,"queue continues after cancelled actor request")
	survivor.received=false
	preload("res://systems/navigation_work_queue.gd").request(survivor,actor,Vector3(29,0,29))
	await physics_frame
	survivor.reparent(root)
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	check(not survivor.received,"world teardown cancels pending search without a late callback")
	survivor.queue_free()
	print("ARCHITECTURE NAVIGATION ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
