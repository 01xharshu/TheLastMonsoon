extends Interactable
## Keeper presents the counter book before control moves to its overhead page.
const Actions = preload("res://systems/action_permissions.gd")
const LedgerView = preload("res://ui/provision_ledger.gd")

var keeper: Node3D
var ledger: Node3D
var buyer: CharacterBody3D
var view: Control
var permissions: Node
var lease := -1
var elapsed := 0.0
var owns_pause := false
var prior_mouse := Input.MOUSE_MODE_CAPTURED
var rest_book_position: Vector3

func _ready() -> void:
	interaction_text = "Ask shopkeeper for the ledger"
	interaction_icon = "loot"
	interaction_max_distance = 2.25
	marker_height = .13
	collision_layer = 0
	collision_mask = 0
	rest_book_position = ledger.position
	set_process(false)
	set_process_input(false)

func interaction_available() -> bool:
	return super.interaction_available() and lease < 0 and is_instance_valid(keeper) \
		and not keeper.get_meta("dead",false) and not keeper.get_meta("knocked_out",false)

func interact(player: CharacterBody3D) -> void:
	if not interaction_available() or player.health <= 0.0 or get_tree().paused:
		return
	if player.global_position.distance_to(global_position) > interaction_max_distance \
		or to_local(player.global_position).x <= 0.0 or player.get_meta("provision_shop_open",false) \
		or not Actions.allowed(player,&"interact"):
		return
	permissions = Actions.install(player)
	var domains: Array[StringName] = [&"move",&"attack",&"interact",&"board"]
	lease = permissions.acquire(self,domains)
	if lease < 0:
		return
	buyer = player
	elapsed = 0.0
	buyer.set_meta("provision_shop_open",true)
	# The keeper updates its animation first, then the counter applies the reach.
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	if not is_instance_valid(buyer) or buyer.health <= 0.0 \
		or buyer.global_position.distance_to(global_position) > interaction_max_distance \
		or not is_instance_valid(keeper) or keeper.get_meta("dead",false) or keeper.get_meta("knocked_out",false):
		close_shop()
		return
	elapsed += delta
	var reach := smoothstep(0.0,.28,elapsed)
	var slide := smoothstep(.28,.64,elapsed)
	ledger.position = rest_book_position + Vector3(.08*slide,0,0)
	if keeper._skeleton != null:
		var edge := ledger.to_global(Vector3(-.195,.068,-.13))
		keeper.solve_hand_contact("l",keeper.palm_world("l").lerp(edge,reach))
	if elapsed >= .74:
		open_book()

func open_book() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	view = LedgerView.new()
	layer.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.balance = buyer.inventory.get_item_count("rupees")
	prior_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_process(false)
	owns_pause = true
	get_tree().paused = true
	# This node's input needs to receive Escape while the world is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_shop()
		return
	get_viewport().set_input_as_handled()
	if not is_instance_valid(view):
		return
	match event.keycode:
		KEY_UP, KEY_W:
			view.browse(-1)
		KEY_DOWN, KEY_S:
			view.browse(1)
		KEY_LEFT, KEY_PAGEUP:
			view.turn_page(-1)
		KEY_RIGHT, KEY_PAGEDOWN:
			view.turn_page(1)
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				buy_selected()
	view.queue_redraw()

func buy_selected() -> bool:
	if not is_instance_valid(view) or view.turning or not is_instance_valid(buyer) or buyer.health <= 0.0:
		return false
	var item: Dictionary = LedgerView.STOCK[view.selected]
	var inventory: Node = buyer.inventory
	if item.get("unique",false) and inventory.has_item(item.id):
		view.receipt = "Already in your satchel."
		return false
	if not inventory.remove_item("rupees",item.price):
		view.receipt = "Insufficient rupees."
		return false
	inventory.add_item(item.id,item.get("quantity",1))
	view.balance = inventory.get_item_count("rupees")
	view.receipt = "Purchased · %s" % item.get("label",LedgerView.Catalog.display_name(item.id))
	return true

func close_shop() -> void:
	set_process(false)
	set_process_input(false)
	if is_instance_valid(view):
		view.get_parent().queue_free()
		view.get_parent().hide()
		view = null
	if owns_pause:
		get_tree().paused = false
		Input.mouse_mode = prior_mouse
		owns_pause = false
		process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(ledger):
		ledger.position = rest_book_position
	if is_instance_valid(permissions):
		permissions.release(lease)
	if is_instance_valid(buyer):
		buyer.set_meta("provision_shop_open",false)
	buyer = null
	lease = -1

func _exit_tree() -> void:
	if lease >= 0:
		close_shop()
