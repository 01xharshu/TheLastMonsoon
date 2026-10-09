extends SceneTree
const River=preload('res://world/suryagarh/river_dynamics.gd')
const Layout=preload('res://world/suryagarh/landscape_layout.gd')
var failures: Array[String]=[]
var layout:=Layout.new()
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures.append(label)
func terrain_patch(world: Node3D,z: float) -> void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var left:=layout.river_x(z)-layout.river_width(z)-55
 for row in 32:
  for col in 52:
   var x:=left+col*4;var zz:=z-64+row*4
   for p in [Vector2(x,zz),Vector2(x,zz+4),Vector2(x+4,zz),Vector2(x+4,zz),Vector2(x,zz+4),Vector2(x+4,zz+4)]:
    st.add_vertex(Vector3(p.x,layout.height(p.x,p.y),p.y))
 st.generate_normals()
 var mesh:=MeshInstance3D.new();mesh.mesh=st.commit()
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.28,.25,.16);mat.roughness=.94
 mesh.material_override=mat;world.add_child(mesh)
func run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_SKY
 var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new();settings.sky=sky
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color(.7,.75,.8);settings.ambient_light_energy=.8
 settings.reflected_light_source=2
 environment.environment=settings;world.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);world.add_child(sun)
 var clock:=preload('res://world/suryagarh/systems/game_time_system.gd').new();clock.name='GameTimeSystem';world.add_child(clock);clock.set_process(false)
 var river:=River.new();world.add_child(river)
 var camera:=Camera3D.new();camera.far=2000;camera.fov=60;world.add_child(camera);camera.current=true
 var boat: Node3D=load('res://vehicles/river_boat.gd').new();boat.name='RiverBoat';world.add_child(boat);boat.set_physics_process(false)
 check(river.get_child_count()==18,'18 culled water strips cover playable river')
 var vertices:=0
 for child in river.get_children():vertices+=child.mesh.surface_get_array_len(0)
 check(vertices<100000 and vertices>40000,'bounded subdivided water geometry: '+str(vertices)+' vertices')
 for z in [-600.0,165.0,680.0]:
  var at:=Vector3(layout.river_x(z),0,z)
  var flow: Vector3=River.current_at(at)
  check(flow.z>0 and flow.length()<1,'current follows downstream tangent at '+str(z))
  check(River.current_at(at+Vector3(layout.river_width(z)+2,0,0))==Vector3.ZERO,'current excludes dry bank at '+str(z))
 check(River.current_at(Vector3(layout.river_x(-500),0,-500)).length()>River.current_at(Vector3(layout.river_x(700),0,700)).length(),'upstream flows faster than estuary')
 var at:=Vector3(layout.river_x(165),0,165)
 check(absf(River.surface_height(at,0)-River.surface_height(at,2))>.01,'wave height changes with time')
 check(absf(River.surface_height(at,2))<.1,'wave amplitude remains below ten centimetres')
 var env: Node=root.get_node('WorldAudio/EnvironmentAudio');env.set_process(false)
 root.get_node('WindSystem').exposure=1
 env.tick(at,12,.25)
 check(env.river_voice.playing and not env.shore_voice.playing,'mid-channel current sound plays without bank layer')
 env.tick(at+Vector3(layout.river_width(165),2,0),12,.25)
 check(env.shore_voice.playing,'close bank wash layer plays')
 check(absf(layout.height(env.shore_voice.position.x,env.shore_voice.position.z)-Layout.WATER_LEVEL)<.06,'bank wash follows terrain shoreline')
 env.tick(Vector3(-650,8,165),12,.25)
 check(not env.shore_voice.playing and not env.river_voice.playing,'both water voices stop inland')
 var actor: CharacterBody3D=load('res://player/player.tscn').instantiate()
 world.add_child(actor);actor.set_physics_process(false);actor.set_process(false)
 actor.get_node('UI').hide();actor.get_node('CameraPivot').rotation.y=0
 actor.global_position=Vector3(layout.river_x(165),.2,165)
 actor.is_swimming=true;var flow:=River.current_at(actor.global_position)
 actor.set_meta('river_current',flow);actor.velocity=Vector3.ZERO
 for i in 90:actor._handle_movement(1.0/60)
 check(actor.velocity.distance_to(flow)<.01,'idle swimmer drifts with current')
 Input.action_press('move_forward')
 for i in 90:actor._handle_movement(1.0/60)
 var upstream_speed: float=absf(actor.velocity.z)
 Input.action_release('move_forward');Input.action_press('move_backward')
 for i in 120:actor._handle_movement(1.0/60)
 var downstream_speed: float=actor.velocity.z
 Input.action_release('move_backward')
 check(downstream_speed>upstream_speed+.5,'downstream swimming is faster than upstream')
 actor.velocity=Vector3.ZERO;actor.set_meta('map_open',true)
 for i in 60:actor._physics_process(1.0/60)
 check(actor.velocity.z>.5,'current remains active while a swimming player opens the map')
 actor.set_meta('map_open',false)
 actor.is_swimming=false;actor.velocity=Vector3.ZERO;actor._handle_movement(1.0/60)
 check(actor.velocity.length()<.01,'dry actor receives no current')
 actor.global_position=boat.position+Vector3(-1,1,0)
 check(boat.board(actor),'existing player boards boat with river changes')
 boat.position=Vector3(layout.river_x(165),.03,165)
 var before:=boat.position
 for i in 60:boat._physics_process(1.0/60)
 check(boat.position.z>before.z+.4,'occupied idle boat drifts downstream')
 check(actor.global_position.distance_to(boat.seat_world())<.2,'rider remains attached while drifting')
 boat.rider=null;actor.remove_meta('mounted_vehicle')
 before=boat.position
 for i in 60:boat._physics_process(1.0/60)
 check(Vector2(boat.position.x-before.x,boat.position.z-before.z).length()<.01,'unoccupied moored boat stays in place')
 actor.hide();actor.get_node('VisualRoot/CharacterVisual').set_process(false)
 camera.make_current()
 var out: String=''
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--output='):out=arg.trim_prefix('--output=')
 if DisplayServer.get_name()!='headless':
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(960,540))
  root.content_scale_size=Vector2i(960,540)
  root.size=Vector2i(960,540)
  for z in [-500.0,235.0,650.0]:
   terrain_patch(world,z)
   var edge:=layout.river_x(z)-layout.river_width(z)-22
   camera.position=Vector3(edge-7,maxf(3.2,layout.height(edge-7,z+12)+1.7),z+12);camera.look_at(Vector3(edge+35,-.2,z-12))
   if z==235:boat.position=Vector3(edge+6,.03,z)
   env.tick(camera.position,12,.25)
   var started:=Time.get_ticks_msec()
   while Time.get_ticks_msec()-started<3000:await process_frame
   await RenderingServer.frame_post_draw
   if out!='':var capture:=root.get_texture().get_image();capture.resize(960,540);capture.save_png(out+'/river_'+str(int(z))+'.png')
   print('NATIVE REACH '+str(z)+' normal-speed 3 seconds')
 print('RIVER DYNAMICS: '+('PASS' if failures.is_empty() else 'FAIL'))
 preload('res://tools/test_audio_cleanup.gd').stop(root);await preload('res://tools/test_audio_cleanup.gd').settle(self)
 quit(0 if failures.is_empty() else 1)
