extends SceneTree
## Actual baked terrain and collision, not only the analytic source height.
var errors:Array[String]=[]
func check(ok:bool,label:String)->void:
 if not ok:errors.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func sample_height(world:Node3D,x:float,z:float)->float:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(x,30,z),Vector3(x,-20,z),1)
 var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
 return hit.position.y if not hit.is_empty() else NAN
func run()->void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
 for i in 4:await physics_frame
 var report:Array=[]
 for z in [-48.0,312.0]:
  var edge:float=layout.river_x(z)-layout.river_width(z)
  var heights:Array=[]
  for d in [3.0,6.0,9.0,12.0,15.0,18.0]:
   var x:float=edge-d;var value:=sample_height(world,x,z);var expected:float=layout.height(x,z)
   check(is_finite(value),"terrain collision present at "+str([z,d]))
   check(absf(value-expected)<.18,"baked collision matches low-bank height at "+str([z,d]))
   check(value>=-.10 and value<=.48,"low land stays near water at "+str([z,d]))
   heights.append(value)
  check(absf(float(heights[-1])-float(heights[0]))<.40,"gentle grade at "+str(z))
  # Walk a real collision capsule across the visible land toward the water.
  var actor:=CharacterBody3D.new();actor.name="LowBankWalkProbe";world.add_child(actor)
  var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.25;capsule.height=1.7;shape.shape=capsule;shape.position.y=.85;actor.add_child(shape)
  actor.global_position=Vector3(edge-18,float(heights[-1])+.04,z)
  for frame in 180:
   actor.velocity=Vector3(1.5,-.45,0);actor.move_and_slide();await physics_frame
  var progress:float=actor.global_position.x-(edge-18)
  check(progress>3.0,"capsule crosses low bank at "+str(z))
  report.append({"z":z,"edge_x":edge,"heights":heights,"walked_m":progress})
  actor.queue_free();await physics_frame
  var player:CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
  player.set_physics_process(false);player.set_process_unhandled_input(false)
  player.global_position=Vector3(edge-18,float(heights[-1])+1.0,z)
  for frame in 180:
   player.velocity=Vector3(1.5,player.velocity.y-9.8/60.0,0);player.move_and_slide();await physics_frame
  var player_progress:float=player.global_position.x-(edge-18)
  check(player_progress>3.0,"player crosses low bank at "+str(z))
  report[-1]["player_walked_m"]=player_progress
  player.queue_free();await physics_frame
 print("LOW_BANK_VALIDATION ",JSON.stringify({"passed":errors.is_empty(),"issues":errors,"sites":report,"scope":"baked collision and controlled player movement; animation and full-world play remain separate"}))
 world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
