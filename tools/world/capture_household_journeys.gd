extends SceneTree
var captured:Dictionary={}
var camera:Camera3D
var folder:="res://docs/world/household_journeys_2026-10-01/"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 world.get_node("Player").hide();world.get_node("Player").set_physics_process(false)
 world.get_node("Player/UI").hide();world.get_node("LandscapeUI").hide()
 for frame in 8:await physics_frame
 world.get_node("GameTimeSystem").clock_paused=true
 camera=Camera3D.new();camera.fov=50;world.add_child(camera);camera.make_current()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var coaches:=get_nodes_in_group("household_coach")
 for coach in coaches:coach.get_node("HouseholdTravel").set_physics_process(false)
 for frame in 4000:
  for coach in coaches:
   var travel:Node=coach.get_node("HouseholdTravel");travel.step(.1)
   for journey in travel.journeys:
    var label:String=str(journey.actor.name).to_snake_case()+"_"+journey.state
    if captured.has(label):continue
    if journey.state not in ["leave_home","climb_step","enter_coach","sit_down","climb_down","enter_office","sit_at_desk","work","enter_home"]:continue
    if journey.elapsed<.65:continue
    if journey.state in ["leave_home","enter_home"] and journey.point<1:continue
    if journey.state=="enter_office" and journey.point<2:continue
    var actor:Node3D=journey.actor
    if journey.state in ["sit_at_desk","work"]:
     camera.global_position=travel.office.to_global(Vector3(-3 if journey.office_side<0 else 3,2.1,1.8));camera.look_at(actor.global_position+Vector3.UP*1.0)
    elif journey.state=="enter_office":
     camera.global_position=travel.office.to_global(Vector3(0,2.4,7));camera.look_at(actor.global_position+Vector3.UP*.9)
    elif journey.state in ["climb_step","enter_coach","sit_down","climb_down"]:
     camera.global_position=travel.coach.to_global(Vector3(journey.side*4,2.8,3.8));camera.look_at(actor.global_position+Vector3.UP*.9)
    else:
     camera.global_position=actor.global_position+Vector3(2.8,2,4);camera.look_at(actor.global_position+Vector3.UP*.8)
    for redraw in 4:await process_frame
    RenderingServer.force_draw(false)
    var error:=root.get_texture().get_image().save_png(folder+label+".png")
    captured[label]=true;print("JOURNEY_CAPTURE ",label," ",error," desk_error ",actor.get_meta("desk_hand_error_m",-1))
  await physics_frame
  if captured.size()>=36:break
 FileAccess.open(folder+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":captured.keys(),"scope":"Metal transition stills; continuous motion and garment contact remain review"},"  ")+"\n")
 quit()
