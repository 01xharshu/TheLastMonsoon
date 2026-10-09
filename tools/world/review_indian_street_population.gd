extends SceneTree
## Real imported actors and player's real capsule; media only in caller temp.
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var floor:=StaticBody3D.new();world.add_child(floor)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,.1,40);shape.shape=box;shape.position.y=-.05;floor.add_child(shape)
 var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(40,40);mesh.mesh=plane;world.add_child(mesh)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-20,0);world.add_child(light)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color(.2,.24,.28);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,2.5,8);camera.look_at(Vector3(0,.9,0));camera.current=true
 var template:Node=load("res://player/player.tscn").instantiate()
 var probe:=CharacterBody3D.new();probe.collision_mask=template.collision_mask;world.add_child(probe)
 var probe_shape:CollisionShape3D=template.get_node("CollisionShape3D").duplicate();probe.add_child(probe_shape);template.free()
 var people:Array[Node3D]=[]
 for i in 8:
  var actor:=preload("res://characters/npcs/indian/indian_street_actor.gd").new()
  actor.name="Identity%d"%i;actor.movement_enabled=false;actor.movement_profile=&"female" if i%2==0 else &"male"
  actor.ground_height=func(_x:float,_z:float)->float:return 0.0
  var path:="res://characters/npcs/street_residents/%s_%02d.glb"%["female" if i%2==0 else "male",i/2+1]
  actor.add_child(load(path).instantiate());actor.position=Vector3((i-3.5)*1.25,0,0);world.add_child(actor);actor.set_process(false);people.append(actor)
  await physics_frame
  if "--visual-only" in OS.get_cmdline_user_args():continue
  for direction in [Vector3.RIGHT,Vector3.FORWARD,Vector3(1,0,1).normalized()]:
   probe.global_position=actor.global_position+direction*3
   var collided:=false
   for frame in 36:
    await physics_frame
    var hit:=probe.move_and_collide(-direction*(6.0/60.0))
    if hit!=null and hit.get_collider()==actor.body_collider:collided=true
   if not collided:errors.append(actor.name+": player passed through body")
   if probe.global_position.distance_to(actor.global_position)<.45:errors.append(actor.name+": overlapped torso")
   if not actor._patrol_body_blocked(actor.to_local(probe.global_position).normalized()*.8):errors.append(actor.name+": NPC did not detect player")
 probe.position=Vector3(20,0,20)
 var output:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 if not output.is_empty():
  root.size=Vector2i(1440,900)
  for sex in [0,1]:
   for i in people.size():
    people[i].visible=i%2==sex
    people[i].position=Vector3((i/2-1.5)*1.2,0,0)
   camera.position=Vector3(0,1.5,5.3);camera.look_at(Vector3(0,.85,0));camera.fov=48
   await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(output+"/"+("women" if sex==0 else "men")+".png")
  for i in 8:
   for person in people:person.hide()
   people[i].show();people[i].position=Vector3.ZERO
   camera.position=Vector3(.28,1.45,1.25);camera.look_at(Vector3(0,1.36,0));camera.fov=35
   await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(output+"/face_%d.png"%i)
 print("INDIAN_POPULATION_CONTACT ",JSON.stringify({"passed":errors.is_empty(),"identities":8,"player_approaches":0 if "--visual-only" in OS.get_cmdline_user_args() else 24,"errors":errors}))
 quit(0 if errors.is_empty() else 1)
