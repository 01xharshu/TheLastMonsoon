extends SceneTree
var actors:Array[Node3D]=[]
var controllers:Array[Node]=[]
var camera:Camera3D
var frame:=0
var last_engine_frame:=-1
var errors:Array[String]=[]
var folder:="res://docs/world/household_cloth_2026-10-05/"
func _initialize() -> void:call_deferred("_setup")
func _setup() -> void:
 root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.22,.25,.28)
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.65
 environment.environment=settings;scene.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.4;scene.add_child(light)
 _box(scene,Vector3(0,-.06,0),Vector3(14,.12,9),Color(.39,.36,.30))
 var files:=["households/merchant","households/landowner","british/official_woman"]
 for index in 3:
  var actor:Node3D=load("res://characters/npcs/households/household_npc_actor.gd").new()
  actor.movement_profile=&"female" if index==2 else &"male";actor.movement_enabled=false;actor.foot_plant_enabled=false
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  if document.append_from_file(ProjectSettings.globalize_path("res://characters/npcs/"+files[index]+".glb"),state)!=OK:errors.append("GLB failed "+files[index]);continue
  actor.add_child(document.generate_scene(state));actor.position.x=(index-1)*2.5;scene.add_child(actor);actor.set_process(false)
  actor.get_node("BodyCollider/BodyShape").disabled=true;actors.append(actor)
  var controller:Node=load("res://world/suryagarh/settlements/household_resident_journey.gd").new();controller.actor=actor;scene.add_child(controller);controllers.append(controller)
  var drape:Node=load("res://characters/npcs/households/household_drape.gd").new();drape.measure_cost=true;actor.add_child(drape)
  if not drape.configure(actor):errors.append("garment missing "+files[index])
  actor.set_meta("household_drape",drape)
  _box(scene,Vector3(actor.position.x,.69,-.05),Vector3(.62,.08,.52),Color(.15,.09,.05))
  for x in [-.25,.25]:
   for z in [-.25,.15]:_box(scene,Vector3(actor.position.x+x,.33,z),Vector3(.065,.66,.065),Color(.15,.09,.05))
 camera=Camera3D.new();camera.position=Vector3(5.3,2.6,7.5);camera.fov=45;scene.add_child(camera);camera.look_at(Vector3(0,1,0));camera.make_current()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for i in 3:await process_frame
 DirAccess.make_dir_recursive_absolute("/tmp/household_motion_frames")
 for sample in 720:
  _frame()
  await process_frame
  await RenderingServer.frame_post_draw
  var rendered:=root.get_texture().get_image()
  rendered.save_png("/tmp/household_motion_frames/%04d.png"%frame)
 func _finish() -> void:
 var metrics:Array=[]
 for actor in actors:
  var drape:Node=actor.get_meta("household_drape")
  var costs:PackedInt32Array=drape.rebuild_costs;costs.sort()
  metrics.append({"name":str(actor.name),"rebuilds":drape.rebuilds,"median_rebuild_us":costs[costs.size()/2],"p95_rebuild_us":costs[int(costs.size()*.95)],"max_rebuild_us":drape.max_rebuild_us})
 var report:={"passed":errors.is_empty(),"errors":errors,"frames":frame,"duration_seconds":24,"fps":30,"actors":metrics,"scope":"isolated native cloth walking/climb/sit/stand fixture; fixed-time PNG frames encoded at 30 FPS, not hardware FPS or full-world motion/historical approval"}
 FileAccess.open(folder+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("HOUSEHOLD_DRAPE_REVIEW ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
func _box(scene:Node3D,at:Vector3,size:Vector3,color:Color) -> void:
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at
 var material:=StandardMaterial3D.new();material.albedo_color=color;node.material_override=material;scene.add_child(node)
