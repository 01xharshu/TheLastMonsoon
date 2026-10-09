extends SceneTree
const Startup = preload("res://systems/world_startup.gd")
var failed := false
var sequence: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error(message)
func producer(node: Node, task: int) -> void:
	await Startup.checkpoint(node,"Preparing a test fixture",true)
	sequence.append("geometry")
	Startup.finish(task)
func dependent(node: Node, task: int) -> void:
	await Startup.wait_for(node,"Geometry")
	sequence.append("operations")
	Startup.finish(task)
func run() -> void:
	var node := Node.new()
	root.add_child(node)
	var session := Startup.start(self)
	var producer_task := Startup.begin("Geometry")
	var dependent_task := Startup.begin("Operations")
	var world_task := Startup.begin("World")
	producer(node,producer_task)
	dependent(node,dependent_task)
	await Startup.wait_others(node,world_task)
	check(sequence == ["geometry","operations"],"Startup dependency order changed")
	check(session.tasks.size() == 1 and session.tasks.has(world_task),"Startup barrier released early")
	check(session.checkpoints > 0,"Startup never yielded a frame")
	Startup.finish(world_task)
	Startup.close(session)
	check(Startup.current == null,"Startup session remained active")
	var before := Engine.get_process_frames()
	await Startup.checkpoint(node,"Outside startup",true)
	check(Engine.get_process_frames() == before,"Direct scene construction became asynchronous")
	print("STARTUP BARRIER ","FAIL" if failed else "PASS")
	await root.get_node("SaveManager").quit_game(1 if failed else 0)
