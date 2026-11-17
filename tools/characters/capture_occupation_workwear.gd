extends "res://tools/characters/export_occupation_native_surfaces.gd"
## Native lighting/front-side-back rejection views; caller deletes all output.
var review_camera:Camera3D
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Native renderer required");quit(2);return
 root.size=Vector2i(900,900)
 var stage:=Node3D.new();root.add_child(stage)
 var light:=DirectionalLight3D.new();stage.add_child(light)
 light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.2
 var world:=WorldEnvironment.new();stage.add_child(world);world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color(.25,.28,.30)
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.65
 var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(6,6)
 floor_mesh.mesh=plane;stage.add_child(floor_mesh)
 review_camera=Camera3D.new();stage.add_child(review_camera);review_camera.current=true
 review_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;review_camera.size=2.0
 await super.run()

func capture_pose(actor:Node3D,label:String,sample:int,folder:String) -> void:
 if sample!=16 and not (sample==3 and label in ["walk","repair","rise"]):return
 for view in [["front",Vector3(0,1.1,4)],["side",Vector3(4,1.1,0)],["back",Vector3(0,1.1,-4)]]:
  review_camera.position=actor.global_position+Vector3(view[1])
  review_camera.look_at(actor.global_position+Vector3(0,.75,0))
  await process_frame
  RenderingServer.force_draw(false)
  var result:=root.get_texture().get_image().save_png(folder+"/"+label+("_mid" if sample==3 else "")+"_"+str(view[0])+".png")
  assert(result==OK)
 print("OCCUPATION_NATIVE_REVIEW ",label)
