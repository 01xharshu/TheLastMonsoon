extends Camera3D
## Fixed rear passenger eye. Mouse/controller input moves an independent aim point.
var player:CharacterBody3D
var previous:Camera3D
var pointer:=Vector2(.5,.5)
func _ready() -> void:
 name="ConsignmentFirstPerson";process_priority=95;near=.05;fov=72
 position=Vector3(0,2.18,4.02);rotation=Vector3(0,PI,0)
 previous=get_viewport().get_camera_3d()
 player.set_meta("consignment_fpv_camera",self);player.set_meta("consignment_aim_uv",pointer)
 make_current()
func accepts_input() -> bool:
 return current and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not player.get_meta("map_open",false) and not player.get_meta("weapon_wheel_open",false) and not player.inventory_ui.is_open()
func move_pointer(motion:Vector2) -> void:
 pointer=(pointer+motion).clamp(Vector2(.20,.23),Vector2(.80,.77))
 player.set_meta("consignment_aim_uv",pointer)
func _input(event:InputEvent) -> void:
 if accepts_input() and event is InputEventMouseMotion:
  move_pointer(event.relative/ get_viewport().get_visible_rect().size * (player.mouse_sensitivity/.0025))
func _process(delta:float) -> void:
 if accepts_input():move_pointer(Input.get_vector("look_left","look_right","look_up","look_down")*delta*.45)
func release() -> void:
 if is_instance_valid(player) and player.has_meta("consignment_fpv_camera") and player.get_meta("consignment_fpv_camera")==self:
  player.remove_meta("consignment_fpv_camera");player.remove_meta("consignment_aim_uv")
 if current and is_instance_valid(previous):previous.make_current()
 queue_free()
