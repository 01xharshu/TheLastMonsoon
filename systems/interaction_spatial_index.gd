extends Node
## One world-owned broad phase. Final anchor/range/occlusion rules stay unchanged.
const CELL_SIZE:=16.0
var cells: Dictionary={}
var records: Dictionary={}
var pending: Array[Node]=[]
var maximum_reach:=0.0
var maximum_anchor_extent:=0.0
var sequence:=0

func _ready() -> void:
	get_tree().node_added.connect(_added)
	for subject in get_tree().get_nodes_in_group("interactables"): _added(subject)

func _added(subject: Node) -> void:
	if subject is Interactable and get_parent().is_ancestor_of(subject):
		pending.append(subject)
		flush.call_deferred()

func flush() -> void:
	var waiting:=pending
	pending=[]
	for subject in waiting:
		if not is_instance_valid(subject) or subject.is_queued_for_deletion() or not subject.is_inside_tree(): continue
		if not subject.is_node_ready(): pending.append(subject);continue
		var identity:=subject.get_instance_id()
		if records.has(identity):continue
		sequence+=1
		records[identity]={"node":weakref(subject),"cell":Vector2i(2147483647,2147483647),"order":sequence}
		maximum_reach=maxf(maximum_reach,subject.interaction_max_distance)
		var extent:float=subject.interaction_anchor().distance_to(subject.global_position)
		if subject.is_in_group("house_doors") and subject.get("width")!=null: extent=maxf(extent,float(subject.get("width"))*2.0+float(subject.get("height")))
		maximum_anchor_extent=maxf(maximum_anchor_extent,extent)
		subject.set_meta("interaction_spatial_index",self)
		update_subject(subject)

func cell_for(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x/CELL_SIZE),floori(at.z/CELL_SIZE))

func update_subject(subject: Node3D) -> void:
	var identity:=subject.get_instance_id()
	if not records.has(identity):return
	var next:=cell_for(subject.global_position)
	var previous: Vector2i=records[identity].cell
	if previous==next:return
	if cells.has(previous):
		cells[previous].erase(identity)
		if cells[previous].is_empty():cells.erase(previous)
	if not cells.has(next):cells[next]=[]
	cells[next].append(identity);records[identity].cell=next

func remove_subject(identity: int) -> void:
	if not records.has(identity):return
	var cell: Vector2i=records[identity].cell
	if cells.has(cell):
		cells[cell].erase(identity)
		if cells[cell].is_empty():cells.erase(cell)
	records.erase(identity)

func candidates(at: Vector3, marker_range := 0.0) -> Array[Node]:
	flush()
	var radius:=maxf(maximum_reach,marker_range)+maximum_anchor_extent
	var first:=cell_for(at-Vector3(radius,0,radius))
	var last:=cell_for(at+Vector3(radius,0,radius))
	var selected:Array[Dictionary]=[]
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):
			for identity in cells.get(Vector2i(x,z),[]):
				var entry: Dictionary=records[identity]
				var subject: Node=entry.node.get_ref()
				if is_instance_valid(subject) and not subject.is_queued_for_deletion():selected.append(entry)
	# Godot group enumeration uses scene-tree order, including later reparenting.
	selected.sort_custom(func(a,b):return b.node.get_ref().is_greater_than(a.node.get_ref()))
	var result:Array[Node]=[]
	for entry in selected:result.append(entry.node.get_ref())
	return result
