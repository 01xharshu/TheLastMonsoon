extends Node
## World-owned local-search queue; physics queries remain on the main thread.
const BUDGET_USEC:=1500
var requests: Array[Dictionary]=[]
var draining:=false
var frame_start:=0
var work_frame:=-1

static func request(owner_node: Node, actor: Node3D, goal: Vector3, extra_excluded:Array[RID]=[]) -> bool:
	var world:=preload("res://systems/world_context.gd").find_world(actor)
	if world==null:return false
	var service:=world.get_node_or_null("NavigationWorkQueue")
	if service==null:
		service=load("res://systems/navigation_work_queue.gd").new();service.name="NavigationWorkQueue";world.add_child(service)
	service.enqueue(owner_node,actor,goal,extra_excluded)
	return true

func enqueue(owner_node: Node, actor: Node3D, goal: Vector3, extra_excluded:Array[RID]=[]) -> void:
	for request in requests:
		if request.owner.get_ref()==owner_node:
			request.actor=weakref(actor);request.goal=goal;request.excluded=extra_excluded.duplicate()
			return
	requests.append({"owner":weakref(owner_node),"actor":weakref(actor),"goal":goal,"excluded":extra_excluded.duplicate()})
	if not draining:
		draining=true;drain.call_deferred()

func checkpoint() -> bool:
	if not is_inside_tree() or is_queued_for_deletion():return false
	var frame:=Engine.get_physics_frames()
	if frame!=work_frame:work_frame=frame;frame_start=Time.get_ticks_usec()
	if Time.get_ticks_usec()-frame_start>=BUDGET_USEC:
		await get_tree().physics_frame
		if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion():return false
		work_frame=Engine.get_physics_frames();frame_start=Time.get_ticks_usec()
	return true

func drain() -> void:
	while not requests.is_empty():
		if not is_inside_tree() or is_queued_for_deletion():break
		var request: Dictionary=requests.pop_front()
		var actor: Node3D=request.actor.get_ref()
		var owner_node: Node=request.owner.get_ref()
		if not is_instance_valid(actor) or not is_instance_valid(owner_node):continue
		await get_tree().physics_frame
		if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion():return
		if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not is_instance_valid(owner_node) or owner_node.is_queued_for_deletion():continue
		var path: Array[Vector3]=await preload("res://world/suryagarh/settlements/resident_walk_route.gd").find_budgeted(actor,request.goal,self,request.excluded)
		if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion():return
		if is_instance_valid(owner_node) and owner_node.is_inside_tree() and not owner_node.is_queued_for_deletion():owner_node.call("receive_navigation",path,request.goal)
	draining=false
