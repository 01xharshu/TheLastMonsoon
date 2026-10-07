extends SceneTree
const Output=preload("res://tools/animals/disposable_review.gd")
var viewport:SubViewport
var camera:Camera3D
var world:Node3D
var jobs:Node3D
var actor:CharacterBody3D
var folder:="roadside/"
func _initialize() -> void:run.call_deferred()
func still(label:String,at:Vector3,target:Vector3) -> void:
 camera.global_position=at;camera.look_at(target)
 for frame in 5:
  jobs.roadside._physics_process(1.0/60.0)
  await process_frame
 await RenderingServer.frame_post_draw
 Output.save_png(viewport.get_texture().get_image(),folder+label+".png")
 print("ROADSIDE_CAPTURE ",label)
func run() -> void:
 root.size=Vector2i(960,540);root.disable_3d=true
 viewport=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var display:=TextureRect.new();display.texture=viewport.get_texture();display.size=Vector2(960,540);display.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(display)
 world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 actor=world.get_node("Player");actor.set_physics_process(false);actor.get_node("UI").hide()
 actor.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
 world.get_node("GameTimeSystem").clock_paused=true
 jobs=world.get_node("ErrandSystem");jobs.roadside.set_physics_process(false);jobs.expanded.set_physics_process(false)
 camera=Camera3D.new();camera.fov=48;viewport.add_child(camera);camera.make_current()
 var road:Node=jobs.roadside
 road.locations.road_letter=Vector3(-245,7.2,225);road._spawn("road_letter")
 var person:Node3D=jobs.targets.road_letter_caller.person
 actor.global_position=person.global_position+Vector3(0,0,1.5)
 var ray:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*10,actor.global_position-Vector3.UP*10,1,[actor.get_rid()]))
 if not ray.is_empty():actor.global_position.y=ray.position.y+.93
 actor.rotation.y=0
 actor.get_node("VisualRoot/CharacterVisual").equipment.stowed=true
 jobs.source="road_letter_caller";jobs.accept("road_letter");jobs.use_endpoint("road_letter_caller",actor);road._physics_process(.02)
 await still("caller_and_carried_letter",person.global_position+Vector3(3,2.1,4),person.global_position+Vector3(0,1,1))
 jobs.cancel()
 road.locations.road_office_bag=person.global_position;road._spawn("road_office_bag")
 actor.global_position=person.global_position+Vector3(0,.9,1)
 jobs.source="road_office_bag_caller";jobs.accept("road_office_bag");jobs.use_endpoint("road_office_bag_caller",actor)
 road._physics_process(.02)
 await still("carried_dispatch_bag",actor.global_position+Vector3(2,1,2),actor.global_position)
 actor.global_position=jobs.targets.road_office_desk.global_position+Vector3(1.4,0,.8)
 actor.global_position.y=jobs.floor_levels.parcel+.93
 jobs.use_endpoint("road_office_desk",actor)
 await still("dispatch_bag_placed",jobs.targets.road_office_desk.global_position+Vector3(-2,1,2),jobs.targets.road_office_desk.global_position)
 road.locations.road_warehouse_crate=person.global_position;road._spawn("road_warehouse_crate")
 actor.global_position=person.global_position+Vector3(0,.9,1)
 jobs.source="road_warehouse_crate_caller";jobs.accept("road_warehouse_crate");jobs.expanded.borrowed.global_position=person.global_position+Vector3(-2,0,0)
 jobs.use_endpoint("road_warehouse_crate_caller",actor);road._physics_process(.02)
 var loaded:Node3D=road.cargo_cart
 if loaded!=null:await still("loaded_warehouse_crate",loaded.to_global(Vector3(-4,3,0)),road.cargo.global_position)
 jobs.cancel()
 if "--prop-only" in OS.get_cmdline_user_args():print("ROADSIDE PROPS COMPLETE");quit();return
 road.locations.road_injured=Vector3(-245,7.2,210);road._spawn("road_injured")
 person=jobs.targets.road_injured_caller.person;actor.global_position=person.global_position+Vector3(0,0,1.2)
 jobs.source="road_injured_caller";jobs.accept("road_injured")
 var cart:Node3D=jobs.expanded.borrowed;cart.global_position=person.global_position+Vector3(-2,0,0)
 jobs.expanded.use_endpoint("road_injured_caller")
 cart=jobs.expanded.cart
 for frame in 90:
  jobs.expanded._physics_process(1.0/30.0)
  if frame in [20,45,89]:await still("injured_boarding_%03d"%frame,cart.to_global(Vector3(-5,3,4)),cart.to_global(Vector3(0,1.5,2)))
  await process_frame
  await RenderingServer.frame_post_draw
  Output.save_png(viewport.get_texture().get_image(),"roadside_boarding/%04d.png"%frame)
 cart.global_position=jobs.targets.road_hospital.person.global_position+Vector3(-3,0,4)
 var hospital_ground:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cart.global_position+Vector3.UP*2,cart.global_position-Vector3.UP*3,1,cart.boarding._vehicle_exclusions()))
 if not hospital_ground.is_empty():cart.global_position.y=hospital_ground.position.y
 for frame in 3:await physics_frame
 actor.global_position=jobs.targets.road_hospital.global_position+Vector3(0,0,1)
 jobs.use_endpoint("road_hospital",actor)
 for frame in 90:
  jobs.expanded._physics_process(1.0/30.0)
  if frame in [20,45,89]:await still("hospital_exit_%03d"%frame,cart.to_global(Vector3(-6,3,4)),cart.to_global(Vector3(0,1.5,2)))
  await process_frame
  await RenderingServer.frame_post_draw
  Output.save_png(viewport.get_texture().get_image(),"roadside_exit/%04d.png"%frame)
 await still("hospital_receiving_context",cart.global_position+Vector3(-10,5,10),jobs.targets.road_hospital.person.global_position+Vector3.UP)
 print("ROADSIDE_CAPTURE COMPLETE | native Metal stills plus 90-frame 30 Hz transfer sequences for 1x playback; whole-game performance separate")
 quit()
