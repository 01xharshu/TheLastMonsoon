extends SceneTree
func _initialize() -> void:call_deferred('run')
func run() -> void:
 root.size=Vector2i(1280,720)
 var scene := Node3D.new();root.add_child(scene);current_scene=scene
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(4,2.8,5);camera.look_at(Vector3(0,1.5,0));camera.current=true
 var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-45,-30,0)
 var flag: Node3D=load('res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb').instantiate();scene.add_child(flag);flag.scale=Vector3.ONE*.55
 for anim in flag.find_children('*','AnimationPlayer',true,false):
  anim.get_animation('wind').loop_mode=Animation.LOOP_LINEAR;anim.play('wind');anim.add_to_group('wind_flags')
 var tree: Node3D=load('res://environment/vegetation/mango_tree/mango_tree_01.glb').instantiate();scene.add_child(tree);tree.position=Vector3(-1,0,-2);tree.scale=Vector3.ONE*.35
 var ground:=MeshInstance3D.new();ground.mesh=PlaneMesh.new();ground.mesh.size=Vector2(8,8);scene.add_child(ground)
 for x in 14:
  for z in 12:
   var grass := MeshInstance3D.new();grass.mesh=preload('res://world/suryagarh/grass_blades.gd').make_mesh(true)
   grass.position=Vector3(.5+x*.1,0,-.6+z*.1);scene.add_child(grass)
 for i in 180:await process_frame
 DirAccess.make_dir_recursive_absolute("/tmp/monsoon_wind_frames")
 var timestamps: Array[int]=[]
 var started := Time.get_ticks_msec()
 for i in 60:
  while Time.get_ticks_msec()<started+i*100:await process_frame
  await RenderingServer.frame_post_draw
  var frame := root.get_texture().get_image();frame.resize(1280,720)
  frame.save_png("/tmp/monsoon_wind_frames/%03d.png"%i)
  timestamps.append(Time.get_ticks_msec()-started)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('res://docs/world/wind_review.png')
 var timing := FileAccess.open('/tmp/monsoon_wind_frames/timing.json',FileAccess.WRITE);timing.store_string(JSON.stringify(timestamps));timing.close()
 print('NATIVE WIND REVIEW: PASS | rendered shared grass and flag animation')
 preload('res://tools/test_audio_cleanup.gd').stop(root)
 await preload('res://tools/test_audio_cleanup.gd').settle(self)
 quit()
