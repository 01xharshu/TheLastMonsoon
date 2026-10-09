extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
 root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 var jobs:=world.get_node("ErrandSystem")
 var expected:Dictionary={"office":"record_clerk","port_cargo":"dock_porter","money_receiver":"boatman"}
 var errors:Array=[];var actors:Dictionary={}
 var camera:=Camera3D.new();world.add_child(camera);camera.fov=38
 for endpoint in expected:
  if not jobs.targets.has(endpoint):errors.append(endpoint+": endpoint missing");continue
  var actor:Node3D=jobs.targets[endpoint].person
  if actor==null or actor.get_meta("purpose_role","")!=expected[endpoint]:errors.append(endpoint+": role missing");continue
  if actor.get("animation_tree")==null or (expected[endpoint]=="boatman" and actor.get("purpose_cloth").size()<2):errors.append(endpoint+": animation/cloth not integrated")
  actors[endpoint]={"role":actor.get_meta("purpose_role"),"position":str(actor.global_position),"cloth_meshes":actor.get("purpose_cloth").size()}
  if DisplayServer.get_name()!="headless":
   var aim:=actor.global_position+Vector3.UP*.85
   for offset in [Vector3(1.6,1.25,2.4),Vector3(-1.6,1.25,2.4),Vector3(1.6,1.25,-2.4),Vector3(-1.6,1.25,-2.4)]:
    var candidate:Vector3=actor.global_position+offset
    var query:=PhysicsRayQueryParameters3D.create(candidate,aim,1)
    query.exclude=[actor.get_node("BodyCollider").get_rid(),jobs.targets[endpoint].get_rid()]
    if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():camera.global_position=candidate;break
   camera.look_at(aim);camera.current=true
   await process_frame;RenderingServer.force_draw(false)
   var folder:=OS.get_environment("TLM_REVIEW_DIR")
   if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("purpose_world_"+expected[endpoint]+".png"))
 var report:Dictionary={"passed":errors.is_empty(),"actors":actors,"errors":errors,"scope":"actual world role placement, tree and cloth binding; terrain/cloth motion/art acceptance separate"}
 print("PURPOSE_WORLD ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
