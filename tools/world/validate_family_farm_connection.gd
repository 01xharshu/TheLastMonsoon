extends SceneTree
var failures: Array[String]=[]
class WorldFixture:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 if not value:failures.append(label);push_error(label)
func walk(player: CharacterBody3D,target: Vector3) -> bool:
 for frame in 420:
  var delta:=target-player.global_position;delta.y=0
  if delta.length()<.3:Input.action_release("move_forward");return true
  player.get_node("CameraPivot").global_rotation.y=atan2(-delta.x,-delta.z)
  Input.action_press("move_forward");await physics_frame
 Input.action_release("move_forward")
 print("FAMILY ROUTE BLOCKED ",player.global_position," target ",target)
 return false
func run() -> void:
 var world:=WorldFixture.new();root.add_child(world);current_scene=world
 var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.clock_paused=true
 var terrain:=SurfaceTool.new();terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-457,-414):
  for z in range(201,241):
   for point in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
    terrain.add_vertex(Vector3(point.x,world.layout.height(point.x,point.y),point.y))
 var ground:=StaticBody3D.new();world.add_child(ground)
 var collider:=CollisionShape3D.new();collider.shape=terrain.commit().create_trimesh_shape();ground.add_child(collider)
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
 var house: Node3D=load("res://world/suryagarh/settlements/chacha_house.gd").new();world.add_child(house)
 var community: Node3D=load("res://world/suryagarh/settlements/story_community.gd").new();world.add_child(community);community.set_process(false)
 house.set_meta("advice_given",true);house.get_node("Chacha").set_process(false)
 house.get_node("EntranceDoor").set_open(true)
 player.global_position=house.to_global(Vector3(-3,1.1,1.5));player.velocity=Vector3.ZERO
 for frame in 60:await physics_frame
 check(community.farm.has_node("HouseConnectionRamp"),"house-to-farm ramp exists")
 for point in [Vector3(0,1.1,1.5),Vector3(0,1.1,8),Vector3(-7.7,1.1,8)]:
  check(await walk(player,house.to_global(point)),"normal controller follows family house route "+str(point))
 check(await walk(player,community.farm.to_global(Vector3(8.5,.9,0))),"controller walks up the farm connection")
 check(await walk(player,community.farm.to_global(Vector3(4,.9,0))),"controller reaches practice yard")
 var gate: Node=house.get_node("FamilyCourtyardGate");gate.set_open(false)
 for frame in 80:await physics_frame
 var ray:=PhysicsRayQueryParameters3D.create(house.to_global(Vector3(.2,1,11)),house.to_global(Vector3(.2,1,15)))
 var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty(),"closed boundary gate blocks its opening")
 gate.set_open(true)
 for frame in 80:await physics_frame
 hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
 check(hit.is_empty(),"open boundary gate clears the opening")
 print("FAMILY FARM CONNECTION: "+("PASS" if failures.is_empty() else str(failures)))
 world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,code)
