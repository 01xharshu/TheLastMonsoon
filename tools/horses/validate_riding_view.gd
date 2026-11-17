extends SceneTree
func check(ok: bool, message: String = "riding check") -> void:
 if not ok:
  push_error(message)
  quit(1)
func _initialize() -> void: _run.call_deferred()
var review_horse: Node3D
var review_camera: Camera3D
func capture(label: String, settle := .3) -> void:
 if settle > 0.0: await create_timer(settle).timeout
 var actor: Node3D = review_horse.rider
 var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
 actor._update_weapon_camera(.1)
 check(is_equal_approx(actor.get_node("CameraPivot/SpringArm3D").spring_length,5.8))
 check(is_zero_approx(actor.get_node("CameraPivot/SpringArm3D").position.x))
 # Project conservative whole-horse envelope plus rider head in the real rear view.
 for point in [Vector3(-.65,.1,-1.5),Vector3(.65,.1,-1.5),Vector3(-.65,.1,1.5),Vector3(.65,.1,1.5),Vector3(0,3.1,0)]:
  var at: Vector3 = review_horse.to_global(point)
  check(not camera.is_position_behind(at), "horse stays ahead of camera")
  var uv: Vector2 = camera.unproject_position(at)/Vector2(root.size)
  check(uv.x>.03 and uv.x<.97 and uv.y>.03 and uv.y<.97,"whole horse/rider envelope fits: "+str(uv))
 var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
 for side in ["l","r"]:
  var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side))
  var palm: Vector3 = visual.skeleton.to_global(hand*visual.equipment.palm_offsets[side])
  check(palm.distance_to(review_horse.riding_rein_world(side))<.08,"rein contact")
  var foot_index: int = visual.skeleton.find_bone("foot_"+side)
  var foot: Transform3D = visual.skeleton.get_bone_global_pose(foot_index)
  var rest: Transform3D = visual.skeleton.get_bone_global_rest(foot_index)
  var sole: Vector3 = visual.skeleton.to_global(foot*(rest.basis.inverse()*Vector3(0,-.085,.06)))
  check(sole.distance_to(review_horse.stirrup_world(side))<.04,"stirrup contact")
 print("RIDING VIEW PASS ",label)
 if DisplayServer.get_name() != "headless" and OS.get_environment("TLM_RIDING_REVIEW") != "":
  await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OS.get_environment("TLM_RIDING_REVIEW")+"/"+label+".png")
func _run() -> void:
 root.size = Vector2i(1280,720)
 var world := Node3D.new()
 world.position.y = 20.0 # Keep the isolated floor above the real-world river safety plane.
 root.add_child(world)
 var time := Node.new()
 time.name = "GameTimeSystem"
 time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 world.add_child(time)
 var floor := StaticBody3D.new()
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(1000,.2,1000)
 collision.shape = box
 floor.add_child(collision)
 var mesh := MeshInstance3D.new()
 var ground := BoxMesh.new()
 ground.size = Vector3(1000,.2,1000)
 mesh.mesh = ground
 floor.add_child(mesh)
 world.add_child(floor)
 var sun := DirectionalLight3D.new()
 sun.rotation = Vector3(-.9,.4,0)
 sun.light_energy = 1.8
 world.add_child(sun)
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 actor.position = Vector3(1.2,1,0)
 world.add_child(actor)
 actor.get_node("UI").hide()
 await create_timer(.3).timeout
 var horse: CharacterBody3D = load("res://horses/stable_horse.gd").new()
 world.add_child(horse)
 review_horse = horse
 await create_timer(.5).timeout
 actor.global_position = horse.global_position + Vector3(1.2,1,0)
 check(horse.board(actor))
 await create_timer(1.0).timeout
 check(absf(angle_difference(actor.camera_pivot.global_rotation.y,horse.rotation.y))<.01,"boarding starts behind horse")
 await capture("horse_seated_refinement")
 Input.action_press("move_forward")
 Input.action_press("sprint")
 await create_timer(1.7).timeout
 check(horse.pace > 9.0)
 await capture("horse_gallop_refinement")
 Input.action_press("jump")
 for frame in 6:
  await physics_frame
  if not horse.is_on_floor(): break
 Input.action_release("jump")
 for frame in 50:
  if horse.velocity.y <= .3 or horse.is_on_floor(): break
  await physics_frame
 check(not horse.is_on_floor(),"horse reaches airborne apex")
 var jump_anim: AnimationPlayer = horse.rigged_anim
 check(jump_anim.current_animation.ends_with("Jump") and absf(jump_anim.current_animation_position-.5)<.09,"foreleg tuck keys align with the physical apex")
 var skeleton: Skeleton3D = horse.rigged_skeleton
 var foreleg := skeleton.find_bone("FrontLowerLeg.L")
 var tucked := skeleton.get_bone_pose_rotation(foreleg)
 await capture("horse_jump_apex",0.0)
 await create_timer(.27).timeout
 check(not horse.is_on_floor() and jump_anim.current_animation_position>.67,"horse reaches foreleg extension keys before contact")
 check(tucked.angle_to(skeleton.get_bone_pose_rotation(foreleg))>.35,"foreleg unfolds on descent")
 await capture("horse_jump_extension",0.0)
 Input.action_release("move_forward")
 Input.action_release("sprint")
 await create_timer(1.2).timeout
 check(horse.landing_events > 0)
 check(horse.rider_landing < .1)
 var ramp := StaticBody3D.new()
 ramp.position = Vector3(24,2.8,0)
 ramp.rotation.x = .21
 var ramp_collision := CollisionShape3D.new()
 var ramp_box := BoxShape3D.new()
 ramp_box.size = Vector3(12,.2,26)
 ramp_collision.shape = ramp_box
 ramp.add_child(ramp_collision)
 var ramp_surface := MeshInstance3D.new()
 var ramp_mesh := BoxMesh.new()
 ramp_mesh.size = ramp_box.size
 ramp_surface.mesh = ramp_mesh
 ramp.add_child(ramp_surface)
 world.add_child(ramp)
 horse.global_position = world.to_global(Vector3(24,3.1,0))
 horse.velocity = Vector3.ZERO
 await create_timer(.45).timeout
 Input.action_press("move_forward")
 await create_timer(.8).timeout
 check(horse.is_on_floor() and horse.rider_grade>.15,"actual ramp produces sustained uphill grade")
 check(horse.body_root.rotation.x>.05,"horse and tack pitch uphill together")
 await capture("horse_uphill")
 Input.action_release("move_forward")
 await create_timer(.4).timeout
 check(horse.dismount())
 await create_timer(1.5).timeout
 actor._update_weapon_camera(.1)
 check(not is_equal_approx(actor.get_node("CameraPivot/SpringArm3D").spring_length,5.8),"on-foot camera restores")
 print("RIDING VIEW PASS dismount restoration, gallop, jump, landing and uphill")
 var review_dir := OS.get_environment("TLM_RIDING_REVIEW")
 if DisplayServer.get_name() != "headless" and not review_dir.is_empty():
  print("RIDING REVIEW READY")
  var deadline := Time.get_ticks_msec()+45000
  while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(review_dir.path_join("riding_done")):
   await process_frame
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0)
