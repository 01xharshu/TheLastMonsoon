extends SceneTree
## Actual-world hideout render/clearance review; images only in temporary output.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var output:=OS.get_environment("TLM_HIDEOUT_REVIEW_PATH")
 if output.is_empty() or not output.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 root.get_node("SaveManager").save_root=output
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 var deadline:=Time.get_ticks_msec()+120000
 while not world.has_node("RebellionStory") and Time.get_ticks_msec()<deadline:await process_frame
 if not world.has_node("RebellionStory"):push_error("Hideout story missing");quit(1);return
 var story:Node=world.get_node("RebellionStory")
 while not story.configured and Time.get_ticks_msec()<deadline:await process_frame
 if not story.configured:push_error("Hideout setup timed out");quit(1);return
 var cellar:Node3D=story.sites.cellar
 if not cellar.has_node("HideoutEnvironment"):push_error("Hideout environment missing");quit(1);return
 story.set_process(false);story.sites.set_enabled(true)
 var opening:Node=world.get_node_or_null("OpeningSequence")
 if opening!=null:opening.set_process(false)
 var player:Node3D=world.get_node("Player");player.get_node("UI").hide();player.visible=false;player.set_physics_process(false);player.global_position=cellar.to_global(Vector3(0,1.0,4))
 player.set_meta("opening_active",false);player.set_meta("story_cinematic",false)
 story.set_stage("complete")
 var daily:Node=cellar.get_node("HideoutDailyLife")
 var spawn_deadline:=Time.get_ticks_msec()+60000
 while daily.records.size()<daily.JOBS.size() and Time.get_ticks_msec()<spawn_deadline:await process_frame
 if daily.records.size()!=daily.JOBS.size():push_error("Hideout population did not finish spawning");quit(1);return
 for frame in 30:await process_frame
 # Exercise actual distance activation without disabling the story/save owner.
 var home:Vector3=player.global_position
 var clock_before:float=daily.routine_clock
 player.global_position=home+Vector3(420,0,0)
 for frame in 12:await process_frame
 if not daily.remote_visuals or daily.records[0].actor.animation_tree.active:
  push_error("Remote camp visual work did not suspend");quit(1);return
 if daily.routine_clock<=clock_before:
  push_error("Remote camp schedule stopped");quit(1);return
 var previous_active:bool=story.active
 story.active=true
 for frame in 3:await process_frame
 if daily.mangal_visual_suspended or not story.sites.mangal.is_processing():
  push_error("Mission ownership did not wake distant Mangal");quit(1);return
 story.active=previous_active
 player.global_position=home
 for frame in 12:await process_frame
 if daily.remote_visuals or not daily.records[0].actor.animation_tree.active:
  push_error("Nearby camp visual work did not resume");quit(1);return
 var saved:Dictionary=daily.export_state()
 daily.routine_clock=999.0;daily.restore_state(saved)
 if absf(daily.routine_clock-float(saved._routine_clock))>.001:
  push_error("Camp routine clock failed save round trip");quit(1);return
 for role in ["gun_cleaner","cook","drinker","drinking_partner"]:
  if not daily.has_node("Camp_"+role):push_error("Missing camp job "+role);quit(1);return
 var routine_restore:float=daily.routine_clock
 for task in [[80.0,"rifle_check"],[120.0,"rest"],[45.0,"planning"]]:
  daily.routine_clock=task[0]
  for frame in 3:await process_frame
  if str(story.sites.mangal.get_meta("hideout_task",""))!=task[1]:
   push_error("Mangal free-time task did not change");quit(1);return
 daily.routine_clock=routine_restore
 print("PASS hideout14 jobs, distance suspension/resume and routine save clock")
 var camera:=Camera3D.new();camera.fov=68;cellar.add_child(camera);camera.current=true
 for view in [
  ["work_corner",Vector3(-2.7,2.0,-2.5),Vector3(-4.8,.7,-4.5)],
  ["gun_cleaner",Vector3(3.6,1.7,-1.8),Vector3(5.3,.9,-3.8)],
  ["drinking",Vector3(-3.1,1.8,3.4),Vector3(-5.4,1.0,5.2)],
  ["entrance",Vector3(6,6.8,26),Vector3(0,2.1,8)],
  ["passage",Vector3(0,4.9,21),Vector3(0,1.8,3)],
  ["interior",Vector3(0,2.3,5.8),Vector3(0,1.5,-4)],
  ["interior_side",Vector3(-4,2.1,4.8),Vector3(5,1.4,-2)],
  ["discussion",Vector3(-1.0,1.9,4.8),Vector3(-3.6,1.0,2)],
  ["rest",Vector3(-5.2,1.7,6.0),Vector3(-7.7,.65,3.6)],
  ["roof_watch",Vector3(4,6.0,1),Vector3(7,5,-4.5)],
  ["carrier",Vector3(2,5.0,25),Vector3(-2,4.6,21)],
  ["gate_watch",Vector3(6.5,5.7,26),Vector3(3,4.5,22)],
  ["terrace_supports",Vector3(10,2.8,31),Vector3(0,3,22)]
 ]:
  camera.global_position=cellar.to_global(view[1]);camera.look_at(cellar.to_global(view[2]));camera.make_current()
  for i in 8:await process_frame
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("hideout_"+view[0]+".png"))
 # Observe real-time gait and hand contact without moving the actor by script.
 var carrier:Node3D=daily.get_node("Camp_carry_supplies")
 for side in ["l","r"]:
  var index:int=carrier._skeleton.find_bone("hand_"+side)
  print("HIDEOUT HAND REST ",side," ",carrier.to_local(carrier._skeleton.to_global(carrier._skeleton.get_bone_global_rest(index).origin)))
 var start_distance:float=daily.records[7].travelled
 var start:=Time.get_ticks_msec();var peak_hand:=0.0;var peak_low_ankle:float=-INF;var min_low_ankle:float=INF;var sample:=0
 camera.global_position=carrier.to_global(Vector3(1.4,1.5,2.2));camera.look_at(carrier.to_global(Vector3(0,1,.3)));camera.make_current()
 while Time.get_ticks_msec()-start<3600:
  await process_frame
  peak_hand=maxf(peak_hand,maxf(float(carrier.get_meta("hand_contact_l",0.0)),float(carrier.get_meta("hand_contact_r",0.0))))
  var ankle_l:Vector3=carrier._skeleton.to_global(carrier._skeleton.get_bone_global_pose(carrier._skeleton.find_bone("foot_l")).origin)
  var ankle_r:Vector3=carrier._skeleton.to_global(carrier._skeleton.get_bone_global_pose(carrier._skeleton.find_bone("foot_r")).origin)
  var low_ankle:float=minf(ankle_l.y,ankle_r.y)-cellar.to_global(Vector3(0,3.7,0)).y
  peak_low_ankle=maxf(peak_low_ankle,low_ankle);min_low_ankle=minf(min_low_ankle,low_ankle)
  if DisplayServer.get_name()!="headless" and Time.get_ticks_msec()-start>=sample*1200 and sample<3:
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("hideout_carrier_motion_%d.png"%sample));sample+=1
 var travelled:float=daily.records[7].travelled-start_distance
 print("HIDEOUT CARRIER LIVE metres=",travelled," peak_hand_m=",peak_hand," min_low_ankle_m=",min_low_ankle," max_low_ankle_m=",peak_low_ankle)
 if travelled<.3:push_error("Hideout carrier did not travel during real-time review");quit(1);return
 if peak_hand>.03:push_error("Hideout carrier hand contact exceeds 30 mm");quit(1);return
 print("HIDEOUT ENVIRONMENT REVIEW READY ",output)
 if DisplayServer.get_name()!="headless":
  var until:=Time.get_ticks_msec()+90000
  while Time.get_ticks_msec()<until and not FileAccess.file_exists(output.path_join("hideout_done")):await process_frame
 root.get_node("SaveManager").quit_game(0)
