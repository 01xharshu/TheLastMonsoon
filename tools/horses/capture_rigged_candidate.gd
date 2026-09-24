extends SceneTree
## Isolated source-mesh review in the actual world; does not alter the live horse.
func _initialize() -> void:
 _capture.call_deferred()
func _capture() -> void:
 if DisplayServer.get_name() == 'headless':
  push_error('HORSE CANDIDATE CAPTURE BLOCKED: native renderer required')
  quit(1);return
 var world: Node3D = load('res://world/suryagarh/suryagarh_world.tscn').instantiate()
 root.add_child(world);current_scene=world
 var actor: CharacterBody3D=world.get_node('Player')
 actor.set_physics_process(false)
 actor.get_node('UI').hide();world.get_node('LandscapeUI').hide()
 for i in 20: await process_frame
 var horse: CharacterBody3D=world.get_node('VillageHorse')
 horse.get_node('HorseBody').hide()
 var model: Node3D=load('res://assets/animals/horse/rigged_horse_candidate.glb').instantiate()
 horse.add_child(model);model.scale=Vector3.ONE*.47
 var animations: AnimationPlayer=model.find_child('AnimationPlayer',true,false)
 animations.play('AnimalArmature|Idle')
 actor.global_position=horse.global_position+Vector3(0,1,2)
 if not horse.board(actor): push_error('Could not mount');quit(1);return
 horse.global_position=Vector3(-258,world.layout.height(-258,203)+.15,203)
 var camera:=Camera3D.new();world.add_child(camera);camera.fov=52;camera.make_current()
 for i in 85: await physics_frame
 for orientation in [0.0,PI]:
  model.rotation.y=orientation
  camera.global_position=horse.global_position+horse.global_basis*Vector3(-6,2.6,2.5)
  camera.look_at(horse.global_position+Vector3.UP*1.5)
  for i in 8: await process_frame
  await RenderingServer.frame_post_draw
  var path: String='res://WorkingAssets/Horse/candidates/quaternius_horse/game_side_%s.png' % ('zero' if orientation==0.0 else 'pi')
  root.get_texture().get_image().save_png(path)
  print('HORSE CANDIDATE CAPTURE ',path)
 quit()
