extends SceneTree
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if not ok:errors.append(label);push_error(label)
func walk(actor:CharacterBody3D,target:Vector3,label:String) -> bool:
 var offset:=target-actor.global_position;offset.y=0
 actor.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.z)
 Input.action_press("move_forward")
 var reached:=false
 for frame in 280:
  offset=target-actor.global_position;offset.y=0
  if OS.get_environment("TLM_EXPLORE_OFFICE")=="1" and frame==180:
   var trial=actor.move_and_collide(Vector3(0,0,.3),true)
   print("EXPLORE STEPTEST ","no hit" if trial==null else str(trial.get_collider().get_path())+" normal="+str(trial.get_normal())+" pos="+str(trial.get_position())," floor=",actor.is_on_floor()," held=",Input.is_action_pressed("move_forward")," shape=",("none" if trial==null else str(trial.get_collider_shape().global_position)+" / "+str(trial.get_collider_shape().shape)))
   var before_velocity:=actor.velocity
   actor._handle_movement(1.0/60.0);print("EXPLORE HANDLE velocity=",actor.velocity)
   actor.velocity=before_velocity
  if offset.length()<.65:reached=true;break
  await physics_frame
 Input.action_release("move_forward")
 for frame in 5:await physics_frame
 if reached:print("EXPLORE WALK ",label," PASS");return true
 var hits:Array[String]=[]
 for i in actor.get_slide_collision_count():
  var body=actor.get_slide_collision(i).get_collider()
  if body is Node:
   var hit:=actor.get_slide_collision(i)
   hits.append(str(body.get_path())+" normal="+str(hit.get_normal())+" pos="+str(hit.get_position())+" shape="+str(hit.get_collider_shape_index()))
 print("EXPLORE WALK ",label," BLOCKED at=",actor.global_position," target=",target," hits=",hits," health=",actor.health," velocity=",actor.velocity," input=",Input.get_vector("move_left","move_right","move_forward","move_backward")," camera=",actor.get_node("CameraPivot").global_rotation.y," floor=",actor.is_on_floor()," opening=",actor.get_meta("opening_active",false)," rest=",actor.get_meta("rest_action",""))
 return false
func visit(actor:CharacterBody3D,site:Node3D,outer:Vector3,inner:Vector3,label:String,door:Node=null) -> void:
 actor.global_position=site.to_global(outer);actor.velocity=Vector3.ZERO
 if actor.has_node("PlayerSafety"):actor.get_node("PlayerSafety").peak=-INF
 for i in 3:await physics_frame
 if door!=null and not door.opened:
  door.interact(actor)
  for i in 360:
   await physics_frame
   if door.opened and not door.moving:break
  if not door.opened:print("EXPLORE DOOR ",label," failure=",actor.get_meta("door_latch_failure","")," active=",actor.get_meta("door_latch_active",false)," gap=",actor.get_meta("door_latch_hand_gap",-1)," distance=",actor.global_position.distance_to(door.global_position))
  check(door.opened and not door.locked,label+" door is usable")
 var reached:bool=await walk(actor,site.to_global(inner),label+" entry")
 check(reached,label+" actual player can enter")
 if reached:check(await walk(actor,site.to_global(outer),label+" exit"),label+" actual player can leave")
func run() -> void:
 root.size=Vector2i(1280,720)
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 for i in 60:await process_frame
 var actor:CharacterBody3D=world.get_node("Player");actor.set_physics_process(true)
 var map:Node=actor.get_node("UI/WorldMap");map._update_map_area();map.refresh_sites()
 var factory:Node3D=world.get_node("IndigoFactory")
 var city:Node3D=world.get_node("UrbanWest")
 var district:Node3D=world.get_node("Settlement/BritishCantonment")
 var ward:Node3D=city.get_node("CivilianHospital")
 var lecture:Node3D=city.get_node("CollegeLectureHall")
 var college:Node3D=world.get_node("StoryCommunity/CollegeReadingRoom")
 var military:Node3D=district.get_node("MilitaryHospital")
 var locations:Array=[["Indigo Processing Factory",factory],["Civilian hospital",ward],["College campus",college],["College · Lecture hall",lecture],["British Cantonment",district],["Military Hospital",military]]
 for location in locations:
  var label:String=location[0];var node:Node3D=location[1]
  check(map.sites.has(label),"map contains "+label)
  if not map.sites.has(label):continue
  var expected:=Vector2(node.global_position.x,node.global_position.z)
  check(map.sites[label].distance_to(expected)<1.0,label+" marker matches actual place")
  map.zoom=8.0;map.map_center=expected;map.clamp_center()
  map.select_point(map.project(expected))
  check(map.waypoint.distance_to(expected)<1.0 and not map.follow_story,label+" map selection sets shared waypoint")
  print("EXPLORE MAP ",label," at=",expected," selected=",map.selected_site)
 check(map.site_kind("Indigo Processing Factory")=="trade" and map.site_kind("College campus")=="civic","factory and college use meaningful map icons")
 # Buildings are navigated through their authored approach and actual physical geometry.
 var dry:Node3D=factory.get_node("FactoryArchitecture/DryingHouse")
 var store:Node3D=factory.get_node("FactoryArchitecture/PackingStore")
 var office:Node3D=factory.get_node("FactoryArchitecture/AccountOffice")
 for item in [[dry,12.5,4.5,"factory drying house",-1.0],[store,11.5,3.0,"factory packing store",-1.0],[store,15.0,3.0,"factory packing store north gate",1.0],[office,15.0,3.0,"factory account office",-1.0]]:
  if OS.get_environment("TLM_EXPLORE_OFFICE") == "1" and item[0]!=office:continue
  var room:Node3D=item[0];var sign:float=item[4];var outside:Vector3=room.to_global(Vector3(0,0,sign*float(item[1])))
  var start_height:float=factory.height_at(Vector2(outside.x,outside.z))+1.02
  var local_start:=room.to_local(Vector3(outside.x,start_height,outside.z))
  await visit(actor,room,local_start,Vector3(0,1.02,sign*float(item[2])),item[3])
 if OS.get_environment("TLM_EXPLORE_OFFICE") == "1":
  print("INSTITUTION EXPLORATION: ","PASS" if errors.is_empty() else "FAIL "+str(errors))
  await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
  return
 await visit(actor,ward,Vector3(0,1.15,8.8),Vector3(0,1.15,5.2),"civilian hospital",ward.get_node("EntranceDoorFrame/EntranceDoor"))
 await visit(actor,lecture,Vector3(0,1.15,9.8),Vector3(0,1.15,6.2),"college lecture hall",lecture.get_node("EntranceDoorFrame/EntranceDoor"))
 var reading_start:=college.to_global(Vector3(0,0,15))
 reading_start.y=world.layout.height(reading_start.x,reading_start.z)+1.0
 await visit(actor,college,college.to_local(reading_start),Vector3(0,1.0,7.4),"college reading room")
 for label in ["MilitaryHospital","MilitarySupplyDepot","BritishBarracks","CavalryStables"]:
  var room:Node3D=district.get_node(label)
  var entrance:Vector3=room.to_local(room.get_node("Entrance").global_position)
  var outside:=entrance+Vector3.UP*.9
  var inside:=Vector3(0,1.15,2.0 if label=="CavalryStables" else 3.2 if label in ["MilitaryHospital","MilitarySupplyDepot"] else 0)
  await visit(actor,room,outside,inside,"cantonment "+label)
 print("INSTITUTION EXPLORATION: ","PASS" if errors.is_empty() else "FAIL "+str(errors))
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
