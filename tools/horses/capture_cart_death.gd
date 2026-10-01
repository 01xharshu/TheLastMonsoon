extends Node3D
var cart: Node3D
var elapsed := 0.0
var killed := false
func _ready() -> void:
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);add_child(sun)
	var ground:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(30,.1,30);ground.mesh=mesh;ground.position.y=-.05
	var earth:=StandardMaterial3D.new();earth.albedo_color=Color(.46,.39,.26);ground.material_override=earth;add_child(ground)
	cart=preload("res://vehicles/family_carriage_candidate.gd").new();add_child(cart)
	var camera:=Camera3D.new();camera.position=Vector3(-6,3.2,-4.5);camera.fov=48;add_child(camera);camera.look_at(Vector3(0,1,0));camera.make_current()
func _physics_process(delta: float) -> void:
	elapsed+=delta
	if elapsed<1.0:
		cart.position.z-=delta*.7
		cart.set_forward_motion(.7,delta)
	elif not killed:
		killed=true
		cart.combat.horses[0].take_damage(100)
	else:cart.set_forward_motion(0,delta)
	if elapsed>4.5:get_tree().quit()
func _process(_delta: float) -> void:
	RenderingServer.force_draw(false)
