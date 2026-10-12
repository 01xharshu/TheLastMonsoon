extends SceneTree
## Exact old/new clothing geometry, buffer lifetime, bounds and native pixels on MPFB actors.
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 if not ok and not errors.has(message):errors.append(message);push_error(message)
func run() -> void:
 var output:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 if output.is_empty() or not output.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-20,0);world.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.15,.18,.21)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.65
 world.add_child(environment)
 var view:=SubViewport.new();view.size=Vector2i(960,540);view.world_3d=world.get_world_3d()
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);root.disable_3d=true
 var camera:=Camera3D.new();view.add_child(camera);camera.position=Vector3(.8,1.0,2.8);camera.look_at(Vector3(0,.9,0));camera.current=true
 var max_vertex:=0.0;var max_normal:=0.0;var max_tangent:=0.0;var changed_pixels:=0
 var mismatched_saved:=false
 var original_times: Array[int]=[];var updated_times: Array[int]=[]
 var old_draw_times: Array[int]=[];var new_draw_times: Array[int]=[]
 for variant in 4:
  var actor:=preload("res://characters/npcs/british/british_npc_actor.gd").new()
  actor.movement_enabled=false;actor.foot_plant_enabled=false;actor.set_meta("combat_faction","indian")
  actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/workman_%02d.glb"%[variant+1],false))
  world.add_child(actor);await process_frame
  actor.set_process(false);actor.set_physics_process(false);actor.animation_tree.active=false
  var reference=preload("res://tools/characters/street_dhoti_reference.gd").new(actor,actor._skeleton)
  var updated=preload("res://characters/npcs/indian/indian_street_dhoti.gd").new(actor,actor._skeleton)
  var untouched: Dictionary={}
  for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   if node!=reference.garment and node!=updated.garment:untouched[node]=node.mesh
  reference.update();updated.update();var buffer: RID=updated.mesh.get_rid()
  for sample in 32:
   actor._set_animation(&"walk" if sample<24 else &"idle",.07)
   actor._skeleton.force_update_all_bone_transforms()
   reference.update();updated.update()
   check(updated.mesh.get_rid()==buffer,"cloth mesh buffer stays resident")
   if DisplayServer.get_name()!="headless":
    var first: Array=reference.garment.mesh.surface_get_arrays(0)
    var second: Array=updated.mesh.surface_get_arrays(0)
    check(first[Mesh.ARRAY_INDEX]==second[Mesh.ARRAY_INDEX] and first[Mesh.ARRAY_TEX_UV]==second[Mesh.ARRAY_TEX_UV],"cloth topology and UV stay exact")
    for tangent in first[Mesh.ARRAY_TANGENT].size():
     max_tangent=maxf(max_tangent,absf(first[Mesh.ARRAY_TANGENT][tangent]-second[Mesh.ARRAY_TANGENT][tangent]))
    for vertex in first[Mesh.ARRAY_VERTEX].size():
     max_vertex=maxf(max_vertex,first[Mesh.ARRAY_VERTEX][vertex].distance_to(second[Mesh.ARRAY_VERTEX][vertex]))
     max_normal=maxf(max_normal,first[Mesh.ARRAY_NORMAL][vertex].distance_to(second[Mesh.ARRAY_NORMAL][vertex]))
     check(updated.mesh.custom_aabb.grow(.000001).has_point(second[Mesh.ARRAY_VERTEX][vertex]),"updated bounds contain all vertices")
    if sample in [4,12,20,28]:
     # Let imported skinning settle before comparing two presentations of one pose.
     for settle in 2:RenderingServer.force_draw(false)
     reference.garment.show();updated.garment.hide();RenderingServer.force_draw(false);RenderingServer.force_draw(false)
     var old_image:=view.get_texture().get_image()
     reference.garment.hide();updated.garment.show();RenderingServer.force_draw(false);RenderingServer.force_draw(false)
     var new_image:=view.get_texture().get_image()
     var a:=old_image.get_data();var b:=new_image.get_data()
     var changed:=0
     for byte in a.size():
      if a[byte]!=b[byte]:changed+=1
     changed_pixels+=changed
     if changed>0:
      print("DHOTI PIXEL DELTA variant=",variant," pose=",sample," bytes=",changed," material=",reference.garment.material_override)
      if not mismatched_saved:
       old_image.save_png(output.path_join("first_delta_reference.png"));new_image.save_png(output.path_join("first_delta_updated.png"))
       mismatched_saved=true
     if sample==12:
      old_image.save_png(output.path_join("dhoti_reference_%d.png"%variant));new_image.save_png(output.path_join("dhoti_updated_%d.png"%variant))
   for node in untouched:check(node.mesh==untouched[node],"full MPFB body and other garments stay untouched")
  # Same pose work, alternating order, with unchanged-pose early exit deliberately bypassed.
  for round_index in 7:
   for use_updated in ([false,true] if round_index%2==0 else [true,false]):
    var garment: RefCounted=updated if use_updated else reference
    var started:=Time.get_ticks_usec()
    for iteration in 40:
     garment.previous=PackedVector3Array();garment.update()
    var elapsed:=Time.get_ticks_usec()-started
    if use_updated:updated_times.append(elapsed)
    else:original_times.append(elapsed)
  if DisplayServer.get_name()!="headless":
   for round_index in 7:
    for use_updated in ([false,true] if round_index%2==0 else [true,false]):
     reference.garment.visible=not use_updated;updated.garment.visible=use_updated
     RenderingServer.force_draw(false)
     var started:=Time.get_ticks_usec()
     var garment: RefCounted=updated if use_updated else reference
     for iteration in 8:
      garment.previous=PackedVector3Array();garment.update();RenderingServer.force_draw(false)
     var elapsed:=Time.get_ticks_usec()-started
     if use_updated:new_draw_times.append(elapsed)
     else:old_draw_times.append(elapsed)
  print("DHOTI VARIANT ",variant," completed")
  actor.queue_free();await process_frame
 check(max_vertex<.000001,"uploaded cloth vertices match the original")
 check(max_normal<.0001,"uploaded cloth normals match the original")
 check(changed_pixels==0,"rendered cloth pixels match the original")
 original_times.sort();updated_times.sort()
 print("STREET DHOTI BUFFERS: ","PASS" if errors.is_empty() else "FAIL", " variants=4 poses=128 vertex_gap=",max_vertex," normal_gap=",max_normal," tangent_gap=",max_tangent," changed_bytes=",changed_pixels," old_40_updates_us=",original_times[original_times.size()/2]," new_40_updates_us=",updated_times[updated_times.size()/2]," native=",DisplayServer.get_name()!="headless")
 if not old_draw_times.is_empty():
  old_draw_times.sort();new_draw_times.sort()
  print("DHOTI DRAW COST: old_8_frames_us=",old_draw_times[old_draw_times.size()/2]," new_8_frames_us=",new_draw_times[new_draw_times.size()/2])
 world.queue_free();view.queue_free();await process_frame
 preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
