extends RefCounted
## Scoped to a title-menu load. Direct scene/editor checks retain synchronous setup.
static var current: RefCounted
const BUDGET_US := 8000

class Session extends RefCounted:
	var tasks: Dictionary = {}
	var next_id := 0
	var frame := -1
	var frame_start := 0
	var stage := "Preparing the world…"
	var checkpoints := 0
	var tree: SceneTree

static func start(tree: SceneTree) -> RefCounted:
	var session := Session.new()
	session.tree = tree
	current = session
	return session

static func begin(label: String) -> int:
	if current == null: return -1
	current.next_id += 1
	current.tasks[current.next_id] = label
	return current.next_id

static func finish(id: int) -> void:
	if current != null and id >= 0: current.tasks.erase(id)

static func checkpoint(node: Node, label: String = "", force: bool = false) -> void:
	if current == null: return
	var session: RefCounted = current
	if not label.is_empty(): session.stage = label
	var frame := Engine.get_process_frames()
	if session.frame != frame:
		session.frame = frame
		session.frame_start = Time.get_ticks_usec()
	if not force and Time.get_ticks_usec() - session.frame_start < BUDGET_US: return
	session.checkpoints += 1
	await node.get_tree().process_frame
	# Charge all resumed builders against the same frame budget, including the
	# work between their first resume and their first subsequent checkpoint.
	var resumed_frame := Engine.get_process_frames()
	if session.frame != resumed_frame:
		session.frame = resumed_frame
		session.frame_start = Time.get_ticks_usec()

static func wait_for(node: Node, label: String) -> void:
	while current != null and label in current.tasks.values():
		await node.get_tree().process_frame

static func wait_others(node: Node, own_id: int) -> void:
	while current != null and (current.tasks.size() > 1 or (current.tasks.size() == 1 and not current.tasks.has(own_id))):
		await node.get_tree().process_frame

static func close(session: RefCounted) -> void:
	if current == session: current = null
