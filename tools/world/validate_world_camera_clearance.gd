extends SceneTree
# Run with Godot --path . --script tools/world/validate_world_camera_clearance.gd.
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
 var arm: SpringArm3D = player.get_node("CameraPivot/SpringArm3D")
 var house: Node3D = world.get_node("Settlement/GovernmentHouse/MainHouse")
 var failures := 0
 var locations := [
  ["house_ground_hall", Vector3(20, 0.95, 8.0)],
  ["house_upper_room", Vector3(28, 5.55, -8.0)],
  ["house_study", Vector3(-19, 1.29, 16)],
  ["house_drawing_room", Vector3(-5, 5.55, 5.5)],
  ["house_bedroom", Vector3(-19, 10.15, -5)]
 ]
 for location in locations:
  var center: Vector3 = house.to_global(location[1])
  var found := false
  for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
   var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 1.5, center + Vector3.UP * 1.5 + direction * 50.0)
   ray.exclude = [player.get_rid()]
   var wall_hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
   if wall_hit.is_empty(): continue
   var hit_distance: float = center.distance_to(wall_hit.position)
   if hit_distance < 1.0: continue
   player.global_position = wall_hit.position - direction * 0.65 - Vector3.UP * 1.5
   player.global_position.y = center.y
   player.camera_pivot.rotation = Vector3(0, atan2(direction.x, direction.z), 0)
   for i in 20: await physics_frame
   for i in 3: await process_frame
   camera._process(0.0)
   var distance: float = arm.global_position.distance_to(camera.global_position)
   var max_open_distance := arm.spring_length + 0.1
   # Close-wall retraction can reach the pivot; verify clearance and body hiding.
   var clear: bool = distance >= 0.0 and distance <= max_open_distance
   if distance <= camera.BODY_HIDE_DISTANCE:
    clear = clear and not player.visual_root.visible
   var sphere := SphereShape3D.new()
   sphere.radius = camera.near
   var overlap := PhysicsShapeQueryParameters3D.new()
   overlap.shape = sphere
   overlap.transform = Transform3D(Basis.IDENTITY, camera.global_position)
   overlap.collision_mask = arm.collision_mask
   overlap.exclude = [player.get_rid()]
   clear = clear and world.get_world_3d().direct_space_state.intersect_shape(overlap, 1).is_empty()
   var query := PhysicsRayQueryParameters3D.create(arm.global_position, camera.global_position)
   query.collision_mask = arm.collision_mask
   query.exclude = [player.get_rid()]
   var camera_hit := world.get_world_3d().direct_space_state.intersect_ray(query)
   clear = clear and camera_hit.is_empty()
   if not clear: failures += 1
   print("WORLD CAMERA ", "PASS" if clear else "FAIL", " ", location[0], " distance=", distance, " wall=", wall_hit.collider, " camera_hit=", camera_hit.get("collider", null), " hit_pos=", camera_hit.get("position", Vector3.ZERO), " pivot=", arm.global_position, " camera=", camera.global_position)
   if DisplayServer.get_name() != "headless":
    camera.make_current()
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    print("WORLD CAMERA CAPTURE ", root.get_texture().get_image().save_png("/tmp/tlm_camera_" + location[0] + ".png"))
   found = true
   break
  if not found:
   failures += 1
   print("WORLD CAMERA FAIL no nearby wall for ", location[0])
 print("WORLD CAMERA CLEARANCE: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
 quit(0 if failures == 0 else 1)
