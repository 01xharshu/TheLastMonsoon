extends Node3D
## A depth-tested stake at the destination, never attached above the player.
var map: Control
var target := Vector2(INF, INF)
var stake: MeshInstance3D
var beacon: MeshInstance3D
var label: Label3D
var fading := false
var arrival_tween: Tween
var site_identity := ""

func _ready() -> void:
	name = "WorldWaypoint"
	stake = MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.018
	shaft.bottom_radius = 0.035
	shaft.height = 1.2
	stake.mesh = shaft
	stake.position.y = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.28,0.15,0.065)
	wood.roughness = 0.95
	stake.material_override = wood
	add_child(stake)
	beacon = MeshInstance3D.new()
	var tip := PrismMesh.new()
	tip.size = Vector3(0.20,0.25,0.08)
	beacon.mesh = tip
	beacon.position.y = 1.3
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0,0.75,0.05)
	gold.emission_enabled = true
	gold.emission = Color(0.8,0.45,0.01)
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon.material_override = gold
	wood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(beacon)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position.y = 1.65
	label.fixed_size = true
	label.font = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
	label.outline_size = 4
	label.font_size = 32
	label.pixel_size = 0.001
	label.modulate = Color(1,0.8,0.2)
	add_child(label)
	hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(map): return
	if map.waypoint != target or map.selected_site != site_identity:
		if arrival_tween != null and arrival_tween.is_valid(): arrival_tween.kill()
		site_identity = map.selected_site
		target = map.waypoint
		fading = false
		stake.material_override.albedo_color.a = 1.0
		beacon.material_override.albedo_color.a = 1.0
		label.modulate.a = 1.0
		visible = target.is_finite()
		if not visible: return
		stake.visible = map.selected_site == ""
		var height: float = map.layout.height(target.x,target.y)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(target.x,height+80,target.y),Vector3(target.x,height-20,target.y))
		ray.exclude = [map.player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): height = hit.position.y
		global_position = Vector3(target.x,height,target.y)
	if not visible or fading: return
	var distance := Vector2(map.player.global_position.x,map.player.global_position.z).distance_to(target)
	label.text = "◆ %.0f m" % distance
	label.visible = distance > 6.0
	if distance <= 3.0:
		fading = true
		arrival_tween = create_tween().set_parallel()
		arrival_tween.tween_property(stake.material_override,"albedo_color:a",0.0,0.7)
		arrival_tween.tween_property(beacon.material_override,"albedo_color:a",0.0,0.7)
		arrival_tween.chain().tween_callback(func():
			if fading:
				map.waypoint = Vector2(INF,INF)
				map.selected_site = ""
				hide()
			arrival_tween = null
		)

func _exit_tree() -> void:
	if arrival_tween != null and arrival_tween.is_valid(): arrival_tween.kill()
	arrival_tween = null
