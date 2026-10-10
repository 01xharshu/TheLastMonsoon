extends SceneTree
var failures: Array[String]=[]
class WorldFixture:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
class Manager:
 extends Node
 var player: CharacterBody3D
 var active:=""
 var goal:=Vector3(0,1,-10)
 func destination() -> Dictionary:return {"position":goal,"label":"Chacha's house","endpoint":""}
 func tracked_objective() -> String:return "Return to Chacha"
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 if not value:failures.append(label);push_error(label)
func run() -> void:
 var world:=WorldFixture.new();root.add_child(world);current_scene=world
 var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
 player.set_physics_process(false)
 var camera: Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
 camera.make_current();camera.global_position=Vector3(0,2,5);camera.look_at(Vector3(0,1,0))
 var manager:=Manager.new();manager.player=player;world.add_child(manager)
 var layer:=CanvasLayer.new();world.add_child(layer)
 var marker:=preload("res://world/suryagarh/errands/destination_marker.gd").new();marker.manager=manager;layer.add_child(marker)
 await process_frame
 marker.refresh();check(marker.visible and not marker.at_edge,"One on-screen marker renders the destination")
 manager.goal=Vector3(-1000,1,-10);marker.refresh()
 check(marker.at_edge and marker.marker_position.x<80,"Left destination has a left-edge marker")
 check(marker.distance_text.ends_with("m") and not " " in marker.distance_text,"Reference distance format")
 manager.goal=Vector3(0,1,100);marker.refresh();check(marker.at_edge,"Behind-camera guidance stays at the edge")
 player.set_meta("story_cinematic",true);marker.refresh();check(not marker.visible,"Cinematic hides navigation")
 player.set_meta("story_cinematic",false)
 var world_stake:=preload("res://player/world_waypoint.gd").new();world.add_child(world_stake)
 check(not world_stake.is_processing() and not world_stake.visible,"Duplicate world beacon disabled")
 var output:=OS.get_environment("TLM_MARKER_REVIEW_DIR")
 if not output.is_empty() and DisplayServer.get_name()!="headless":
  if not output.begins_with(OS.get_environment("TMPDIR")):quit(2);return
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720))
  manager.goal=Vector3(-1000,1,-10);marker.refresh()
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("single_marker.png"))
 print("SINGLE LOCATION MARKER: "+("PASS" if failures.is_empty() else str(failures)))
 world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,code)
