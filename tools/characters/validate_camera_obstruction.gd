extends SceneTree
# Run with Godot --headless --path . --script tools/characters/validate_camera_obstruction.gd.
func _initialize() -> void:
 _run.call_deferred()

func _run() -> void:
 var stage := Node3D.new()
 root.add_child(stage)
 var clock := Node.new()
 clock.name = "GameTimeSystem"
 clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 stage.add_child(clock)
 var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
 stage.add_child(player)
 player.set_physics_process(false)
 var arm: SpringArm3D = player.get_node("CameraPivot/SpringArm3D")
 var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
 var ok := arm.shape is SphereShape3D and arm.collision_mask == 4294967295
 for i in 12: await physics_frame
 var open_distance: float = arm.global_position.distance_to(camera.global_position)
 ok = ok and open_distance > 1.6 and open_distance < 1.9
 var ground := MeshInstance3D.new()
 var floor_mesh := PlaneMesh.new()
 floor_mesh.size = Vector2(8, 8)
 ground.mesh = floor_mesh
 stage.add_child(ground)
 var light := DirectionalLight3D.new()
 stage.add_child(light)
 light.rotation_degrees = Vector3(-35, -25, 0)
 light.light_energy = 2.0
 var wall := StaticBody3D.new()
 stage.add_child(wall)
 wall.position = Vector3(0, 1.5, 1.0)
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(3, 3, 0.2)
 collision.shape = box
 wall.add_child(collision)
 var wall_mesh := MeshInstance3D.new()
 var wall_box := BoxMesh.new()
 wall_box.size = box.size
 wall_mesh.mesh = wall_box
 wall.add_child(wall_mesh)
 for i in 12: await physics_frame
 var blocked_distance: float = arm.global_position.distance_to(camera.global_position)
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  print("CAMERA CAPTURE: ", root.get_texture().get_image().save_png("/tmp/tlm_camera_obstruction.png"))
 ok = ok and blocked_distance < 0.8 and blocked_distance > 0.1
 wall.collision_layer = 16
 for i in 12: await physics_frame
 ok = ok and arm.global_position.distance_to(camera.global_position) < 0.8
 wall.position = Vector3(0, 1.5, 0.48)
 for i in 12: await physics_frame
 for i in 3: await process_frame
 var tight_distance: float = arm.global_position.distance_to(camera.global_position)
 ok = ok and tight_distance < 0.42 and not player.visual_root.visible
 wall.position = Vector3(0, 1.5, -1.0)
 for i in 12: await physics_frame
 var restored_distance: float = arm.global_position.distance_to(camera.global_position)
 ok = ok and restored_distance > 1.6
 print("CAMERA OBSTRUCTION: ", "PASS" if ok else "FAIL", " | open=", open_distance, " blocked=", blocked_distance, " tight=", tight_distance, " restored=", restored_distance)
 quit(0 if ok else 1)
