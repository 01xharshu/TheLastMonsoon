extends SceneTree
const Trees = preload("res://world/suryagarh/roadside_trees.gd")
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func sample(label: String) -> void:
 var epoch_path:=OS.get_environment("TLM_ROADSIDE_EPOCH")
 var epoch: String=FileAccess.get_file_as_string(epoch_path) if FileAccess.file_exists(epoch_path) else ""
 var warmup:=20
 var times: Array[float]=[]
 while times.size()<90:
  var before:=Time.get_ticks_usec();await process_frame
  var revision: String=FileAccess.get_file_as_string(epoch_path) if FileAccess.file_exists(epoch_path) else ""
  if revision!=epoch:
   epoch=revision;times.clear();warmup=20;continue
  if warmup>0:warmup-=1;continue
  times.append((Time.get_ticks_usec()-before)/1000.0)
 times.sort();print("ROADSIDE FRAME ",label," p50_ms=",times[45]," p95_ms=",times[85]," viewport=",root.size," scale=",root.scaling_3d_scale)
func run() -> void:
 var saves: Node=root.get_node("SaveManager")
 saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.apply_options()
 saves.start_new_game();await scene_changed
 var world: Node3D=current_scene
 while not world.has_node("RoadsideShadeTrees") or not world.get_node("RoadsideShadeTrees").has_meta("tree_count"):await process_frame
 while world.get_node_or_null("OpeningSequence")==null:await process_frame
 var opening: Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true;opening._input(skip);await process_frame;opening._input(skip)
 while is_instance_valid(opening) and opening.state!="done":await process_frame
 var holder: Node3D=world.get_node("RoadsideShadeTrees")
 var points: Array=holder.get_meta("roots")
 check(points.size()>=200 and points.size()<=Trees.LIMIT,"bounded substantial roadside population")
 check(await Trees.install(world)==0,"repeated setup does not duplicate trees")
 var layout:=Trees.Layout.new()
 var space:=world.get_world_3d().direct_space_state
 var road_probe:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=2.0;capsule.height=3.0;road_probe.shape=capsule
 road_probe.exclude=Ground.terrain_exclusions(world);road_probe.collision_mask=1
 var new_bodies: Dictionary={}
 for body in holder.find_children("*","StaticBody3D",true,false):new_bodies[body.get_rid()]=true
 var road_samples:=0
 for p: Vector3 in points:
  check(Trees.suitable(layout,Vector2(p.x,p.z)),"root outside roads/plots/water/steep terrain")
  var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,Ground.TERRAIN_SUPPORT_LAYER)
  var hit:=space.intersect_ray(ray)
  check(not hit.is_empty() and absf(hit.position.y-p.y)<.03,"root uses actual terrain collision")
 # Sample every surveyed route plus original trunk. Only new colliders are judged;
 # pre-existing obstacles remain with their owners.
 var paths: Array=Trees.Layout.ROUTES.values().duplicate()
 var trunk: Array=[]
 for z in range(-690,711,4):
  if z>360 and z<510:continue
  trunk.append(Vector2(layout.road_x(z),z))
 # Split original trunk across its superseded section.
 paths.append(trunk.slice(0,263));paths.append(trunk.slice(263))
 for path in paths:
  for i in range(path.size()-1):
   var a: Vector2=path[i];var b: Vector2=path[i+1]
   for step in range(ceili(a.distance_to(b)/3.0)+1):
    var at:=a.lerp(b,minf(float(step)*3.0/maxf(a.distance_to(b),.001),1.0))
    road_probe.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,layout.height(at.x,at.y)+1.6,at.y))
    for hit in space.intersect_shape(road_probe,64):check(not new_bodies.has(hit.rid),"new trunks clear swept cart-width road envelope")
    road_samples+=1
 var actual:=0
 if DisplayServer.get_name()!="headless":
  var shared_meshes: Dictionary={}
  var batch_count:=0
  for batch in holder.find_children("*","MultiMeshInstance3D",true,false):
   batch_count+=1
   var kind: String=batch.get_meta("roadside_species","")
   check(batch.multimesh.mesh==Trees.Variety.mesh_for(kind),"each tile references its shared species mesh")
   shared_meshes[batch.multimesh.mesh.get_instance_id()]=true
   check(batch.visibility_range_end==460 and is_equal_approx(batch.lod_bias,.6),"shared LOD and finite tile visibility")
   var profile:=Trees.Variety.profile_for(batch.multimesh.mesh)
   for at in Ground.instance_transforms(batch.multimesh):
    var foot: Vector3=batch.to_global(at*(profile[0].centre-Vector3.UP*float(profile[0].height)*.5))
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*2,foot-Vector3.UP*2,Ground.TERRAIN_SUPPORT_LAYER))
    check(not hit.is_empty() and absf(foot.y-hit.position.y+.12)<.03,"visible woody root embeds terrain")
    var center: Vector3=batch.to_global(at*profile[1].centre)
    var trunk_ray:=PhysicsRayQueryParameters3D.create(center+Vector3.RIGHT*3,center-Vector3.RIGHT*3,1)
    trunk_ray.exclude=Ground.terrain_exclusions(world)
    var solid:=space.intersect_ray(trunk_ray)
    if solid.is_empty() or not new_bodies.has(solid.rid):print("ROADSIDE TRUNK DIAGNOSTIC center=",center," kind=",batch.get_meta("roadside_species")," hit=",solid)
    check(not solid.is_empty() and new_bodies.has(solid.rid),"visible trunk has persistent solid collision")
    actual+=1
  check(actual==points.size(),"rendered and physical tree counts agree")
  check(shared_meshes.size()<=4 and batch_count<actual,"trees share at most four mesh resources and use instanced batches")
  print("ROADSIDE INSTANCING trees=",actual," batches=",batch_count," shared_meshes=",shared_meshes.size())
 print("ROADSIDE CHECK trees=",points.size()," road_samples=",road_samples," tiles=",new_bodies.size())
 if DisplayServer.get_name()!="headless":
  var clock: Node=world.get_node("GameTimeSystem");clock.current_hour=10;clock.total_game_minutes=600;clock.clock_paused=true;clock._update_readable_time(true)
  var camera:=Camera3D.new();world.add_child(camera);camera.far=900;camera.fov=70;camera.make_current()
  world.player.set_physics_process(false)
  for region in [{"name":"rural","z":-120.0},{"name":"village_approach","z":100.0}]:
   var x: float=layout.road_x(region.z)
   world.player.global_position=Vector3(x,layout.height(x,region.z)+1,region.z)
   camera.position=world.player.position+Vector3(0,1.0,0)
   camera.look_at(Vector3(layout.road_x(region.z+60),layout.height(x,region.z)+3,region.z+60))
   holder.hide();await sample(region.name+"_baseline")
   holder.show();await sample(region.name+"_avenue")
   await RenderingServer.frame_post_draw
   var output:=OS.get_environment("TLM_ROADSIDE_REVIEW")
   if not output.is_empty():root.get_texture().get_image().save_png(output.path_join(region.name+".png"))
  var output:=OS.get_environment("TLM_ROADSIDE_REVIEW")
  if not output.is_empty():
   print("ROADSIDE REVIEW READY ",output)
   var deadline:=Time.get_ticks_msec()+90000
   while not FileAccess.file_exists(output.path_join("review_done")) and Time.get_ticks_msec()<deadline:await process_frame
 print("ROADSIDE TREES: ","PASS" if failures.is_empty() else "FAIL "+str(failures.size()))
 saves.quit_game(0 if failures.is_empty() else 1)
