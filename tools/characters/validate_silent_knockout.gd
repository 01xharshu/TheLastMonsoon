extends SceneTree
const Silent=preload("res://combat/silent_knockout.gd")
var failures:Array[String]=[]
class Evidence:
 extends Node
 var wanted:=false
 var wanted_level:=0
 var reports:=0
 var identities:Array[String]=[]
 func record_incident(_kind:String,_location:Vector3,seen:Array[String],_severity:int)->bool:
  reports+=1;identities=seen;wanted=true;wanted_level=2;return true
func _initialize()->void:
 call_deferred("run")
 create_timer(40).timeout.connect(func():quit(2))
func check(ok:bool,label:String)->void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func human(world:Node3D,label:String,at:Vector3,faction:String)->Node3D:
 var npc:=preload("res://characters/npcs/households/household_npc_actor.gd").new()
 npc.name=label;npc.position=at;npc.movement_enabled=false;npc.set_meta("combat_faction",faction)
 npc.add_child(load("res://characters/npcs/british/private_man.glb").instantiate());world.add_child(npc);return npc
func run()->void:
 check(load("res://assets/ui/map_icons/weapon.svg")!=null,"generated map icon loads")
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(20,.2,20);collision.shape=shape;collision.position.y=-.1;floor.add_child(collision);world.add_child(floor)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);world.add_child(light)
 var player:CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player);player.get_node("PlayerSafety").set_physics_process(false);player.position=Vector3(0,.9,.35)
 var enemy:=human(world,"Enemy",Vector3(0,0,1),"british")
 var witness:=human(world,"Witness",Vector3(3,0,-2),"indian")
 var authority:=Evidence.new();authority.name="CombatEncounters";world.add_child(authority);authority.add_to_group("police_crime_observers")
 for i in 20:await physics_frame
 player.get_node("PlayerSafety").set_physics_process(false)
 var grapple:Node=player.get_node("RearGrapple")
 witness.rotation.y=atan2(player.position.x-witness.position.x,player.position.z-witness.position.z)
 check(Silent.witnesses(player,enemy).is_empty(),"victim and civilian cannot report silent knockout")
 witness.set_meta("combat_faction","police");witness.set_meta("sleeping",true)
 check(Silent.witnesses(player,enemy).is_empty(),"sleeping police cannot witness")
 witness.set_meta("sleeping",false);witness.rotation.y+=PI
 check(Silent.witnesses(player,enemy).is_empty(),"police facing away cannot witness")
 witness.rotation.y-=PI
 check(Silent.witnesses(player,enemy).size()==1,"other visible policeman identifies action")
 var wall:=StaticBody3D.new();var panel:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.3,3,6);panel.shape=box;wall.add_child(panel);wall.position=Vector3(1.5,1,-1);world.add_child(wall)
 for i in 3:await physics_frame
 check(Silent.witnesses(player,enemy).is_empty(),"wall blocks witness evidence")
 wall.queue_free();for i in 3:await physics_frame
 var smoke:=preload("res://combat/escape_smoke.gd").new();world.add_child(smoke);smoke.position=Vector3(1.5,0,-1)
 check(Silent.witnesses(player,enemy).is_empty(),"escape smoke blocks witness evidence")
 smoke.queue_free();for i in 3:await physics_frame
 witness.set_meta("combat_faction","british")
 check(Silent.report(player,enemy) and authority.reports==1 and str(enemy.get_path()) not in authority.identities,"British witness reports once without victim identity")
 for i in 3:await process_frame
 check(player.get_node("UI/HUDRoot").wanted_level==2,"HUD reads wanted stars from crime state")
 var source:Node=load("res://world/suryagarh/combat_encounters.gd").new()
 source.player=player
 var notifications:Array[String]=[]
 player.inventory.message_requested.connect(func(message:String):notifications.append(message))
 source.record_incident("takedown",enemy.global_position,authority.identities,2)
 check(source.wanted_level==1 and notifications.is_empty(),"real crime record raises stars without notification")
 source.free()
 witness.set_meta("sleeping",true);authority.reports=0;authority.wanted=false;authority.wanted_level=0
 player.global_position=Vector3(0,.9,1.7);for i in 3:await physics_frame
 check(not grapple.begin(),"front approach rejected")
 player.global_position=Vector3(0,.9,.35);for i in 3:await physics_frame
 enemy.get_node("Vitality").health=180
 var key:=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true
 player._unhandled_input(key)
 check(grapple.active,"ordinary player Q starts rear knockout")
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(-2.8,1.8,3.5);camera.look_at(Vector3(0,1,1));camera.current=true
 var output:=OS.get_environment("TLM_KNOCKOUT_REVIEW")
 var middle:=false
 for i in 220:
  await physics_frame
  if not middle and grapple.age>.7:
   middle=true
   check(grapple.contact_error<.04,"paired palms stay within four centimetres")
   if not output.is_empty():
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("hold.png"))
 check(enemy.get_meta("knocked_out",false) and not enemy.get_meta("dead",false) and enemy.get_node("Vitality").health>0,"high-health enemy survives automatic knockout")
 check(authority.reports==0,"unseen silent knockout creates no crime")
 check(not grapple.active and not player.get_meta("paired_combat",false) and player.get_node("ActionPermissions").domain_free(&"attack"),"animation releases controls and action lease")
 check(enemy.get_node("CombatMotion").state=="down","victim settles into persistent down pose")
 if not output.is_empty():
  authority.wanted=true;authority.wanted_level=3
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("down_stars.png"))
 enemy.set_meta("knocked_out",false);enemy.get_node("Vitality").health=75
 enemy.get_node("BodyCollider/BodyShape").disabled=false
 enemy.get_node("CombatMotion").state="";enemy.animation_tree.set("parameters/combat/blend_amount",0.0)
 player.global_position=Vector3(0,.9,.35)
 witness.set_meta("sleeping",false);authority.reports=0
 for i in 6:await physics_frame
 player._unhandled_input(key)
 for i in 230:await physics_frame
 check(authority.reports==1,"visible witness creates exactly one report through whole action")
 check(enemy.get_meta("knocked_out",false) and not enemy.get_meta("dead",false),"witnessed knockout is still nonlethal")
 print("SILENT KNOCKOUT: ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
