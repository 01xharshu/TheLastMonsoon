extends SceneTree
var actors:Array[Node3D]=[]
var controllers:Array[Node]=[]
var camera:Camera3D
var frame:=0
var last_engine_frame:=-1
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("_setup")
func _setup() -> void:
 root.scaling_3d_scale=1.0;root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.22,.25,.28)
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.65
 environment.environment=settings;scene.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.4;scene.add_child(light)
 _box(scene,Vector3(0,.18,0),Vector3(14,.12,9),Color(.39,.36,.30))
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
  _box(scene,Vector3(actor.position.x,.69,-.05),Vector3(.62,.12,.52),Color(.15,.09,.05))
  for x in [-.25,.25]:
   for z in [-.25,.15]:_box(scene,Vector3(actor.position.x+x,.46,z),Vector3(.065,.46,.065),Color(.15,.09,.05))
 camera=Camera3D.new();camera.position=Vector3(5.3,2.6,7.5);camera.fov=45;scene.add_child(camera);camera.look_at(Vector3(0,1,0));camera.make_current()
 var temporary:=OS.get_environment("TLM_HOUSEHOLD_REVIEW_TEMP")
 var samples:Array=range(720)
 if "--poses-only" in OS.get_cmdline_user_args():samples=[29,104,329]
 for sample in samples:
  root.scaling_3d_scale=1.0;root.msaa_3d=Viewport.MSAA_4X
  _pose(sample+1)
  await process_frame
  if "--poses-only" in OS.get_cmdline_user_args():
   camera.position=Vector3(4.5,1.8,3.8);camera.look_at(Vector3(1.6,1,0))
   for redraw in 3:await process_frame
  if not temporary.is_empty() and sample+1 in [30,105,330]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(temporary+"/pose_%03d.png"%(sample+1))
 if not temporary.is_empty():
  print("REVIEW_READY ",temporary)
  await create_timer(45).timeout
 _finish()
func _pose(sample:int) -> void:
 frame=sample
 var time:=frame/30.0
 for index in actors.size():
  var actor:Node3D=actors[index];var controller:Node=controllers[index]
  actor.travel_speed=1.0 if time<2 or time>21 else 0.0
  actor.call("_set_animation",&"walk" if time<2 or time>21 else &"idle",1.0/30)
  var seated:=0.0
  if time>=5 and time<8:seated=smoothstep(0,1,(time-5)/3)
  elif time>=8 and time<14:seated=1
  elif time>=14 and time<17:seated=1-smoothstep(0,1,(time-14)/3)
  if time>=2 and time<=21:
   for suffix in ["l","r"]:
    controller._pitch("thigh_"+suffix,-1.5*seated);controller._pitch("calf_"+suffix,1.5*seated)
  if time>=2 and time<5:
   var lift:=sin((time-2)/3*PI)
   controller._pitch("thigh_l",-1.15*lift);controller._pitch("calf_l",1.65*lift)
  elif time>=17 and time<=21:
   var lift:=sin((time-17)/4*PI)
   controller._pitch("thigh_r",-1.15*lift);controller._pitch("calf_r",1.65*lift)
  var rig:Skeleton3D=actor.get("_skeleton");rig.force_update_all_bone_transforms()
  var hip:Vector3=rig.get_bone_global_pose(rig.find_bone("pelvis")).origin
  actor.position.y=.24+(.75-(rig.transform*hip).y-.24)*seated
  actor.position.z=.65*(1-seated)
  if seated>0:controller._plant_seated_feet(.24,seated)
  var drape:Node=actor.get_meta("household_drape");drape.update_pose()
  if drape.garment.mesh==null:errors.append("empty garment")
func _finish() -> void:
 var metrics:Array=[]
 for actor in actors:
  var drape:Node=actor.get_meta("household_drape")
  var costs:PackedInt32Array=drape.rebuild_costs;costs.sort()
  metrics.append({"name":str(actor.name),"rebuilds":drape.rebuilds,"median_rebuild_us":costs[costs.size()/2],"p95_rebuild_us":costs[int(costs.size()*.95)]})
 print("HOUSEHOLD_DRAPE_REVIEW ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"frames":frame,"actors":metrics,"scope":"isolated native pose fixture; full-world contact remains separate"}))
 quit(0 if errors.is_empty() else 1)
func _box(scene:Node3D,at:Vector3,size:Vector3,color:Color) -> void:
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at
 var material:=StandardMaterial3D.new();material.albedo_color=color;node.material_override=material;scene.add_child(node)
