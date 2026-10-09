extends Node3D
## Bounded real fire, heat light and wind-driven smoke; residual smoke expires.
var smoke_outlet := Vector3.ZERO # Parent-space point; zero uses the fire itself.
var schedule_offset := 0
var clock: Node
var smoke: CPUParticles3D
var flames: Array[MeshInstance3D] = []
var light: OmniLight3D
var burning := false
var elapsed := 0.0
var cooking := false
var wind: Node

func build(builder: Node3D, is_cooking := false) -> void:
	cooking=is_cooking
	add_to_group("village_combustion")
	for i in 3:
		var log_piece: Node3D=builder.piece(self,"FuelLog",Vector3((i-1)*.08,-.02,.42),Vector3(.46,.07,.07),builder.wood,false)
		log_piece.rotation.y=i*.85
		var flame := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius=.5;sphere.height=1;sphere.radial_segments=8;sphere.rings=4
		flame.mesh=sphere
		flame.scale=Vector3(.055,.15,.055)
		flame.position=Vector3((i-1)*.065,.025,.43)
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader=preload("res://world/suryagarh/settlements/village_flame.gdshader")
		material.set_shader_parameter("phase",float(i+schedule_offset))
		flame.material_override=material
		add_child(flame);flames.append(flame)
	light=OmniLight3D.new();light.name="FireLight"
	light.position=Vector3(0,.18,.25);light.light_color=Color(1,.49,.17)
	light.light_energy=.65;light.omni_range=3.5
	light.distance_fade_enabled=true;light.distance_fade_begin=28;light.distance_fade_length=12
	add_child(light)
	smoke=make_smoke(self)
	if smoke_outlet!=Vector3.ZERO: smoke.position=smoke_outlet-position
	clock=get_tree().get_first_node_in_group("game_time_system")
	if clock==null:clock=get_tree().root.find_child("GameTimeSystem",true,false)
	wind=get_tree().root.get_node_or_null("WindSystem")
	set_burning(false)

static func make_smoke(parent: Node3D) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name="FireSmoke"
	particles.emitting=false;particles.amount=26;particles.lifetime=5.0
	particles.local_coords=false
	particles.direction=Vector3.UP;particles.spread=12
	particles.initial_velocity_min=.35;particles.initial_velocity_max=.6
	particles.gravity=Vector3(0,.10,0)
	particles.scale_amount_min=.28;particles.scale_amount_max=.42
	var size := Curve.new();size.max_value=4.0;size.add_point(Vector2(0,.45));size.add_point(Vector2(1,3.6));particles.scale_amount_curve=size
	var fade := Gradient.new()
	fade.set_color(0,Color(.38,.37,.35,0));fade.set_color(1,Color(.54,.53,.50,0))
	fade.add_point(.15,Color(.43,.42,.39,.24));fade.add_point(.65,Color(.50,.49,.46,.13))
	particles.color_ramp=fade
	var quad := QuadMesh.new();quad.size=Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader=preload("res://world/suryagarh/settlements/village_smoke.gdshader")
	quad.material=material;particles.mesh=quad
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb=AABB(Vector3(-8,-1,-8),Vector3(16,8,16))
	parent.add_child(particles)
	return particles

func set_burning(active: bool) -> void:
	burning=active
	if smoke!=null:smoke.emitting=burning
	if light!=null:light.visible=burning
	for flame in flames:flame.visible=burning
	set_meta("burning",burning)

func _process(delta: float) -> void:
	elapsed+=delta
	if cooking and clock!=null:
		var hour: float=clock.current_hour+clock.current_minute/60.0
		var offset := schedule_offset*.18
		var active := (hour>=6.0+offset and hour<8.0+offset) or (hour>=17.0+offset and hour<19.0+offset)
		if active!=burning:set_burning(active)
	if smoke!=null and wind!=null:
		var drift: Vector3=wind.sample(smoke.global_position)*.16
		smoke.gravity=Vector3(drift.x,.10,drift.z)
	if light!=null and burning:light.light_energy=.65*(1+.06*sin(elapsed*7.0))
