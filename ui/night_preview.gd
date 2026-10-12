extends SubViewportContainer
## An isolated empty city-road scene; shares playable night ambient response.
const Lighting = preload("res://world/suryagarh/systems/sun_controller.gd")
var environment: Environment
var last_value := -1.0
func _ready() -> void:
	name = "NightPreview"
	custom_minimum_size = Vector2(460,200)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(460,200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.006,.012,.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.32,.42,.65)
	var env := WorldEnvironment.new()
	env.environment = environment
	scene.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60,-30,0)
	moon.light_color = Color(.75,.82,1)
	moon.light_energy = .18
	moon.shadow_enabled = true
	scene.add_child(moon)
	_box(scene,Vector3(0,-.15,0),Vector3(12,.3,22),Color(.24,.21,.17))
	for side in [-1,1]:
		_box(scene,Vector3(side*4.5,.03,0),Vector3(2,.15,22),Color(.34,.30,.24))
		for z in [-6,0,6]:
			_box(scene,Vector3(side*6,2,z),Vector3(2,4,5),Color(.42,.34,.25))
			_box(scene,Vector3(side*4.98,1.2,z),Vector3(.06,2,1),Color(.10,.07,.045))
	var character := preload("res://characters/arjun/arjun.glb").instantiate() as Node3D
	scene.add_child(character)
	character.rotation.y = .3
	var animations := character.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty() and animations[0].has_animation("idle"):
		animations[0].play("idle")
		animations[0].advance(0.0)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.15,2.4)
	scene.add_child(camera)
	camera.look_at(Vector3(0,1,0))
	camera.fov = 50.0
	camera.current = true
	_update_brightness()

func _box(scene: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .95
	box.material = material
	mesh.mesh = box
	mesh.position = at
	scene.add_child(mesh)

func _process(_delta: float) -> void:
	_update_brightness()

func _update_brightness() -> void:
	var value := float(get_node("/root/SaveManager").options.night_brightness)
	if environment != null and value != last_value:
		last_value = value
		environment.ambient_light_energy = Lighting.night_ambient(value)
