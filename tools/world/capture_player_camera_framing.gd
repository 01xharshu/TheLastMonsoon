extends SceneTree
# Fresh outdoor and interior views from the actual player camera.
func _initialize() -> void:
 _run.call_deferred()

func _run() -> void:
 var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 var player: CharacterBody3D = world.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
 camera.make_current()
 var house: Node3D = world.get_node("Settlement/GovernmentHouse/MainHouse")
 var positions := [
  ["outdoor", Vector3(-230, 10, 180), 0.0],
  ["house_hall", house.to_global(Vector3(20, 0.95, 8.0)), 0.0],
  ["house_room", house.to_global(Vector3(28, 5.55, -8.0)), 0.0]
 ]
 for variant in [["current", 1.5, 0.0], ["candidate", 0.90, -4.0]]:
  player.third_person_height = variant[1]
  player.get_node("StealthStance").base_height = variant[1]
  for sample in positions:
   player.global_position = sample[1]
   player.camera_pitch = deg_to_rad(variant[2])
   player.camera_pivot.rotation = Vector3(player.camera_pitch, sample[2], 0)
   for i in 20: await physics_frame
   for i in 3: await process_frame
   await RenderingServer.frame_post_draw
   var path: String = "/tmp/tlm_camera_framing_" + variant[0] + "_" + sample[0] + ".png"
   print("CAMERA FRAMING ", variant[0], " ", sample[0], " ", root.get_texture().get_image().save_png(path), " camera=", camera.global_position, " pivot=", player.camera_pivot.global_position)
 quit()
