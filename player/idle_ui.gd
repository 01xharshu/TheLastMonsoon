extends Node
## A canvas fade preserves tutorial pulses, owner visibility and button state.
var opacity := 1.0
var layers: Array[CanvasLayer] = []
var watching := false
@onready var component: Node = get_parent()
@onready var world: Node = component.get_parent().get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100

func _input(event: InputEvent) -> void:
	# This also runs while paused, when the character's input owner is suspended.
	if component.is_activity(event): component.cancel()

func _process(delta: float) -> void:
	if get_tree().paused:
		# Pause/menu owners may handle the event before gameplay input receives it.
		if component.elapsed > 0.0: component.cancel()
		restore()
		return
	if component.elapsed < component.look_after:
		restore()
		return
	if not component.eligible():
		component.cancel()
		restore()
		return
	if not watching:
		watching = true
		for node in world.find_children("*","CanvasLayer",true,false): _include(node)
		get_tree().node_added.connect(_node_added)
	var previous := opacity
	opacity = move_toward(opacity,0.0,delta/maxf(component.ui_fade_seconds,.01))
	if opacity != previous: _apply()

func _node_added(node: Node) -> void:
	if node is CanvasLayer: _include.call_deferred(node)

func _include(node: Node) -> void:
	if not watching or not is_instance_valid(node) or not node is CanvasLayer or not world.is_ancestor_of(node): return
	var layer := node as CanvasLayer
	if layer.name == "GameMenu" or layer.layer < 0: return
	if not layers.has(layer): layers.append(layer)
	RenderingServer.canvas_set_modulate(layer.get_canvas(),Color(1,1,1,opacity))

func _apply() -> void:
	for layer in layers:
		if is_instance_valid(layer) and layer.is_inside_tree():
			RenderingServer.canvas_set_modulate(layer.get_canvas(),Color(1,1,1,opacity))

func restore() -> void:
	if not watching and opacity == 1.0: return
	opacity = 1.0
	_apply()
	layers.clear()
	if watching and get_tree() != null and get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	watching = false

func _exit_tree() -> void:
	restore()
