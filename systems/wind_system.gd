extends Node
## Shared gradual prevailing wind and moving gust field, in metres/second.
var elapsed := 0.0
var speed := 0.0
var direction := Vector2(.9,.4).normalized()
var exposure := 1.0
var shelter_timer := 0.0
var sheltered := false
var ambience: AudioStreamPlayer
func _ready() -> void:
 get_tree().node_added.connect(_vegetation_added)
 for node in get_tree().root.find_children('*','MeshInstance3D',true,false):_vegetation_added(node)
 ambience=AudioStreamPlayer.new();add_child(ambience)
 var stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path('res://audio/world/wind.wav'))
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=stream.data.size()/2
 ambience.stream=stream;ambience.volume_db=-60;ambience.play()
func sample(at: Vector3) -> Vector3:
 var gust := .78+.22*sin(elapsed*.71-at.x*.015-at.z*.011)
 return Vector3(direction.x,0,direction.y)*speed*gust
func _process(delta: float) -> void:
 elapsed+=delta
 var target := 2.1+1.1*sin(elapsed*.073)+1.3*pow(maxf(0,sin(elapsed*.31)),3)
 speed=move_toward(speed,target,delta*.7)
 var angle := .42+.22*sin(elapsed*.017)
 direction=Vector2(cos(angle),sin(angle))
 RenderingServer.global_shader_parameter_set('world_wind',Vector3(direction.x*speed,elapsed,direction.y*speed))
 _update_flags(delta)
 var camera := get_viewport().get_camera_3d()
 if camera==null:ambience.volume_db=-60;return
 shelter_timer-=delta
 if shelter_timer<=0:
  shelter_timer=.25
  var query:=PhysicsRayQueryParameters3D.create(camera.global_position+Vector3.UP*.2,camera.global_position+Vector3.UP*18)
  query.collision_mask=1
  sheltered=not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
 exposure=move_toward(exposure,.12 if sheltered else 1.0,delta*.8)
 ambience.volume_db=linear_to_db(maxf(.001,speed/5.0*exposure*.45))

func _update_flags(delta: float) -> void:
 for animator in get_tree().get_nodes_in_group('wind_flags'):
  if is_instance_valid(animator):animator.speed_scale=clampf(sample(animator.get_parent().global_position).length()/2.5,.15,1.8)
 for flag in get_tree().get_nodes_in_group('wind_flag_roots'):
  if is_instance_valid(flag):flag.rotation.y=rotate_toward(flag.rotation.y,-atan2(direction.y,direction.x),delta*.08)

func _vegetation_added(node: Node) -> void:
 if node is MeshInstance3D and node.name=='MangoTree_Leaves':_fit_leaves.call_deferred(node)
func _fit_leaves(mesh: MeshInstance3D) -> void:
 if not is_instance_valid(mesh) or mesh.mesh==null:return
 for i in mesh.mesh.get_surface_count():
  var original := mesh.get_active_material(i) as StandardMaterial3D
  if original==null:continue
  var material := ShaderMaterial.new()
  material.shader=preload('res://environment/forest/shaders/foliage.gdshader')
  material.set_shader_parameter('albedo_texture',original.albedo_texture)
  material.set_shader_parameter('use_albedo_texture',original.albedo_texture!=null)
  material.set_shader_parameter('normal_texture',original.normal_texture)
  material.set_shader_parameter('use_normal_texture',original.normal_enabled and original.normal_texture!=null)
  material.set_shader_parameter('tint',original.albedo_color)
  material.set_shader_parameter('roughness_value',original.roughness)
  material.set_shader_parameter('alpha_cutoff',original.alpha_scissor_threshold)
  material.set_shader_parameter('wind_strength',.045)
  mesh.set_surface_override_material(i,material)

func _exit_tree() -> void:
 if is_instance_valid(ambience):
  ambience.stop()
  ambience.stream=null
