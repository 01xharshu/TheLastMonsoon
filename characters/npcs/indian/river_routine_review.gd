extends Node3D
## Three independently animated adult women; shortened flat route for review.
const Woman = preload("res://characters/npcs/indian/river_woman_study.gd")
var women: Array[Node3D] = []
func _ready() -> void:
	for index in 3:
		var woman := Woman.new()
		woman.name = "RiverWoman%d" % index
		woman.member_index = index
		woman.home = Vector3((index - 1) * 1.4, 0, 2)
		woman.bank = Vector3((index - 1) * 1.4, 0, -2)
		add_child(woman)
		woman.sample(float(index)*.31)
		women.append(woman)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 18)
	floor_mesh.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(.29, .26, .18)
	floor_mesh.material_override = earth
	add_child(floor_mesh)
	var river := MeshInstance3D.new()
	var water := PlaneMesh.new()
	water.size = Vector2(16, 4.6)
	river.mesh = water
	river.position = Vector3(0, .01, -4.7)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(.12, .27, .30)
	blue.roughness = .25
	river.material_override = blue
	add_child(river)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.3, .34, .4)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	add_child(environment)
	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.fov = 42.0
	camera.position = Vector3(4.8, 3, 5.5)
	add_child(camera)
	camera.look_at(Vector3(0, .7, -1))
	camera.current = true
