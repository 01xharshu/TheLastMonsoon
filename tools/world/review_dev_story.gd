extends SceneTree
## Real new-game opening -> station gate -> film -> recovery -> farm/map checkpoint.
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 var manager: Node=root.get_node("SaveManager");manager.save_root=temporary;manager.pending_slot=0
 var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 if OS.get_environment("TLM_INQUIRY_ISOLATE_RIVER")=="1":
  for node in world.find_children("*","Node",true,false):
   if node.get_script()!=null and node.get_script().resource_path.ends_with("village_river_routine.gd"):node.set_physics_process(false)
  print("STORY WORLD: river routine isolated in fixture")
 for frame in 30:await physics_frame
 var story: Node=world.get_node("DevStory");var inquiry: Node=world.get_node("DevInquiry");var player: CharacterBody3D=world.get_node("Player")
 var opening: Node=world.get_node("OpeningSequence")
 check(story.configured and inquiry.stage=="dormant","story waits for main opening")
 var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.pressed=true;opening._input(event)
 await create_timer(.9).timeout;check(inquiry.stage=="dormant","morning seat precedes story")
 # The opening now owns the complete dawn rise and walk out of the house.
 opening._process(25.0);await process_frame
 check(opening.state=="done","morning releases control")
 var tutorial: Node=player.get_node_or_null("UI/HUDRoot/MorningTutorial")
 if tutorial!=null:
  # Onboarding owns the new-game interval before the police objective.
  while tutorial.step<11:tutorial.advance()
 check(inquiry.stage=="police","completed morning onboarding starts police objective")
 # Relocate once from home, then approach the gate using the real controller.
 player.global_position=inquiry.station.to_global(Vector3(0,.9,24));player.velocity=Vector3.ZERO
 player.get_node("CameraPivot").global_rotation.y=0
 Input.action_press("move_forward")
 for frame in 600:
  await physics_frame
  if story.active:break
 Input.action_release("move_forward")
 check(story.active and story.kind=="inquiry","walking through main station gate triggers film")
 print("STORY WORLD: gate cinematic active ",story.active)
 var reviewed: Array[String]=[]
 var natural:=OS.get_environment("TLM_STORY_NATURAL")=="1"
 while story.active:
  if natural:
   await physics_frame
   if story.age>1 and story.cue not in reviewed:
    reviewed.append(story.cue)
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(temporary+"/"+story.cue+".png")
  else:
   story._process(float(story.beats[story.beat_index].seconds)+.1);await process_frame
 check(story.state=="farm" and player.is_physics_processing(),"main film ends at recovery checkpoint")
 check(inquiry.destination.global_position==story.community.farm.global_position,"farm map destination integrated")
 check(manager.save_game(world,1),"main recovery checkpoint saves")
 story.state="awaiting_inquiry";manager.pending_slot=1;manager.apply_pending(world)
 check(story.state=="farm" and inquiry.stage=="released","main load restores film completion and farm objective")
 check(story.community.members.size()==3,"farm partners present in main world")
 check(story.community.college.has_meta("parking_label") and story.community.courtyard.has_meta("parking_label"),"main map gathering places discoverable")
 print("DEV STORY WORLD: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,code)
