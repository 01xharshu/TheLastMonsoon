extends "res://tools/world/validate_consignment_story.gd"
## Sustained native real-world review. No fixed deltas, frozen mounts or fake damage.
## Checkpoints/extra review-only health and cartridges keep the same pair observable.
var story:Node
var player:CharacterBody3D
var camera:Camera3D
var observer:Camera3D
var output=""
var metrics:Dictionary={}
var previous_cart:=Transform3D.IDENTITY
var elapsed=0.0
var next_shot=2.5
var previous_reload=false
var reloads=0
var total_samples=0

func run() -> void:
 output=OS.get_environment("TLM_CONSIGNMENT_REVIEW_PATH")
 if DisplayServer.get_name()=="headless" or output.is_empty():push_error("Live review requires --native --review");quit(2);return
 var saves:Node=root.get_node("SaveManager");saves.save_root=OS.get_environment("TLM_STORY_TEST_DIR")
 saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.apply_options()
 saves.start_new_game();await scene_changed
 var world:Node3D=current_scene;story=world.get_node("ConsignmentStory");player=world.get_node("Player")
 var start:=Time.get_ticks_msec()
 while not story.configured:
  await process_frame
  if Time.get_ticks_msec()-start>120000:push_error("Live world preparation timed out");saves.quit_game(1);return
 var opening:Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip);await process_frame;opening._input(skip)
 while opening.state!="done":await process_frame
 # This checkpoint begins after the first rebellion mission, which itself follows
 # completed onboarding. Do not leave the new-game tutorial over a later mission.
 player.get_node("UI/HUDRoot/MorningTutorial").restore_step(11)
 var clock:Node=world.get_node("GameTimeSystem");clock.current_hour=10;clock.total_game_minutes=600;clock.clock_paused=true;clock._update_readable_time(true)
 var first:Node=world.get_node("RebellionStory");first.set_stage("complete")
 player.inventory.add_item("enfield",1);player.inventory.add_item("paper_cartridges",100)
 player.health=10000 # Review fixture only; production damage/cooldowns stay intact.
 player.global_position=first.sites.prompts.briefing.global_position
 for frame in 3:await process_frame
 camera=player.get_node("CameraPivot/SpringArm3D/Camera3D");camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 observer=Camera3D.new();observer.fov=50;world.add_child(observer)
 check(story.request("consignment",player),"live Mangal request starts authentic boarding")
 for phase in 7:
  await wait_seconds(.30)
  await photograph("boarding_%d"%phase,true)
 await wait_seconds(1.1)
 check(story.cart.boarding.transition.is_empty(),"live boarding transition completes")
 await sample(12,"concealed",false)
 # Separate saved checkpoints select the port, surveyed slopes and a closed bend.
 # Within each window movement, contact, pursuit and timing are ordinary gameplay.
 await checkpoint(0,"loading")
 var interact:=InputEventKey.new();interact.keycode=KEY_E;interact.physical_keycode=KEY_E;interact.pressed=true
 Input.parse_input_event(interact);await process_frame
 interact=interact.duplicate();interact.pressed=false;Input.parse_input_event(interact)
 check(story.stage=="chase","actual E input starts live chase")
 for rider in story.riders:rider.firearm.cartridges=100
 await sample(20,"port_departure",true)
 await checkpoint(story.Route.nearest_anchor(story.route,Vector2(-590,430)),"chase")
 await sample(36,"hill_turns",true)
 await checkpoint(story.holding_start,"chase")
 await sample(36,"wilderness_bends",true)
 Input.action_release("aim")
 print("CONSIGNMENT LIVE: ","PASS" if failures.is_empty() else "FAIL "+str(failures)," samples=",total_samples," completed_reloads=",reloads)
 print("LIVE REVIEW READY")
 var deadline:=Time.get_ticks_msec()+90000
 while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(output.path_join("live_done")):await process_frame
 saves.quit_game(0 if failures.is_empty() else 1)

func checkpoint(index:int,stage:String) -> void:
 Input.action_release("aim")
 var state:Dictionary=story.export_state();state.stage=stage;state.route_index=index;state.wave=1;state.defeated=[]
 story.restore_state(state)
 player.health=10000
 for rider in story.riders:rider.firearm.cartridges=100
 for frame in 3:await physics_frame
 story.set_physics_process(true);camera=preload("res://story/rear_passenger_combat.gd").aim_camera(player,player.get_node("CameraPivot/SpringArm3D/Camera3D"));camera.make_current()
 await wait_seconds(1)

func wait_seconds(seconds:float) -> void:
 var start:=Time.get_ticks_usec()
 while (Time.get_ticks_usec()-start)/1000000.0<seconds:await process_frame

func peak(key:String,value:float) -> void:metrics[key]=maxf(float(metrics.get(key,0.0)),value)
func bone_world(rig:Skeleton3D,bone:String) -> Vector3:return rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone)).origin)

func sample(seconds:float,label:String,armed:bool) -> void:
 metrics={"label":label,"distance_m":0.0,"samples":0,"reload_frames":0,"aim_frames":0,"camera_outside_frames":0};elapsed=0;next_shot=2.5
 if armed:
  for frame in 600:
   if player.has_meta("consignment_fpv_camera"):break
   await process_frame
  check(player.has_meta("consignment_fpv_camera"),"FPV camera ready after curtain/seat transition")
  if not player.has_meta("consignment_fpv_camera"):return
  camera=player.get_meta("consignment_fpv_camera");camera.make_current()
 previous_cart=story.cart.global_transform
 var prior_time:=Time.get_ticks_usec();var captured=0;var reload_captures=0;var rifle:Node=player.get_node("RifleCombat");var shots_before:int=rifle.shots_fired
 while elapsed<seconds and story.stage in ["outbound","chase"]:
  await process_frame;await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();var delta:float=(now-prior_time)/1000000.0;prior_time=now;elapsed+=delta
  # Use real input routing and real reload reservations. Fire off the lane so the
  # same live pair can remain in pursuit throughout the contact review.
  if armed:
   var wanted:=Vector2(.5+sin(elapsed*.7)*.22,.5+cos(elapsed*.5)*.13)
   var mouse:=InputEventMouseMotion.new();mouse.relative=(wanted-Vector2(player.get_meta("consignment_aim_uv",Vector2(.5,.5))))*root.get_visible_rect().size*(.0025/player.mouse_sensitivity)
   Input.parse_input_event(mouse)
   if elapsed>=next_shot and rifle.aiming and rifle.rounds>0:
    # Brief aim away from mounts, keeping physics and the real muzzle trace.
    camera.move_pointer(Vector2(.75,.3)-camera.pointer)
    var fire:=InputEventAction.new();fire.action="attack";fire.pressed=true;Input.parse_input_event(fire)
    await process_frame
    fire=fire.duplicate();fire.pressed=false;Input.parse_input_event(fire);next_shot=elapsed+4
   if rifle.rounds==0 and rifle.reload_remaining<=0:
    var reload:=InputEventAction.new();reload.action="reload";reload.pressed=true;Input.parse_input_event(reload)
    await process_frame;reload=reload.duplicate();reload.pressed=false;Input.parse_input_event(reload)
  await RenderingServer.frame_post_draw
  measure(delta,armed)
  var loading:bool=rifle.reload_remaining>0
  if previous_reload and not loading:reloads+=1
  previous_reload=loading
  if armed and loading and reload_captures<2 and rifle.reload_remaining<(1.2 if reload_captures==0 else .6):
   await photograph(label+"_reload_%d"%reload_captures,reload_captures==0);reload_captures+=1
  if elapsed>float(captured+1)*seconds/4:
   await photograph(label+"_%d"%captured,captured%2==1);captured+=1
 check(elapsed>=seconds,"sustained window completed: "+label)
 if armed:
  check(metrics.get("fpv_anchor_error_m",1.0)<.001 and metrics.get("fpv_yaw_error_rad",1.0)<.001,"mouse leaves FPV anchor fixed "+label)
  check(rifle.shots_fired>shots_before,"real FPV trigger/reload "+label)
  check(metrics.get("player_grip_error_m",1.0)<.06,"palms remain on FPV rifle "+label)
  check(metrics.get("gun_reticle_angle_rad",1.0)<.02,"rifle follows pointer ray "+label)
 check(metrics.distance_m>seconds*2,"cart keeps progressing through "+label)
 check(story.cart.rider==player,"rear passenger retained "+label)
 check(metrics.get("player_sole_error_m",1.0)<.04,"player soles stay on supports "+label)
 check(metrics.get("crew_sole_error_m",1.0)<.02 and metrics.get("crew_seat_gap_m",1.0)<.02,"crew feet/seat contact "+label)
 if armed:check(metrics.get("police_seat_gap_m",1.0)<.08,"pursuer saddle contact through aim/reload "+label)
 metrics.player_shots=rifle.shots_fired-shots_before;metrics.seconds=elapsed;metrics.stage=story.stage
 var police_shots=0
 for rider in story.riders:police_shots+=rider.firearm.shots
 metrics.police_shots=police_shots
 print("CONSIGNMENT LIVE WINDOW ",JSON.stringify(metrics))

func measure(delta:float,armed:bool) -> void:
 var cart:Node3D=story.cart;var visual:Node=player.get_node("VisualRoot/CharacterVisual");var rig:Skeleton3D=visual.skeleton
 metrics.distance_m+=cart.global_position.distance_to(previous_cart.origin);metrics.samples+=1;total_samples+=1
 peak("cart_yaw_step_deg",rad_to_deg(absf(angle_difference(previous_cart.basis.get_euler().y,cart.global_rotation.y))))
 peak("cart_pitch_deg",absf(cart.global_rotation_degrees.x))
 peak("player_seat_gap_m",bone_world(rig,"pelvis").distance_to(cart.seat_sockets.ConsignmentRearSeat.global_position))
 for side in ["l","r"]:
  var foot:int=rig.find_bone("foot_"+side);var rest:Transform3D=rig.get_bone_global_rest(foot)
  var sole:Vector3=rig.to_global(rig.get_bone_global_pose(foot)*(rest.basis.inverse()*Vector3(0,-.085,.06)))
  peak("player_sole_error_m",sole.distance_to(cart.boarding.foot_support_world(side)))
  peak("player_leg_target_m",bone_world(rig,"thigh_"+side).distance_to(cart.boarding.foot_support_world(side)))
  peak("player_leg_length_m",rig.get_bone_global_rest(rig.find_bone("thigh_"+side)).origin.distance_to(rig.get_bone_global_rest(rig.find_bone("calf_"+side)).origin)+rig.get_bone_global_rest(rig.find_bone("calf_"+side)).origin.distance_to(rest.origin))
 for crew in [story.driver,story.companion]:
  peak("crew_seat_gap_m",bone_world(crew._skeleton,"pelvis").distance_to(crew.riding_socket.global_position+Vector3.UP*.1))
  for side in ["l","r"]:
   var target:Vector3=crew.riding_socket.global_position+cart.global_basis*Vector3(-.18 if side=="l" else .18,-crew.seated_foot_drop,crew.seated_foot_forward)
   var rig_crew:Skeleton3D=crew._skeleton;var foot_index:int=rig_crew.find_bone("foot_"+side);var rest:Transform3D=rig_crew.get_bone_global_rest(foot_index)
   var sole:Vector3=rig_crew.to_global(rig_crew.get_bone_global_pose(foot_index)*(rest.basis.inverse()*Vector3(0,-.085,.06)))
   peak("crew_sole_error_m",sole.distance_to(target))
   if crew.driving:peak("driver_rein_gap_m",crew.palm_world(side).distance_to(cart.rein_grip_world(side)))
 for rider in story.riders:
  if not rider.visible or not is_instance_valid(rider.patrol_mount):continue
  peak("police_seat_gap_m",bone_world(rider._skeleton,"pelvis").distance_to(rider.patrol_mount.seat_world()))
  peak("police_hand_error_m",maxf(rider.get_meta("hand_contact_l",0.0),rider.get_meta("hand_contact_r",0.0)))
 if armed:
  var local:Vector3=cart.to_local(camera.global_position)
  peak("fpv_anchor_error_m",local.distance_to(Vector3(0,2.18,4.02)))
  peak("fpv_yaw_error_rad",absf(angle_difference(camera.rotation.y,PI)))
  if absf(local.x)>1.10 or local.y>3.05 or local.z<1.1:metrics.camera_outside_frames+=1
  var gun:Node=player.get_node("RifleCombat")
  if gun.reload_remaining>0:metrics.reload_frames+=1
  if gun.aiming:metrics.aim_frames+=1
  if gun.aiming and gun.reload_remaining<=0:
   var gear:Node=visual.equipment
   var aim:Vector3=preload("res://story/rear_passenger_combat.gd").aim_direction(player,camera)
   peak("gun_reticle_angle_rad",gear.enfield_hand.global_basis.x.normalized().angle_to(aim))
   var grips:Dictionary=gear.grip_errors();var error:float=maxf(grips.right_palm_m,grips.left_palm_m)
   if error>float(metrics.get("player_grip_error_m",0)):
    metrics.grip_peak_seconds=elapsed;metrics.grip_peak_conceal=player.get_meta("consignment_conceal_blend",0.0);metrics.grip_peak_reload=gear.reload_progress
    metrics.grip_right_m=grips.right_palm_m;metrics.grip_left_m=grips.left_palm_m
   peak("player_grip_error_m",error)
 previous_cart=cart.global_transform

func photograph(label:String,external:bool) -> void:
 var prior:Camera3D=root.get_camera_3d()
 if external:
  observer.global_position=story.cart.to_global(Vector3(4.4,2.4,5.8));observer.look_at(story.cart.to_global(Vector3(0,1.7,2.9)));observer.make_current()
 if label.ends_with("_1") and external:
  observer.global_position=story.cart.to_global(Vector3(3.8,2.8,-2.8));observer.look_at(story.cart.to_global(Vector3(.2,1.6,1.2)))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("live_"+label+".png"))
 if is_instance_valid(prior):prior.make_current()
 print("CONSIGNMENT LIVE CAPTURE ",label)
