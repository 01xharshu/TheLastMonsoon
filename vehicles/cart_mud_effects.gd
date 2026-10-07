extends Node3D
## Small wet clods thrown from grounded wheels; bounded, world-space particles.
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
var cart:Node3D
var particles:Array[CPUParticles3D]=[]
var wet_contacts:=0
var active_emission:=false
var previous:=Vector3.INF
var elapsed:=0.0
var measured_speed:=0.0
static func wet_strength(point:Vector2) -> float:
 var wet:=smoothstep(.52,.82,(sin(point.x*.11+point.y*.075-1.5)+1)*.5)
 if wet<.05:return 0
 for label in ["village_spine","village_west_lane","village_market_lane","village_north_lane","village_south_lane","village_west_link","village_estate_approach"]:
  var route:Array=Layout.ROUTES[label];var width:=2.5 if label=="village_spine" else 2.0 if label in ["village_market_lane","village_north_lane"] else 1.7
  for segment in route.size()-1:
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,route[segment],route[segment+1]))<width-.2:return wet
 return 0
func configure(vehicle:Node3D) -> void:cart=vehicle
func _ready() -> void:
 for side in [-1.0,1.0]:
  var effect:=CPUParticles3D.new();effect.name="LeftWheelClods" if side<0 else "RightWheelClods"
  effect.amount=28;effect.lifetime=.32;effect.randomness=.45;effect.local_coords=false;effect.emitting=false
  effect.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;effect.emission_sphere_radius=.045
  effect.gravity=Vector3(0,-9.8,0);effect.initial_velocity_min=.8;effect.initial_velocity_max=1.5;effect.spread=24
  effect.scale_amount_min=.45;effect.scale_amount_max=1.0;effect.color=Color(.18,.105,.047,1)
  var mesh:=SphereMesh.new();mesh.radius=.022;mesh.height=.028;mesh.radial_segments=6;mesh.rings=3
  var material:=StandardMaterial3D.new();material.albedo_color=Color(.19,.105,.045);material.roughness=.56;mesh.material=material
  effect.mesh=mesh;effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(effect);particles.append(effect)
 previous=cart.global_position
func _physics_process(delta:float) -> void:
 if cart==null:return
 elapsed+=delta
 if previous.is_finite():measured_speed=cart.global_position.distance_to(previous)/maxf(delta,.001)
 previous=cart.global_position
 if elapsed<.08:return
 elapsed=0;active_emission=false;wet_contacts=0
 var player:=get_tree().current_scene.get_node_or_null("Player") as Node3D
 var near:=player==null or player.global_position.distance_to(cart.global_position)<110
 var moving:=measured_speed>.35 and measured_speed<25 and near
 for index in particles.size():
  var effect:CPUParticles3D=particles[index];effect.emitting=false
  if not moving:continue
  var local:Vector3=cart.wheels[index].position if cart.get("wheels")!=null and cart.wheels.size()>index else Vector3(-1 if index==0 else 1,0,2.5)
  var at:Vector3=cart.to_global(local);var wet:=wet_strength(Vector2(at.x,at.z))
  if wet<.08:continue
  var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,cart.global_position.y+1,at.z),Vector3(at.x,cart.global_position.y-1,at.z),1,cart.boarding._vehicle_exclusions())
  var ground:=cart.get_world_3d().direct_space_state.intersect_ray(query)
  if ground.is_empty() or ground.normal.y<.75:continue
  effect.global_position=ground.position+Vector3.UP*.06
  effect.direction=(cart.global_basis*Vector3(-.65 if index==0 else .65,1,.35)).normalized()
  effect.initial_velocity_max=minf(2.1,.9+measured_speed*.15);effect.emitting=true;wet_contacts+=1;active_emission=true
