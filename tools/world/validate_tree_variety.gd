extends SceneTree
const Variety=preload("res://world/suryagarh/tree_variety.gd")
const Ground=preload("res://world/suryagarh/tree_trunk_collision.gd")
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Tree instance checks require a native renderer");quit(2);return
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var land:=Node3D.new();land.name="PaletteLandscape";scene.add_child(land)
 var nature:=Node3D.new();nature.name="NatureTiles";land.add_child(nature)
 var body:=StaticBody3D.new();body.name="GroundCollision";land.add_child(body)
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,.2,200);collision.shape=box;collision.position.y=-.1;body.add_child(collision)
 var visual:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);visual.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.28,.32,.15);visual.material_override=mat;land.add_child(visual)
 var asset:Node3D=load("res://assets/nature/models/island_tree_02.glb").instantiate()
 var original:Mesh=asset.find_children("*","MeshInstance3D",true,false)[0].mesh
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=original;mm.instance_count=32
 for i in 32:mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3((i%8)*10-35,0,(i/8)*12-18)))
 var batch:=MultiMeshInstance3D.new();batch.name="BroadleafTrees";batch.multimesh=mm;nature.add_child(batch);asset.free()
 for i in 3:await physics_frame
 await Ground.repair_landscape(land)
 var count:=await Variety.configure_landscape(land)
 check(count==32,"all original tree slots retained")
 check(nature.find_children("*","StaticBody3D",true,false).size()==1,"one physical trunk body retained for mixed tile")
 check(land.get_meta("tree_variety_counts").size()==7,"seven distinct shapes distributed")
 check(await Variety.configure_landscape(land)==0,"repeat setup is idempotent")
 check(mm.instance_count==32,"baked source resource unmodified")
 for i in 3:await physics_frame
 var meshes:Dictionary={};var rooted:=0
 for item in nature.find_children("BroadleafTrees*","MultiMeshInstance3D",true,false):
  meshes[item.multimesh.mesh.get_instance_id()]=true
  var profile:=Ground.profile(item.multimesh.mesh)
  check(profile.size()==3,"variant has measured woody trunk")
  for transform in Ground.instance_transforms(item.multimesh):
   var base:Vector3=profile[0].centre-Vector3.UP*float(profile[0].height)*.5
   var root_at:Vector3=item.to_global(transform*base)
   check(absf(root_at.y+.12)<.025,"root embeds terrain")
   var centre:Vector3=item.to_global(transform*profile[1].centre)
   var ray:=PhysicsRayQueryParameters3D.create(centre+Vector3.RIGHT*3,centre-Vector3.RIGHT*3,1)
   var hit:=scene.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and hit.collider.get_meta("tree_trunk_geometry",false),"solid visible trunk")
   if item.get_meta("tree_variety","")=="banyan":
    for prop in item.multimesh.mesh.get_meta("prop_roots"):
     var foot:Vector3=item.to_global(transform*(prop.centre-Vector3.UP*float(prop.height)*.5))
     check(foot.y<=.005,"banyan prop foot reaches soil")
     var mid:Vector3=item.to_global(transform*prop.centre)
     var prop_hit:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mid+Vector3.RIGHT,mid-Vector3.RIGHT,1))
     check(not prop_hit.is_empty() and prop_hit.collider.get_meta("tree_trunk_geometry",false),"banyan prop has solid wood")
     var gap:=root_at.lerp(foot,.5)+Vector3.UP*.8
     var gap_hit:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(gap+Vector3.UP*.05,gap-Vector3.UP*.05,1))
     check(gap_hit.is_empty(),"space between banyan trunks stays walkable")
   rooted+=1
 check(meshes.size()==7 and rooted==32,"seven mesh identities and exact live count")
 var output:=OS.get_environment("TLM_TREE_REVIEW")
 if DisplayServer.get_name()!="headless" and not output.is_empty():
  var env:=WorldEnvironment.new();var lighting:=Environment.new();lighting.background_mode=Environment.BG_COLOR;lighting.background_color=Color(.55,.69,.78);lighting.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;lighting.ambient_light_color=Color.WHITE;lighting.ambient_light_energy=.65;env.environment=lighting;scene.add_child(env)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);scene.add_child(sun)
  var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(45,15,50);camera.look_at(Vector3(0,4,0));camera.make_current()
  for i in 10:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("tree_palette.png"))
  for index in 3:
   var kind:String=["peepal","banyan","palm"][index]
   var specimen:=MeshInstance3D.new();specimen.mesh=Variety.mesh_for(kind);scene.add_child(specimen);specimen.position=Vector3(0,0,65)
   var height:float=specimen.mesh.get_aabb().size.y
   camera.position=specimen.position+Vector3(height*1.0,height*.65,height*1.4);camera.look_at(specimen.position+Vector3.UP*height*.48)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join(kind+"_specimen.png"))
   specimen.queue_free()
  print("TREE REVIEW READY ",output)
  var deadline:=Time.get_ticks_msec()+90000
  while not FileAccess.file_exists(output.path_join("review_done")) and Time.get_ticks_msec()<deadline:await process_frame
 print("TREE VARIETY: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
 quit(0 if failures.is_empty() else 1)
