extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _stand_at(player:CharacterBody3D,service:Node3D) -> void:
 var directions:Array[Vector3]=[service.global_basis.z,Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]
 for direction in directions:
  player.global_position=service.global_position+direction*1.4-Vector3.UP*.9
  var toward:=service.global_position-player.global_position
  player.get_node("VisualRoot").global_rotation.y=atan2(toward.x,toward.z)
  for frame in 3:await physics_frame
  if player.call("_find_interactable")==service:return
func _run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 for frame in 12:await physics_frame
 var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false);player.first_person=false
 for coach in get_nodes_in_group("household_coach"):coach.get_node("HouseholdTravel").set_physics_process(false)
 var services:=get_nodes_in_group("household_role_services")
 var errors:Array[String]=[]
 if services.size()!=13:errors.append("expected 13 household role services, got "+str(services.size()))
 var merchant:Node
 var landlord:Node
 for service in services:
  service.person.set_process(false);service.person.set_meta("household_action","home")
  if service.role=="merchant":merchant=service
  if service.role=="landowner":landlord=service
  await _stand_at(player,service)
  if player.call("_find_interactable")!=service:errors.append(str(service.person.name)+": normal interaction cannot select role")
 var saver:Node=root.get_node("SaveManager")
 var ledger:Node=world.get_node("WealthyHouseholds/WorldRoles")
 if landlord!=null:
  await _stand_at(player,landlord);landlord.interact(player)
  if not ledger.survey_active:errors.append("placed landowner survey unavailable")
  elif not ledger.fields.is_empty():
   var field:Node3D=ledger.fields[0]
   player.global_position=field.global_position+Vector3(0,-.35,1.4);player.get_node("VisualRoot").global_rotation.y=PI
   for frame in 3:await physics_frame
   if player.call("_find_interactable")!=field:errors.append("placed field cannot be selected")
   field.interact(player)
 if merchant!=null:
  await _stand_at(player,merchant)
  var inv:Node=player.get_node("InventoryComponent");inv.items.mango=2
  ledger.clock.advance_minutes(10*60-fmod(ledger.clock.total_game_minutes,1440))
  merchant.interact(player)
  if inv.get_item_count("mango")!=1:errors.append("placed merchant trade failed")
  var temp:=OS.get_environment("TLM_HOUSEHOLD_SAVE_TEMP")
  if temp.is_empty():errors.append("temporary save directory is required")
  else:
   var original_root:String=saver.save_root;var original_pending:int=saver.pending_slot
   saver.save_root=temp
   if not saver.save_game(world,1):errors.append("temporary save failed")
   else:
    var data:Dictionary=saver.read_slot(1)
    if not data.has("household_roles"):errors.append("role ledger missing from save")
    ledger.state.clear();inv.items.mango=99
    saver.pending_slot=1;saver.apply_pending(world)
    if int(ledger.state.get(merchant.role_id,{}).get("sold",0))!=1 or inv.get_item_count("mango")!=1 or ledger.survey_checked.size()!=1:errors.append("role/inventory/survey save restore failed")
   saver.save_root=original_root;saver.pending_slot=original_pending
 print("HOUSEHOLD_ROLES_WORLD ",JSON.stringify({"passed":errors.is_empty(),"services":services.size(),"errors":errors,"scope":"placed NPC interaction selection, merchant trade and temporary real save/load"}))
 quit(0 if errors.is_empty() else 1)
