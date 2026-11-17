extends SceneTree
const Terrain=preload("res://world/suryagarh/tree_trunk_collision.gd")
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run()->void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 for path in ["res://world/suryagarh/generated/landscape.scn","res://world/suryagarh/generated/wilderness_expansion/wilderness_expansion.scn"]:world.add_child(load(path).instantiate())
 Terrain.configure_terrain_support(world)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);world.add_child(light)
 var ambience:=WorldEnvironment.new();var environment:=Environment.new();var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new();environment.sky=sky;environment.background_mode=Environment.BG_SKY;environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;environment.ambient_light_energy=.7;ambience.environment=environment;world.add_child(ambience)
 var original_grass:Dictionary={}
 for batch:MultiMeshInstance3D in world.find_children("Grass*","MultiMeshInstance3D",true,false):original_grass[batch]=batch.multimesh
 var region: Node3D=load("res://world/suryagarh/remote_mountains.gd").new();world.add_child(region);await region.built
 var unchanged:=true
 for batch in original_grass:unchanged=unchanged and batch.multimesh==original_grass[batch]
 check(unchanged,"worn trail preserves all existing grass instance buffers")
 var cleared:=true
 for point:Vector3 in region.route:
  var uv:Vector2=(Vector2(point.x,point.z)-region.clearance_rect.position)/region.clearance_rect.size
  var pixel:=Vector2i(uv*1024).clamp(Vector2i.ZERO,Vector2i.ONE*1023)
  if region.clearance_image.get_pixel(pixel.x,pixel.y).r<.9:cleared=false
 check(cleared,"walking centerline has full grass clearance along entire trail")
 check(region.verge_roots.size()>1500,"long mountain grass remains on natural verges")
 check(region.find_children("*","MeshInstance3D",true,false).filter(func(node:Node)->bool:return node.get_meta("period_roof_board",false)).size()>=30 and region.find_children("WeatheredTimberRoof*","MeshInstance3D",true,false).is_empty(),"refuge uses pitched split-timber roof rather than slab silhouette")
 var missing:=0;var blocked:=0;var steep:=0;var length:=0.0
 var exclude: Array[RID]=Terrain.terrain_exclusions(world)
 var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.6
 var horse_capsule:=CapsuleShape3D.new();horse_capsule.radius=.65;horse_capsule.height=2.4
 var horse_blocked:=0
 for i in region.route.size():
  var point: Vector3=region.route[i]
  var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*3,Terrain.TERRAIN_SUPPORT_LAYER)
  if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():missing+=1
  var q:=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.transform.origin=point+Vector3.UP*1.05;q.exclude=exclude;q.collision_mask=1
  var hits:=world.get_world_3d().direct_space_state.intersect_shape(q,4)
  q.shape=horse_capsule;q.transform.origin=point+Vector3.UP*1.45
  var horse_hits:=world.get_world_3d().direct_space_state.intersect_shape(q,4)
  if not horse_hits.is_empty():
   horse_blocked+=1
   if horse_blocked<5:print("MOUNTAIN HORSE BLOCK ",point," ",horse_hits[0].collider.get_path())
  if not hits.is_empty():
   blocked+=1
   if blocked<8:print("MOUNTAIN BLOCK ",point," ",hits[0].collider.get_path())
  if i>0:
   var difference: Vector3=point-region.route[i-1];length+=difference.length()
   if absf(difference.y)/maxf(.01,Vector2(difference.x,difference.z).length())>.6:steep+=1
 check(length>1300,"dedicated remote trail exceeds 1.3km")
 check(missing==0,"entire trail supported by saved physical terrain")
 check(blocked==0,"walking corridor clear of solid obstructions")
 check(steep==0,"saved trail grades remain traversable")
 check(horse_blocked==0,"trail has horse-sized collision clearance")
 var sites: Dictionary=preload("res://player/map_infrastructure.gd").collect(world)
 check(sites.has("Northern mountain refuge") and sites.has("Northeastern summit"),"mountain destinations enter shared map registry")
 var solids:Dictionary={}
 for body:StaticBody3D in region.find_children("*","StaticBody3D",true,false):solids[body.get_rid()]=true
 var public_blocks:=0
 var public_shape:=CapsuleShape3D.new();public_shape.radius=2;public_shape.height=3
 for points:Array in region.Layout.ROUTES.values():
  for i in points.size()-1:
   var a:Vector2=points[i];var b:Vector2=points[i+1];var steps:=maxi(1,ceili(a.distance_to(b)/4))
   for step in steps+1:
    var p:Vector3=region.surface(a.lerp(b,float(step)/steps))
    var q:=PhysicsShapeQueryParameters3D.new();q.shape=public_shape;q.transform.origin=p+Vector3.UP*1.7;q.collision_mask=1;q.exclude=exclude
    for hit in world.get_world_3d().direct_space_state.intersect_shape(q,16):
     if solids.has(hit.collider.get_rid()):public_blocks+=1
 check(public_blocks==0,"mountain scenery preserves all existing public and convoy road corridors")
 var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor)
 var samples: Array[int]=[0,int(region.route.size()/2),region.route.size()-14]
 for start_index in samples:
  actor.position=region.route[start_index]+Vector3.UP*.95;actor.velocity=Vector3.ZERO
  for frame in 20:await physics_frame
  var reached:=0
  for index in range(start_index+1,mini(start_index+11,region.route.size())):
   var goal: Vector3=region.route[index]
   Input.action_press("move_forward")
   for frame in 90:
    var offset: Vector3=goal-actor.global_position;offset.y=0
    if offset.length()<.65:reached+=1;break
    actor.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.z)
    await physics_frame
   Input.action_release("move_forward")
  if reached!=10:print("MOUNTAIN WALK DIAGNOSTIC reached=",reached," position=",actor.position," velocity=",actor.velocity," processing=",actor.is_physics_processing())
  check(reached==10,"actual Arjun walks mountain trail segment "+str(start_index))
 var refuge: Vector3=region.get_node("Northernmountainrefuge").global_position
 actor.position=region.route[-1]+Vector3.UP*.95;actor.velocity=Vector3.ZERO
 for frame in 20:await physics_frame
 for target:Vector3 in [refuge,region.route[-1]]:
  var reached:=false
  Input.action_press("move_forward")
  for frame in 300:
   var offset:Vector3=target-actor.global_position;offset.y=0
   if offset.length()<.55:reached=true;break
   actor.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.z)
   await physics_frame
  Input.action_release("move_forward")
  check(reached,"actual Arjun traverses refuge ramp "+str(target))
 actor.queue_free()
 print("REMOTE MOUNTAINS samples=",region.route.size()," length=",length," missing=",missing," blocked=",blocked," steep=",steep)
 if OS.get_environment("TLM_TUTORIAL_OUTPUT")!="":
  var camera:=Camera3D.new();world.add_child(camera);camera.far=1800
  for label in ["ridge","summit","refuge","crags","path","vessels"]:
   var at: Vector3=region.surface({"ridge":Vector2(570,-440),"summit":Vector2(1000,-700),"refuge":Vector2(968,-930),"vessels":Vector2(968,-930),"crags":Vector2(860,-820),"path":Vector2(region.route[int(region.route.size()/2)].x,region.route[int(region.route.size()/2)].z)}[label])
   camera.position=at+Vector3(-55,30,35) if label=="crags" else at+Vector3(8,6,-10) if label=="refuge" else at+Vector3(35,24,35);if label=="path":
    var index:=int(region.route.size()/2);var forward:Vector3=(region.route[index+8]-region.route[index]).normalized()
    camera.position=at-forward*5+Vector3.UP*2.3;camera.look_at(at+forward*9+Vector3.UP*.5)
   elif label=="vessels":
    var bench:Node3D=region.get_node("RestingBench")
    camera.position=bench.global_position+Vector3(.65,1.05,-1.4);camera.look_at(bench.global_position+Vector3(-.95,.03,0))
   else:camera.look_at(at)
   camera.make_current()
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/mountain_"+label+".png")
  print("MOUNTAIN REVIEW READY")
  var deadline:=Time.get_ticks_msec()+45000
  while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/mountain_done"):await process_frame
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
