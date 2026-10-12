extends Node3D
## Temporary visibility cover, with no body collision or invulnerability.
const RADIUS := 3.0
const DURATION := 9.0
var age := 0.0
func _ready() -> void:
	add_to_group("escape_smoke")
	var particles:=preload("res://world/suryagarh/settlements/village_combustion.gd").make_smoke(self)
	particles.amount=48;particles.lifetime=4;particles.preprocess=2
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;particles.emission_sphere_radius=2.1
	particles.gravity=Vector3(0,.08,0);particles.initial_velocity_min=.1;particles.initial_velocity_max=.3
	particles.scale_amount_min=.8;particles.scale_amount_max=1.4
	var growth:=Curve.new();growth.max_value=2;growth.add_point(Vector2(0,.8));growth.add_point(Vector2(1,1.8))
	particles.scale_amount_curve=growth
	var density:=Gradient.new();density.set_color(0,Color(.57,.55,.48,0));density.set_color(1,Color(.57,.55,.48,0))
	density.add_point(.12,Color(.57,.55,.48,.48));density.add_point(.65,Color(.57,.55,.48,.28))
	particles.color_ramp=density
	particles.emitting=true
func _process(delta: float) -> void:
	age+=delta
	# Stop feeding the cloud early enough for its final wisps to fade before removal.
	if age>=DURATION-4:
		get_node("FireSmoke").emitting=false
	if age>=DURATION:queue_free()
static func obscures(tree: SceneTree, from: Vector3, to: Vector3) -> bool:
	var segment:=to-from
	for cloud in tree.get_nodes_in_group("escape_smoke"):
		if cloud.age>=DURATION:continue
		var t: float=clampf((cloud.global_position-from).dot(segment)/maxf(segment.length_squared(),.001),0,1)
		if (from+segment*t).distance_to(cloud.global_position)<RADIUS:return true
	return false
