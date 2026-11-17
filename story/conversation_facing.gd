extends Node
## Late visual facing for active dialogue only; movement/combat regain control immediately.
var actor: Node3D
var target:=Vector3.ZERO
var through_frame: int=-1
static func toward(person: Node3D, point: Vector3) -> void:
	if not is_instance_valid(person):return
	var solver: Node=person.get_node_or_null("ConversationFacing")
	if solver==null:
		solver=load("res://story/conversation_facing.gd").new();solver.name="ConversationFacing";solver.actor=person;person.add_child(solver)
	solver.set_process(true);solver.target=point;solver.through_frame=Engine.get_process_frames()+1
	solver.apply()
static func release(person: Node3D) -> void:
	if not is_instance_valid(person):return
	var solver:=person.get_node_or_null("ConversationFacing")
	if solver!=null:solver.through_frame=-1;solver.set_process(false)
static func pair(first: Node3D, second: Node3D) -> void:
	if not is_instance_valid(first) or not is_instance_valid(second):return
	toward(first,second.global_position);toward(second,first.global_position)
func _ready() -> void:process_priority=1000
func _process(_delta: float) -> void:
	if Engine.get_process_frames()<=through_frame:apply()
	else:set_process(false)
func apply() -> void:
	if not is_instance_valid(actor):return
	var body: Node3D=actor.get_node_or_null("VisualRoot")
	if body==null:body=actor
	var offset:=target-actor.global_position;offset.y=0
	if offset.length_squared()>.0025:body.global_rotation.y=atan2(offset.x,offset.z)
