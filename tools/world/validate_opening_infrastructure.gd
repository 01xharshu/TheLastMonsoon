extends SceneTree
var failures: Array[String]=[]
class FixtureWorld:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 if not value:failures.append(label);push_error(label)
func picture(camera: Camera3D,at: Vector3,target: Vector3,label: String,output: String) -> void:
 if output.is_empty() or DisplayServer.get_name()=="headless":return
 camera.global_position=at;camera.look_at(target)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
 var output:=OS.get_environment("TLM_INFRASTRUCTURE_REVIEW_DIR")
 if not output.is_empty() and not output.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 var world:=FixtureWorld.new();root.add_child(world);current_scene=world
 var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.clock_paused=true
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
 player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("UI").hide()
 var stable: Node3D=load("res://horses/village_stable.gd").new();stable.name="VillageStable";world.add_child(stable)
 var house: Node3D=load("res://world/suryagarh/settlements/chacha_house.gd").new();world.add_child(house);house.set_meta("advice_given",true)
 var community: Node3D=load("res://world/suryagarh/settlements/story_community.gd").new();world.add_child(community);community.set_process(false)
 var bridge: Node3D=load("res://world/suryagarh/timber_bridge.gd").new();bridge.name="TimberBridge";world.add_child(bridge)
 var operations: Node3D=load("res://world/suryagarh/settlements/logistics_operations.gd").new();world.add_child(operations);operations.world=world;operations.build_inspection_post(bridge)
 for frame in 30:await physics_frame
 world.get_node("VillageHorse").global_position=Vector3(-400,world.layout.height(-400,230),230)
 check(world.has_node("StableHorse01") and world.has_node("StableHorse02"),"two stable horses remain")
 var booth: Node3D=bridge.get_node("BridgeInspectionPost")
 check(absf(booth.position.z)-1.7>bridge.WIDTH*.5,"inspection post is entirely beside the road")
 check(not bridge.has_node("RevenueCrossingGate"),"bridge has no crossing gate")
 var officer: Node3D=booth.get_node("BridgeInspectionOfficer")
 player.global_position=Vector3(-800,20,-800)
 for frame in 3:await process_frame
 check(officer.position.y<0,"inspection officer stays seated even when Arjun is far away")
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-30,0);sun.light_energy=1.2;world.add_child(sun)
 var sky:=WorldEnvironment.new();sky.environment=Environment.new();sky.environment.background_mode=Environment.BG_COLOR;sky.environment.background_color=Color(.35,.45,.6);sky.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;sky.environment.ambient_light_color=Color(.8,.8,.8);sky.environment.ambient_light_energy=.65;world.add_child(sky)
 var camera:=Camera3D.new();camera.near=.05;camera.fov=55;world.add_child(camera);camera.make_current()
 await picture(camera,stable.to_global(Vector3(9,4.2,10)),stable.to_global(Vector3(0,1.1,0)),"stocked_stable",output)
 await picture(camera,booth.to_global(Vector3(0,1.65,-5.5)),booth.to_global(Vector3(0,1,.2)),"bridge_inspection",output)
 await picture(camera,house.to_global(Vector3(-19,17,30)),house.to_global(Vector3(-12,1.2,6)),"family_boundary_farm",output)
 print("OPENING INFRASTRUCTURE: "+("PASS" if failures.is_empty() else str(failures)))
 world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,code)
