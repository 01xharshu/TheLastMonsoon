extends Node3D
## Small wet clods thrown from grounded wheels; bounded, world-space particles.
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
var cart:Node3D
var particles:Array[CPUParticles3D]=[]
var dust:Array[CPUParticles3D]=[]
var splashes:Array[CPUParticles3D]=[]
var player:Node3D
var wind:Node
var world:Node
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
 for lane:Array in preload("res://world/suryagarh/settlements/countryside_density.gd").lanes():
  for i in lane.size()-1:
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,lane[i],lane[i+1]))<1.55:return wet
 return 0
func configure(vehicle:Node3D) -> void:cart=vehicle
func _ready() -> void:
 for index in mini(cart.wheels.size(),4):
  var side:float=signf(cart.to_local(cart.wheels[index].global_position).x)
  var effect:=CPUParticles3D.new();effect.name="LeftWheelClods" if side<0 else "RightWheelClods"
  effect.amount=28;effect.lifetime=.32;effect.randomness=.45;effect.local_coords=false;effect.emitting=false
  effect.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;effect.emission_sphere_radius=.045
  effect.gravity=Vector3(0,-9.8,0);effect.initial_velocity_min=.8;effect.initial_velocity_max=1.5;effect.spread=24
  effect.scale_amount_min=.45;effect.scale_amount_max=1.0;effect.color=Color(.18,.105,.047,1)
  var mesh:=SphereMesh.new();mesh.radius=.022;mesh.height=.028;mesh.radial_segments=6;mesh.rings=3
  var material:=StandardMaterial3D.new();material.albedo_color=Color(.19,.105,.045);material.roughness=.56;mesh.material=material
  effect.mesh=mesh;effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(effect);particles.append(effect)
  var splash:=CPUParticles3D.new();splash.name="WheelSplash%d"%index
  splash.amount=24;splash.lifetime=.38;splash.local_coords=false;splash.emitting=false
  splash.direction=Vector3(side,.4,.25);splash.spread=35;splash.gravity=Vector3(0,-9.8,0)
  splash.initial_velocity_min=.7;splash.initial_velocity_max=1.8;splash.scale_amount_min=.5;splash.scale_amount_max=1.0
  var drop:=SphereMesh.new();drop.radius=.09;drop.height=.035;drop.radial_segments=6;drop.rings=3
  var fluid:=StandardMaterial3D.new();fluid.albedo_color=Color(.30,.185,.085);fluid.roughness=.24;drop.material=fluid
  splash.mesh=drop;splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(splash);splashes.append(splash)
 world=preload("res://systems/world_context.gd").find_world(self)
 wind=get_tree().root.get_node_or_null("WindSystem")
 player=world.get_node_or_null("Player") as Node3D if world!=null else null
 for index in particles.size():
  var cloud:=preload("res://world/suryagarh/settlements/village_combustion.gd").make_smoke(self)
  cloud.name="WheelDust";cloud.amount=16;cloud.lifetime=1.8
  cloud.initial_velocity_min=.08;cloud.initial_velocity_max=.25;cloud.spread=55
  cloud.scale_amount_min=.18;cloud.scale_amount_max=.32
  var fade:=Gradient.new();fade.set_color(0,Color(.48,.39,.27,0));fade.set_color(1,Color(.55,.47,.34,0))
  fade.add_point(.18,Color(.48,.39,.27,.16));fade.add_point(.55,Color(.55,.47,.34,.07))
  cloud.color_ramp=fade;dust.append(cloud)
 previous=cart.global_position
func _physics_process(delta:float) -> void:
 if not is_instance_valid(cart):return
 elapsed+=delta
 if previous.is_finite():measured_speed=cart.global_position.distance_to(previous)/maxf(delta,.001)
 previous=cart.global_position
 if elapsed<.08:return
 elapsed=0;active_emission=false;wet_contacts=0
 var near:=not is_instance_valid(player) or player.global_position.distance_to(cart.global_position)<110
 var moving:=measured_speed>.35 and measured_speed<25 and near
 var wet_wheels: Array[int]=[]
 var dry_wheels: Array[int]=[]
 for index in particles.size():
  var effect:CPUParticles3D=particles[index]
  if not moving:continue
  var at:Vector3=cart.wheels[index].global_position;var wet:=wet_strength(Vector2(at.x,at.z))
  var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,cart.global_position.y+1,at.z),Vector3(at.x,cart.global_position.y-1,at.z),1,cart.boarding._vehicle_exclusions())
  var ground:=cart.get_world_3d().direct_space_state.intersect_ray(query)
  if ground.is_empty() or ground.normal.y<.75:continue
  if wet<.08:
   # Dry road dust only: reuse the authored route mask, never fields/interiors.
   if measured_speed<1.2:continue
   var on_road:=false
   for route in Layout.ROUTES.values():
    for segment in route.size()-1:
     if Vector2(at.x,at.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),route[segment],route[segment+1]))<1.4:on_road=true;break
    if on_road:break
   if not on_road:continue
   var roof:=PhysicsRayQueryParameters3D.create(ground.position+Vector3.UP*.2,ground.position+Vector3.UP*8,1,cart.boarding._vehicle_exclusions())
   if not cart.get_world_3d().direct_space_state.intersect_ray(roof).is_empty():continue
   var cloud:CPUParticles3D=dust[index]
   cloud.global_position=ground.position+Vector3.UP*.08
   var drift:Vector3=wind.sample(cloud.global_position)*.12 if wind!=null else Vector3.ZERO
   cloud.gravity=Vector3(drift.x,-.08,drift.z);dry_wheels.append(index)
   continue
  effect.global_position=ground.position+Vector3.UP*.06
  effect.direction=(cart.global_basis*Vector3(signf(cart.to_local(at).x)*.65,1,.35)).normalized()
  effect.initial_velocity_max=minf(2.1,.9+measured_speed*.15);wet_wheels.append(index);wet_contacts+=1;active_emission=true
  var splash:CPUParticles3D=splashes[index]
  # The worn track is a thin visual overlay above collision.
  splash.global_position=ground.position+Vector3.UP*.10
  splash.direction=(cart.global_basis*Vector3(signf(cart.to_local(at).x),.65,.4)).normalized()
  splash.initial_velocity_max=minf(2.8,1.0+measured_speed*.2)

 # Keep emitters running across consecutive wet samples so particles can age.
 for index in particles.size():
  particles[index].emitting=index in wet_wheels
  splashes[index].emitting=index in wet_wheels
  dust[index].emitting=index in dry_wheels
