extends Node3D
## Held by an existing complete-body MPFB resident; never creates a human.
var actor: Node3D
var flame: MeshInstance3D
var light: OmniLight3D
var smoke: CPUParticles3D
var elapsed := 0.0
var hand_error := 0.0
var reach_error := 0.0
var held := false

func configure(person: Node3D) -> void:
	actor=person
	name="CarriedNightTorch"
	actor.add_child(self)
	add_to_group("village_carried_light")
	var wood := StandardMaterial3D.new();wood.albedo_color=Color(.27,.17,.08);wood.roughness=.9
	var cloth := StandardMaterial3D.new();cloth.albedo_color=Color(.20,.13,.08);cloth.roughness=1.0
	_member("TorchShaft",.018,.55,.025,wood)
	_member("FuelWrap",.045,.13,.32,cloth)
	for y in [.28,.32,.36]:_member("WrapBinding",.048,.016,y,wood)
	flame=MeshInstance3D.new()
	var shape := SphereMesh.new();shape.radius=.5;shape.height=1;shape.radial_segments=8;shape.rings=4
	flame.mesh=shape;flame.scale=Vector3(.065,.18,.065);flame.position.y=.44
	flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new();material.shader=preload("res://world/suryagarh/settlements/village_flame.gdshader")
	flame.material_override=material;add_child(flame)
	light=OmniLight3D.new();light.name="FireLight";light.position.y=.48
	light.light_color=Color(1,.52,.21);light.light_energy=1.0;light.omni_range=4.5
	light.distance_fade_enabled=true;light.distance_fade_begin=28;light.distance_fade_length=12
	add_child(light)
	smoke=preload("res://world/suryagarh/settlements/village_combustion.gd").make_smoke(self)
	smoke.position.y=.55;smoke.amount=8;smoke.lifetime=2.0
	visible=false

func _member(label: String, radius: float, height: float, y: float, material: Material) -> void:
	var mesh := MeshInstance3D.new();mesh.name=label
	var cylinder := CylinderMesh.new();cylinder.top_radius=radius;cylinder.bottom_radius=radius;cylinder.height=height;cylinder.radial_segments=10
	mesh.mesh=cylinder;mesh.position.y=y;mesh.material_override=material;add_child(mesh)

func update(delta: float, active: bool) -> void:
	elapsed+=delta
	active=active and not actor.get_meta("dead",false) and not actor.get_meta("knocked_out",false) and not actor.get_meta("grappled",false)
	if held and not active:actor.set_grip("r",0.0)
	held=active;visible=active;smoke.emitting=active
	if not active:return
	# The raised forearm stays outside the torso, while locomotion and the free
	# arm retain their existing AnimationTree. Contact runs after journey animation.
	var rig: Skeleton3D=actor._skeleton
	var shoulder: Vector3=actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("upperarm_r")).origin))
	var outward := -1.0 if shoulder.x<0.0 else 1.0
	position=shoulder+Vector3(outward*.14,-.26,.34)
	position.y+=.015*sin(elapsed*3.2)
	rotation=Vector3(.28,0,-outward*.40)
	var target := to_global(Vector3.ZERO)
	actor.solve_hand_contact("r",target)
	actor.set_grip("r",.85)
	reach_error=actor.palm_world("r").distance_to(target)
	# Anchor the handle to the solved palm rather than leave a visible IK gap.
	global_position+=actor.palm_world("r")-target
	hand_error=actor.palm_world("r").distance_to(global_position)
	set_meta("hand_contact_error",hand_error)
	if actor.drape!=null:actor.drape.update()
	light.light_energy=1.0+.06*sin(elapsed*7)
	var wind := get_tree().root.get_node_or_null("WindSystem")
	if wind!=null:
		var drift: Vector3=wind.sample(global_position)*.16
		smoke.gravity=Vector3(drift.x,.10,drift.z)
