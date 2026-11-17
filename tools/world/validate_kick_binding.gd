extends SceneTree
## Real Player input dispatch and rebind persistence; private runner user data only.
var failures:Array[String]=[]
var count:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 count+=1;print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func run()->void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var floor_body:=StaticBody3D.new();world.add_child(floor_body)
 var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(30,1,30);floor_shape.shape=floor_box;floor_shape.position.y=-.5;floor_body.add_child(floor_shape)
 var actor:CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.position=Vector3(0,.9,0)
 for frame in 20:await physics_frame
 var combat:Node=actor.get_node("CombatInput")
 var visual:Node3D=actor.get_node("VisualRoot/CharacterVisual")
 var slash:Node=actor.get_node("TalwarSlash")
 var settings:Node=root.get_node("SaveManager")
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 check(InputMap.has_action("kick"),"kick is a registered rebindable input action")
 var key:=InputEventKey.new();key.physical_keycode=KEY_K;key.pressed=true
 check(key.is_action_pressed("kick"),"default K maps to kick")
 var panel:Control=load("res://ui/settings_panel.gd").new();world.add_child(panel);panel.show_category("Actions")
 var kick_button:Button
 for child in panel.get_children():
  if child is Button and child.get_meta("action","")=="kick":kick_button=child;break
 check(kick_button!=null and "K" in kick_button.text,"keyboard settings display the Kick binding")
 panel.queue_free()
 var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
 visual.equipment.stowed=true
 combat._unhandled_input(mouse)
 check(combat.punch_time>=0 and combat.kick_time<0,"first mouse press attacks immediately")
 mouse.double_click=true;combat._unhandled_input(mouse)
 check(combat.kick_time<0 and combat.punch_time>=0,"double-click never replaces active punch with kick")
 combat.interrupt();mouse.double_click=false
 actor.inventory.add_item("talwar",1);visual.equipment.selected=0;visual.equipment.stowed=false;visual.equipment._refresh()
 combat._unhandled_input(mouse)
 check(slash.elapsed<slash.DURATION,"mouse press starts selected sword immediately")
 mouse.double_click=true;combat._unhandled_input(mouse)
 check(combat.kick_time<0 and slash.elapsed<slash.DURATION,"OS double-click leaves sword attack active")
 combat._unhandled_input(key)
 check(combat.kick_time>=0 and slash.elapsed>=slash.DURATION,"K triggers kick and cancels active sword swing")
 combat.interrupt();combat.kick_cooldown=0
 check(settings.bind_key("kick",KEY_L),"Kick can be rebound through the existing settings owner")
 var saved:=ConfigFile.new();check(saved.load(settings.settings_path)==OK and saved.get_value("settings","key_bindings",{}).get("kick")==KEY_L,"new key persists in private settings")
 var rebound:=InputEventKey.new();rebound.physical_keycode=KEY_L;rebound.pressed=true
 check(rebound.is_action_pressed("kick") and not key.is_action_pressed("kick"),"rebound action replaces K")
 combat._unhandled_input(key);check(combat.kick_time<0,"former key no longer kicks")
 combat._unhandled_input(rebound);check(combat.kick_time>=0,"configured key performs kick")
 combat.interrupt();combat.kick_cooldown=0;actor.set_meta("detention_action","arrest")
 combat._unhandled_input(rebound);check(combat.kick_time<0,"detention still prevents kicking")
 actor.set_meta("detention_action","")
 print("KICK INPUT ",JSON.stringify({"checks":count,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
 settings.quit_game(0 if failures.is_empty() else 1)
