extends SceneTree
# Isolated Metal/Forward+ waist-pouch review on the temporary gameplay rig.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("WATER BAG CAPTURE requires a rendered display")
  quit(1)
  return
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene=stage
 var clock := Node.new()
 clock.name="GameTimeSystem"
 clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 stage.add_child(clock)
 var floor := StaticBody3D.new()
 stage.add_child(floor)
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size=Vector3(8,.4,8)
 shape.shape=box
 shape.position.y=-.2
 floor.add_child(shape)
 var plane:=MeshInstance3D.new()
 var pm:=PlaneMesh.new()
 pm.size=Vector2(8,8)
 plane.mesh=pm
 floor.add_child(plane)
 var env:=WorldEnvironment.new()
 var e:=Environment.new()
 e.background_mode=Environment.BG_COLOR
 e.background_color=Color(.25,.28,.26)
 e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color=Color(.8,.8,.8)
 env.environment=e
 stage.add_child(env)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-40,-30,0)
 sun.light_energy=2.0
 stage.add_child(sun)
 var actor=load("res://player/player.tscn").instantiate()
 stage.add_child(actor)
 actor.position=Vector3(0,1,0)
 actor.get_node("UI").hide()
 var cam:=Camera3D.new()
 stage.add_child(cam)
 for i in 30: await physics_frame
 for view in [["front",Vector3(0,1.2,2.0)],["side",Vector3(2,1.2,0)],["back",Vector3(0,1.2,-2.0)]]:
  cam.global_position=actor.global_position+view[1]
  cam.look_at(actor.global_position+Vector3(0,.7,0))
  cam.make_current()
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  var path: String = "res://docs/characters/arjun/water_bag_waist_" + str(view[0]) + ".png"
  print("BAG CAPTURE ",view[0]," ",root.get_texture().get_image().save_png(path)," ",path)
 var bag=actor.get_node("VisualRoot/EquipmentVisuals/WaterBagVisual")
 var pelvis=actor.get_node("VisualRoot/CharacterVisual").skeleton
 print("BAG DISTANCE ",bag.global_position.distance_to(pelvis.global_transform.origin)," ",bag.global_position)
 quit()
