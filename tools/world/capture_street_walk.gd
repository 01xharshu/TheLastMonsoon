extends "res://world/suryagarh/settlements/village_street_life.gd"
var elapsed:=0.0
func _ready()->void:
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.shadow_enabled=true;add_child(light)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.48,.53,.55);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.83,.82);env.environment.ambient_light_energy=.5;add_child(env)
	var ground:=StaticBody3D.new();ground.position=Vector3(-338,7.15,275);add_child(ground)
	var floor:=BoxMesh.new();floor.size=Vector3(22,.1,14)
	var visual:=MeshInstance3D.new();visual.mesh=floor;ground.add_child(visual)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.38,.32,.22);visual.material_override=mat
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=floor.size;collider.shape=box;ground.add_child(collider)
	var a:Array[Vector2]=[Vector2(-344,275),Vector2(-333,275)]
	var b:Array[Vector2]=[Vector2(-344,276.1),Vector2(-333,276.1)]
	_lane("ReviewEarthLane",a,4,1)
	_resident("ClothVisitor","res://characters/npcs/households/merchant.glb",a,0)
	_resident("GrainBuyer","res://characters/npcs/households/landowner.glb",b,0)
	var camera:=Camera3D.new();camera.position=Vector3(-337,9,280);camera.fov=48;add_child(camera);camera.look_at(Vector3(-341,8.1,275));camera.make_current()
func _physics_process(delta:float)->void:
	for journey in journeys:
		journey.set_physics_process(false)
		journey.tick(delta)
	elapsed+=delta
	if elapsed>=5.0:get_tree().quit()
func _process(_delta:float)->void:
	RenderingServer.force_draw(false)
