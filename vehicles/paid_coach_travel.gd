extends Node
const Routes = preload("res://vehicles/coach_routes.gd")
const FARE := 2
const STANDING := "Return to cart standing"
var boarding: Node
var graph: AStar2D
var path := PackedVector2Array()
var waypoint := 0
var destination := ""
var payer: CharacterBody3D
var skip_ui: CanvasLayer
var skip_mouse := Input.MOUSE_MODE_CAPTURED
var menu: CanvasLayer
var offered_to: CharacterBody3D
var previous_mouse := Input.MOUSE_MODE_CAPTURED
var stalled := 0.0
var last_position := Vector3.ZERO
var last_heading := 0.0
func configure(driver: Node) -> void: boarding = driver
func passenger_service() -> bool:
 return boarding.cart.has_method("show_coachman_blockout") or boarding.cart.get_meta("public_passenger_service",false)
func _unhandled_input(event: InputEvent) -> void:
 if boarding.cart.is_in_group("household_coach"): return
 if event.is_action_pressed("interact") and boarding.rider != null and boarding.role == "passenger" and boarding.transition == "" and payer == null and passenger_service():
  show_menu()
  get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
 if boarding.cart.is_in_group("household_coach"): return
 if payer != null and (boarding.rider != payer or boarding.transition == "exiting" or not boarding.cart.can_move()): cancel()
 if boarding.rider == null:
  offered_to = null
  close_menu()
 elif passenger_service() and boarding.role == "passenger" and boarding.transition == "" and offered_to != boarding.rider and payer == null:
  offered_to = boarding.rider
  show_menu()
func style_button(button: Button) -> void:
 for state in ["normal","hover","pressed","focus"]:
  var box := StyleBoxFlat.new()
  box.bg_color = Color(1,1,1,.07 if state in ["hover","focus"] else .025)
  box.content_margin_left = 10
  box.content_margin_right = 10
  box.content_margin_top = 6
  box.content_margin_bottom = 6
  button.add_theme_stylebox_override(state,box)
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
 var destinations: Array = Routes.STOPS.keys()
 if boarding.cart.has_meta("parking_bay"): destinations.append(STANDING)
 for place in destinations:
  var button := Button.new()
  style_button(button)
  button.text = str(place)+" · 2 rupees"
  button.pressed.connect(func(): request_trip(str(place)))
  list.add_child(button)
  if list.get_child_count() == 1: button.grab_focus()
 var cancel_button := Button.new()
 style_button(cancel_button)
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
func request_goal(goal: Vector2) -> bool:
 var nearest := ""
 var distance := 40.0
 for place in Routes.STOPS:
  var candidate: float = goal.distance_to(Routes.STOPS[place])
  if candidate < distance:
   nearest = str(place)
   distance = candidate
 return request_trip(nearest)
func request_trip(place: String) -> bool:
 return _begin_trip(place,false)
func resume_trip(place: String) -> bool:
 return _begin_trip(place,true)
func _begin_trip(place: String, already_paid: bool) -> bool:
 if boarding.cart.is_in_group("household_coach"): return false
 var actor: CharacterBody3D = boarding.rider
 if not passenger_service() or actor == null or boarding.role != "passenger" or boarding.transition != "" or payer != null or not boarding.cart.can_move(): return false
 if graph == null: graph = Routes.build()
 var start := Vector2(boarding.cart.global_position.x,boarding.cart.global_position.z)
 var route := PackedVector2Array()
 if place == STANDING:
  var bay = boarding.cart.get_meta("parking_bay",null)
  if not is_instance_valid(bay): return false
  bay.refresh_occupancy()
  if bay.occupant != null and bay.occupant != boarding.cart:
   actor.inventory.message_requested.emit("Cart standing occupied")
   return false
  route = Routes.route_to_point(graph,start,Vector2(bay.global_position.x,bay.global_position.z))
 else: route = Routes.route(graph,start,place)
 if route.is_empty():
  actor.inventory.message_requested.emit("No coach route from here")
  return false
 if not already_paid and actor.inventory.get_item_count("rupees") < FARE:
  actor.inventory.message_requested.emit("2 rupees needed")
  return false
 if not already_paid: actor.inventory.remove_item("rupees",FARE)
 payer = actor
 path = route
 waypoint = 0
 destination = place
 stalled = 0.0
 last_position = boarding.cart.global_position
 last_heading = boarding.cart.rotation.y
 close_menu()
 show_skip()
 return true
func controls(delta_seconds: float = 1.0/60.0) -> Vector2:
 if payer == null: return Vector2.ZERO
 if boarding.cart.global_position.distance_to(last_position) < .002 and absf(angle_difference(last_heading,boarding.cart.rotation.y)) < .0001:
  stalled += delta_seconds
 else: stalled = 0.0
 last_position = boarding.cart.global_position
 last_heading = boarding.cart.rotation.y
 if stalled > 8.0:
  payer.inventory.message_requested.emit("Road blocked · fare refunded")
  cancel()
  return Vector2.ZERO
 var at := Vector2(boarding.cart.global_position.x,boarding.cart.global_position.z)
 while waypoint < path.size() and at.distance_to(path[waypoint]) < (.35 if destination == STANDING and waypoint == path.size()-1 else 2.0): waypoint += 1
 if waypoint >= path.size():
  if destination == STANDING:
   var bay = boarding.cart.get_meta("parking_bay",null)
   if not is_instance_valid(bay): cancel(); return Vector2.ZERO
   var align := angle_difference(boarding.cart.global_rotation.y,bay.standing_heading)
   if absf(align) >= .12: return Vector2(0,clampf(align*3,-1,1))
   if not bay.try_dock(boarding.cart): return Vector2.ZERO
  finish_trip()
  return Vector2.ZERO
 var delta := path[waypoint]-at
 var heading := atan2(-delta.x,-delta.y)
 var turn := angle_difference(boarding.cart.rotation.y,heading)
 # Align before moving, then slow at bends; existing collision/ground probes apply.
 var throttle := .75
 if destination == STANDING and waypoint == path.size()-1:
  throttle = clampf(sqrt(2.0*boarding.ACCELERATION*maxf(delta.length()-.25,0))/boarding.FAST_SPEED,.04,.75)
 return Vector2(0.0 if absf(turn) > .55 else throttle,clampf(turn*3.0,-1.0,1.0))
func show_skip() -> void:
 if destination == STANDING: return
 skip_ui = CanvasLayer.new()
 add_child(skip_ui)
 var button := Button.new()
 style_button(button)
 button.text = "»"
 button.tooltip_text = "Skip journey"
 button.position = Vector2(35,160)
 button.size = Vector2(44,44)
 button.pressed.connect(skip_journey)
 skip_ui.add_child(button)
 button.grab_focus()
 skip_mouse = Input.mouse_mode
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_skip() -> void:
 if skip_ui == null: return
 skip_ui.queue_free()
 skip_ui = null
 Input.mouse_mode = skip_mouse

func finish_trip() -> void:
 payer.inventory.message_requested.emit(destination)
 var service:Node=boarding.cart.get_node_or_null("PublicPassengerService")
 if service!=null and destination!=STANDING:service.announce_arrival(destination)
 payer = null
 path.clear()
 boarding.speed = 0.0
 close_skip()

func skip_journey() -> bool:
 if destination == STANDING: return false
 if payer == null or path.is_empty() or boarding.transition != "" or not boarding.cart.can_move(): return false
 var goal: Vector2 = path[-1]
 var old_heading: float = boarding.cart.rotation.y
 if path.size() > 1:
  var direction: Vector2 = path[-1]-path[-2]
  if direction.length_squared() > .001: boarding.cart.rotation.y = atan2(-direction.x,-direction.y)
 var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
 var at := Vector3(goal.x,layout.height(goal.x,goal.y),goal.y)
 var probe := PhysicsRayQueryParameters3D.create(at+Vector3.UP*3.0,at-Vector3.UP*3.0)
 probe.exclude = boarding._vehicle_exclusions()
 var hit: Dictionary = boarding.cart.get_world_3d().direct_space_state.intersect_ray(probe)
 if hit.is_empty() or not boarding._clearance_at(Vector3(goal.x,hit.position.y,goal.y)):
  boarding.cart.rotation.y = old_heading
  payer.inventory.message_requested.emit("The arrival point is blocked. Continue the journey or try again.")
  return false
 boarding.cart.global_position = Vector3(goal.x,hit.position.y,goal.y)
 boarding._sync_rider()
 boarding.cart.set_forward_motion(0.0,0.0)
 finish_trip()
 return true

func cancel() -> void:
 close_skip()
 if is_instance_valid(payer): payer.inventory.add_item("rupees",FARE)
 payer = null
 path.clear()
 boarding.speed = 0.0
 close_menu()
