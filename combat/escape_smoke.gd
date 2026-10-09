extends Node3D
## Temporary visibility cover, with no body collision or invulnerability.
const RADIUS := 3.0
const DURATION := 9.0
var age := 0.0
func _ready() -> void:
	add_to_group("escape_smoke")
	var particles:=CPUParticles3D.new();add_child(particles)
	particles.amount=48;particles.lifetime=4;particles.preprocess=2
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;particles.emission_sphere_radius=2.1
	particles.gravity=Vector3(0,.08,0);particles.initial_velocity_min=.1;particles.initial_velocity_max=.3
	particles.scale_amount_min=.8;particles.scale_amount_max=1.4
	var mesh:=SphereMesh.new();mesh.radius=.65;mesh.height=1.3;mesh.radial_segments=8;mesh.rings=4
	var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(.57,.55,.48,.25);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material=mat;particles.mesh=mesh
func _process(delta: float) -> void:
	age+=delta
	if age>=DURATION:queue_free()
static func obscures(tree: SceneTree, from: Vector3, to: Vector3) -> bool:
	var segment:=to-from
	for cloud in tree.get_nodes_in_group("escape_smoke"):
		if cloud.age>=DURATION:continue
		var t: float=clampf((cloud.global_position-from).dot(segment)/maxf(segment.length_squared(),.001),0,1)
		if (from+segment*t).distance_to(cloud.global_position)<RADIUS:return true
	return false
