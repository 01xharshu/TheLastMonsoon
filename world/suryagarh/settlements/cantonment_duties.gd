extends Node3D
## Clock-driven barracks/parade/sentry/mess loop; bounded close actor updates.
const Sepoy = preload("res://characters/npcs/cantonment_sepoy.gd")
var actors: Array[Node3D] = []
var district: Node3D
var clock: Node
var current_duty := ""
var budget_elapsed := 0.0

func configure(site: Node3D) -> void:
	district = site
	var world: Node = preload("res://systems/world_context.gd").find_world(site)
	if world == null:
		push_error("Cantonment duties require their owning world's clock")
		return
	clock = world.get_node("GameTimeSystem")
	for i in 4:
		var actor = Sepoy.new()
		actor.name = "Sepoy%02d" % (i+1)
		actor.set_meta("source_model","characters/npcs/dev/dev_idle_candidate.glb")
		actor.set_meta("visual_status","unnamed uniform reuse; final sepoy diversity and role acting open")
		actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/dev/dev_idle_candidate.glb"))
		actor.add_to_group("cantonment_sepoys")
		district.add_child(actor)
		actor.position = Vector3(-20+i*4,.07,10)
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end = 120
		actors.append(actor)
	clock.time_changed.connect(_time_changed)
	_time_changed(clock.current_day,clock.current_hour,clock.current_minute)
	set_meta("maximum_active_sepoys",4)

func duty_at(hour: int) -> String:
	if hour < 6 or hour >= 20: return "rest"
	if hour < 7: return "assembly"
	if hour < 9: return "drill"
	if hour == 12: return "mess"
	if hour >= 18: return "evening_roll"
	return "sentry"

func _time_changed(_day: int,hour: int,_minute: int) -> void:
	var next := duty_at(hour)
	if next == current_duty: return
	current_duty = next
	for i in actors.size():
		var actor = actors[i]
		var destination := Vector3(-18+i*4,.07,8)
		if next == "sentry": destination = Vector3(24 if i%2==0 else -24,.07,-18 if i<2 else 18)
		if next == "drill": destination = Vector3(-18+i*4,.07,-10)
		if next == "mess": destination = Vector3(-18+i*4,.07,20)
		var points: Array[Vector3] = [district.to_global(destination)]
		# Stay within the surveyed open parade for the first loop. Barrack beds and
		# mess manipulation need their own supported/contact-reviewed routes.
		actor.assign_duty(next,points)
	set_meta("current_duty",current_duty)

func _process(delta: float) -> void:
	budget_elapsed += delta
	if budget_elapsed < .25: return
	budget_elapsed = 0
	var world: Node = preload("res://systems/world_context.gd").find_world(self)
	var player: Node3D = world.get_node_or_null("Player") as Node3D if world != null else null
	if player == null: return
	for actor in actors:
		var active: bool = actor.global_position.distance_squared_to(player.global_position) < 100*100
		actor.set_process(active)
		if actor.animation_tree != null: actor.animation_tree.active = active
