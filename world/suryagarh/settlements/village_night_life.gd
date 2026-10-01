extends Node3D
## Clock-linked lamps and gathering fires; resident animation is a separate gate.
const OilLamp = preload("res://objects/oil_lamp.tscn")
var lamps: Array[Node] = []
var fires: Array[Node3D] = []
var clock: GameTimeSystem
var elapsed := 0.0
var night := false

func build(builder: Node3D) -> void:
	name = "VillageNightLife"
	builder.add_child(self)
	var brass: Material = builder.material(Color(.38,.25,.10))
	for i in 34:
		var home: Node3D = builder.get_node("BhairavpurHouse%d"%i) if i<33 else builder.get_node("BhairavpurLandownerEstate")
		var lamp_at := Vector3(1.72,1.40,1.3) if i<33 else Vector3(-12,1.03,-7)
		if i == 0:
			lamp_at = Vector3(0.37,1.40,1.3)
			for z in [1.13,1.47]:
				builder.piece(home,"HomeLampShelfBracket",Vector3(0.24,1.20,z),Vector3(0.32,0.30,0.08),builder.wood,false)
		if i<33: builder.piece(home,"LampShelf",lamp_at-Vector3.UP*.05,Vector3(.52,.10,.48),builder.wood,false)
		var lamp = OilLamp.instantiate()
		lamp.name = "HouseOilLamp"
		lamp.starts_lit = false
		lamp.position = lamp_at
		home.add_child(lamp)
		lamp.add_to_group("village_oil_lamp")
		# Retain the existing interaction and collision; replace only placeholder mesh.
		lamp.get_node("LampBody").hide()
		builder.piece(lamp,"Reservoir",Vector3(0,.10,0),Vector3(.26,.18,.22),brass,false)
		builder.piece(lamp,"WickSpout",Vector3(0,.16,.15),Vector3(.06,.04,.14),brass,false)
		builder.piece(lamp,"Wick",Vector3(0,.18,.20),Vector3(.018,.035,.018),builder.wood,false)
		var flame := _flame(lamp,Vector3(0,.23,.20),Vector3(.035,.09,.035))
		flame.name = "OilFlame"
		var light: OmniLight3D = lamp.get_node("LampLight")
		light.position = Vector3(0,.27,.20)
		light.light_color = Color(1,.63,.28)
		light.light_energy = 1.2
		light.omni_range = 6.5
		light.distance_fade_enabled = true
		light.distance_fade_begin = 35
		light.distance_fade_length = 15
		light.distance_fade_shadow = 18
		lamps.append(lamp)
	for point in [Vector2(-393,230),Vector2(-265,259)]:
		var site := Node3D.new()
		site.name = "GatheringFire%d"%fires.size()
		add_child(site)
		site.position = Vector3(point.x,builder.layout.height(point.x,point.y),point.y)
		site.add_to_group("village_gathering_fire")
		for i in 12:
			var angle: float = i*TAU/12.0
			builder.piece(site,"FireStone",Vector3(cos(angle)*.72,.09,sin(angle)*.72),Vector3(.23,.18,.20),builder.stone,false)
		for i in 5:
			var log_piece: Node3D = builder.piece(site,"Firewood",Vector3(0,.16+i*.025,0),Vector3(.95,.13,.14),builder.wood,false)
			log_piece.rotation.y = i*1.7
		for i in 5:
			_flame(site,Vector3((i%3-1)*.15,.37+i*.04,(i/3)*.12),Vector3(.18,.52,.18)).add_to_group("village_fire_flame")
		var light := OmniLight3D.new()
		light.name = "FireLight"
		light.position.y = .7
		light.light_color = Color(1,.46,.13)
		light.light_energy = 2.2
		light.omni_range = 8
		light.shadow_enabled = true
		site.add_child(light)
		for i in 4:
			var angle: float = i*PI*.5+.35
			var place := Marker3D.new()
			place.name = "FutureSeatedContact%d"%i
			place.position = Vector3(cos(angle)*1.8,.035,sin(angle)*1.8)
			place.rotation.y = -angle+PI*.5
			site.add_child(place)
			builder.piece(site,"GatheringMat",place.position,Vector3(.8,.025,1.0),builder.material(Color(.30,.24,.16)),false).rotation.y = place.rotation.y
		fires.append(site)
	call_deferred("_connect_clock")

func _flame(parent: Node3D,position_: Vector3,size: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = .5
	shape.height = 1
	mesh.mesh = shape
	mesh.position = position_
	mesh.scale = size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://world/suryagarh/settlements/village_flame.gdshader")
	material.set_shader_parameter("phase",position_.x*13+position_.y*21)
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _connect_clock() -> void:
	clock = get_parent().get_parent().get_node("GameTimeSystem")
	clock.time_changed.connect(_time_changed)
	_time_changed(clock.current_day,clock.current_hour,clock.current_minute)

func _time_changed(_day: int,hour: int,_minute: int) -> void:
	var next_night := hour >= 18 or hour < 6
	if next_night == night and has_meta("initialized"): return
	night = next_night
	set_meta("initialized",true)
	# Automatic household lighting changes at dusk/dawn, not every clock tick.
	# A player's manual extinguish/light action therefore persists during the night.
	for lamp in lamps:
		lamp.is_lit = night
		lamp._apply_lamp_state()

func _process(delta: float) -> void:
	elapsed += delta
	for lamp in lamps:
		lamp.get_node("OilFlame").visible = lamp.is_lit
	for i in fires.size():
		var site := fires[i]
		site.get_node("FireLight").visible = night
		site.get_node("FireLight").light_energy = 2.2*(1+.075*sin(elapsed*5+i)+.04*sin(elapsed*8.7))
		for child in site.get_children():
			if child is MeshInstance3D: child.visible = night
