extends Node
## Independent lesson/read/write/discussion phases on existing college residents.
const Budget = preload("res://systems/simulation_budget.gd")
const Props = preload("res://world/suryagarh/settlements/activity_props.gd")
var person: Node3D
var offset := 0.0
var elapsed := 0.0
var pending_time := 0.0
var viewer: Node3D
var book: Node3D
var pen: Node3D
var home := Vector3.ZERO

func _ready() -> void:
	add_to_group("independent_npc_activities")
	process_priority=5
	var world := preload("res://systems/world_context.gd").find_world(self)
	if world!=null:viewer=world.get_node_or_null("Player")
	person.set_process(false)
	home=person.position
	book=Node3D.new();book.name="StudyBook";person.add_child(book)
	Props.box(book,"BoundCover",Vector3.ZERO,Vector3(.28,.025,.20),Props.material(Color(.25,.17,.10)))
	Props.box(book,"PaperLeaves",Vector3(0,.017,0),Vector3(.26,.012,.185),Props.material(Color(.74,.69,.54)))
	pen=Props.cylinder(person,"WritingReed",Vector3.ZERO,.003,.18,Props.material(Color(.32,.20,.08)))
	preload("res://world/suryagarh/settlements/activity_save.gd").apply_late(self)

func _process(delta: float) -> void:
	pending_time+=delta
	if pending_time<Budget.interval(person,viewer,person.get_meta("mission_active",false)):return
	var step:=pending_time;pending_time=0.0
	tick(step)

func tick(delta: float) -> void:
	if person.get_meta("dead",false) or person.get_meta("knocked_out",false) or person.get_meta("civilian_reacting",false):
		# Put study materials at the assigned seat rather than letting them
		# follow an unbound hand through the escape or fall animation.
		book.top_level=true;pen.top_level=true
		var support:=person.get_parent_node_3d().to_global(home+Vector3(0,.46,.30))
		book.global_transform=Transform3D(Basis.IDENTITY,support)
		pen.global_transform=Transform3D(Basis(Vector3.FORWARD,PI*.5),support+Vector3(0,.05,0))
		return
	book.top_level=false;pen.top_level=false
	book.rotation=Vector3.ZERO;pen.rotation=Vector3.ZERO
	elapsed+=delta
	var role: String=person.get_meta("world_role","student")
	var phase:=fposmod(elapsed+offset,42.0)
	var action: String="teach" if role=="lecturer" else ("read" if phase<15 else "write" if phase<29 else "talk" if phase<35 else "listen")
	var speaking: bool=action in ["teach","talk"] and fposmod(elapsed+offset,6.0)<4.5
	person.perform(action,delta,speaking)
	book.visible=action in ["read","write","teach"]
	pen.visible=action=="write"
	if action in ["read","write"] and person.activity_age<.8:
		book.hide();pen.hide();person.finish_contacts();return
	book.position=Vector3(0,.70,.34) if action!="teach" else Vector3(-.22,1.03,.24)
	if action=="read":
		for side in ["l","r"]:
			person.solve_hand_contact(side,book.to_global(Vector3(.12 if side=="l" else -.12,.025,0)))
			person.set_grip(side,.12)
	elif action=="write":
		pen.position=Vector3(.10+.045*sin(elapsed*2.7),.755,.33+.015*cos(elapsed*4.0))
		pen.rotation=Vector3(.5,0,-.25)
		person.solve_hand_contact("r",pen.to_global(Vector3(0,.025,0)))
		person.solve_hand_contact("l",book.to_global(Vector3(-.11,.025,0)))
		person.set_grip("r",.35)
	elif action=="teach":
		person.solve_hand_contact("l",book.to_global(Vector3(0,-.015,0)))
	person.finish_contacts()
	person.set_meta("college_action",action)

func export_state() -> Dictionary:return {"elapsed":elapsed,"offset":offset}
func restore_state(data: Dictionary) -> void:
	if data.is_empty():return
	elapsed=maxf(0,float(data.get("elapsed",elapsed)));offset=float(data.get("offset",offset));tick(0)
