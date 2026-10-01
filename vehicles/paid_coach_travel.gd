extends Node
const Routes = preload("res://vehicles/coach_routes.gd")
const FARE := 2
var boarding: Node
var graph: AStar2D
var path := PackedVector2Array()
var waypoint := 0
var destination := ""
var payer: CharacterBody3D
var menu: CanvasLayer
var offered_to: CharacterBody3D
var previous_mouse := Input.MOUSE_MODE_CAPTURED
func configure(driver: Node) -> void: boarding = driver
func _process(_delta: float) -> void:
 if payer != null and (boarding.rider != payer or boarding.transition == "exiting" or not boarding.cart.can_move()): cancel()
 if boarding.rider == null:
  offered_to = null
  close_menu()
 elif boarding.role == "passenger" and boarding.transition == "" and offered_to != boarding.rider and payer == null:
  offered_to = boarding.rider
  show_menu()
func show_menu() -> void:
 if menu != null: return
 menu = CanvasLayer.new()
 add_child(menu)
 var panel := PanelContainer.new()
 panel.position = Vector2(35,160)
 menu.add_child(panel)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(.035,.03,.025,.88)
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 12
 style.content_margin_bottom = 12
 panel.add_theme_stylebox_override("panel",style)
 var list := VBoxContainer.new()
 panel.add_child(list)
 for place in Routes.STOPS:
  var button := Button.new()
  button.text = str(place)+" · 2 rupees"
  button.pressed.connect(func(): request_trip(str(place)))
  list.add_child(button)
 var cancel_button := Button.new()
 cancel_button.text = "×"
 cancel_button.pressed.connect(close_menu)
 list.add_child(cancel_button)
 previous_mouse = Input.mouse_mode
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func close_menu() -> void:
 if menu == null: return
 menu.queue_free()
 menu = null
 Input.mouse_mode = previous_mouse
func request_trip(place: String) -> bool:
 var actor: CharacterBody3D = boarding.rider
 if actor == null or boarding.role != "passenger" or boarding.transition != "" or payer != null or not boarding.cart.can_move(): return false
 if graph == null: graph = Routes.build()
 var route := Routes.route(graph,Vector2(boarding.cart.global_position.x,boarding.cart.global_position.z),place)
 if route.is_empty():
  actor.inventory.message_requested.emit("No coach route from here")
  return false
 if actor.inventory.get_item_count("rupees") < FARE:
  actor.inventory.message_requested.emit("2 rupees needed")
  return false
 actor.inventory.remove_item("rupees",FARE)
 payer = actor
 path = route
 waypoint = 0
 destination = place
 close_menu()
 return true
func controls() -> Vector2:
 if payer == null: return Vector2.ZERO
 var at := Vector2(boarding.cart.global_position.x,boarding.cart.global_position.z)
 while waypoint < path.size() and at.distance_to(path[waypoint]) < 2.0: waypoint += 1
 if waypoint >= path.size():
  payer.inventory.message_requested.emit(destination)
  payer = null
  path.clear()
  boarding.speed = 0.0
  return Vector2.ZERO
 var delta := path[waypoint]-at
 var heading := atan2(-delta.x,-delta.y)
 var turn := angle_difference(boarding.cart.rotation.y,heading)
 # Align before moving, then slow at bends; existing collision/ground probes apply.
 return Vector2(0.0 if absf(turn) > .55 else .75,clampf(turn*3.0,-1.0,1.0))
func cancel() -> void:
 if is_instance_valid(payer): payer.inventory.add_item("rupees",FARE)
 payer = null
 path.clear()
 boarding.speed = 0.0
 close_menu()
