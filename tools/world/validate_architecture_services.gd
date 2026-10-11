extends "res://tools/world/validate_crime_perception.gd"
const Actions=preload("res://systems/action_permissions.gd")
const Identity=preload("res://systems/entity_identity.gd")
const Objectives=preload("res://systems/objective_resolver.gd")
const Roads=preload("res://vehicles/coach_routes.gd")
class JobProvider extends Node:
	var active:=""
	func destination() -> Dictionary:return {"position":Vector3(2,0,2),"label":"Job","endpoint":"job"}
	func tracked_objective() -> String:return "Deliver goods"
class StoryProvider extends Node:
	var stage:="dormant"
	func destination() -> Dictionary:return {} if stage=="cinematic" else {"position":Vector3(5,0,5),"label":"Story","endpoint":""}
	func objective() -> String:return "Reach hideout"
class WorldFixture extends Node3D:
	var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
class MapChoice extends Node:
	var follow_story:=false
	var waypoint:=Vector2(40,40)
	var selected_site:="Custom destination"
func run() -> void:
	var world:=WorldFixture.new();root.add_child(world);current_scene=world
	var actor:=Node3D.new();actor.name="Player";world.add_child(actor)
	var service:=Actions.install(actor)
	var owner_node:=Node.new();world.add_child(owner_node)
	var domains:Array[StringName]=[&"attack",&"board"]
	var token:int=service.acquire(owner_node,domains)
	check(token>=0 and not Actions.allowed(actor,&"attack") and not Actions.allowed(actor,&"board"),"shared lease blocks weapons and boarding")
	check(service.acquire(owner_node,domains)==-1,"conflicting lease is rejected")
	service.release(token);check(Actions.allowed(actor,&"attack"),"successful action releases permissions")
	token=service.acquire(owner_node,domains);owner_node.queue_free();await process_frame
	check(Actions.allowed(actor,&"attack"),"deleted action owner releases stale lease")
	actor.set_meta("story_cinematic",true);check(not Actions.allowed(actor,&"board"),"cinematic cannot start a competing board action")
	actor.remove_meta("story_cinematic")
	var entity:=Node3D.new();entity.name="Cart";entity.set_meta("entity_id","vehicle:test");world.add_child(entity);entity.add_to_group("live_travel_carts")
	var state:Dictionary={"entity_id":Identity.id_for(world,entity),"path":"old/path"}
	var folder:=Node3D.new();world.add_child(folder);entity.reparent(folder)
	check(Identity.resolve(world,state,Identity.index_group(world,&"live_travel_carts"))==entity,"authored entity ID survives reparenting")
	check(Identity.resolve(world,{"path":str(world.get_path_to(entity))},{})==entity,"legacy path still resolves")
	var jobs:=JobProvider.new();jobs.name="ErrandSystem";world.add_child(jobs)
	var story:=StoryProvider.new();story.name="RebellionStory";world.add_child(story)
	jobs.active="delivery"
	check(Objectives.resolve(actor).owner=="errand","errand objective selected")
	story.stage="return";check(Objectives.resolve(actor).owner=="rebellion","rebellion priority shared by guidance")
	actor.set_meta("morning_tutorial_active",true);check(Objectives.resolve(actor).is_empty(),"tutorial suppresses competing objectives")
	actor.remove_meta("morning_tutorial_active");story.stage="cinematic"
	check(Objectives.resolve(actor).is_empty(),"active story with no destination does not leak lower objective")
	story.stage="complete";check(Objectives.resolve(actor).owner=="errand","completed rebellion releases errand guidance")
	jobs.active="";check(Objectives.resolve(actor,false).is_empty() and Objectives.resolve(actor).owner=="manual","manual destination excluded from auto map sync")
	var ui:=Node.new();ui.name="UI";actor.add_child(ui)
	var map:=MapChoice.new();map.name="WorldMap";ui.add_child(map)
	story.stage="return"
	check(Objectives.resolve(actor).owner=="manual" and Objectives.resolve(actor,false).owner=="rebellion","explicit custom waypoint overrides presentation without losing mission tracking")
	map.follow_story=true
	check(Objectives.resolve(actor).owner=="rebellion","following story restores shared mission priority")
	var graph:=Roads.build(world)
	check(Roads.build(world)==graph,"all coach owners reuse world graph")
	var ids:=graph.get_point_ids()
	var parity:=true
	for i in ids.size():
		for j in range(i+1,ids.size()):
			var close:bool=graph.get_point_position(ids[i]).distance_to(graph.get_point_position(ids[j]))<11.0
			if close and not graph.are_points_connected(ids[i],ids[j]):parity=false
	check(parity,"spatial road linking preserves every original proximity edge")
	var reached:=true
	for from in Roads.STOPS.values():
		for to in Roads.STOPS.keys():
			if Roads.route(graph,from,to).is_empty():reached=false
	check(reached,"coach stop pairs retain routes")
	await spatial_checks(world)
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	print("ARCHITECTURE SERVICES ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
func spatial_checks(world: Node3D) -> void:
	var items:Array[Node]=[]
	for i in 1000:
		var item:=Interactable.new();world.add_child(item);item.position=Vector3(1000+i*20,0,1000);items.append(item)
	var near:=Interactable.new();world.add_child(near);near.position=Vector3(2,0,2)
	var index:=preload("res://systems/interaction_spatial_index.gd").new();world.add_child(index)
	await process_frame
	var selected: Array[Node]=index.candidates(Vector3.ZERO,13)
	check(selected.has(near) and selected.size()<10,"spatial broad phase selects nearby objects without distant enumeration")
	var moving: Node3D=items[0]
	moving.position=Vector3(1,0,1)
	check(index.candidates(Vector3.ZERO,13).has(moving),"teleport into range updates spatial membership immediately")
	moving.position=Vector3(2000,0,2000);moving.force_update_transform()
	check(not index.candidates(Vector3.ZERO,13).has(moving),"teleport out of range clears old spatial membership")
	var removed_id:=near.get_instance_id()
	near.queue_free();await process_frame
	check(not index.records.has(removed_id),"removed objects leave spatial registry")
	# Registration order is preserved for equal-score selector ties.
	var ordered:Array[Node]=[]
	for i in 3:
		var item:=Interactable.new();world.add_child(item);item.position=Vector3(i,0,0);ordered.append(item)
	await process_frame
	check(index.candidates(Vector3.ZERO,13)==ordered,"nearby candidate registration order remains stable")
	world.move_child(ordered[2],0)
	var reordered:Array[Node]=[ordered[2],ordered[0],ordered[1]]
	check(index.candidates(Vector3.ZERO,13)==reordered,"scene-tree reorder preserves equal-score group selection order")
