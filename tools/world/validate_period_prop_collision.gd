extends SceneTree
## Straight approach with the actual Player controller, without jump input.

const NAMES := [
	"CompanyStoresWoodenCrate", "BhairavpurWoodenBucket", "BhairavpurBrassPot",
	"BhairavpurWickerBasket", "BhairavpurWoodenStool", "CompanyGuardBench",
	"CompanyStoresWineBarrel",
]
const SIDE_OFFSETS := [
	Vector3.LEFT, Vector3.LEFT, Vector3.RIGHT, Vector3.LEFT,
	Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT,
]
var failures: Array[String] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var settlement: Node3D = world.get_node("Settlement")
	for i in 12:
		await physics_frame
	for prop_index in NAMES.size():
		var name: String = NAMES[prop_index]
		var prop: StaticBody3D = settlement.get_node(name)
		for offset in [Vector3.BACK, SIDE_OFFSETS[prop_index]]:
			var target := prop.global_position
			player.global_position = target + offset * 2.0 + Vector3.UP * .95
			player.velocity = Vector3.ZERO
			player.get_node("CameraPivot").global_rotation.y = atan2(offset.x, offset.z)
			for i in 12:
				await physics_frame
			var settled := player.global_position
			var touched := false
			Input.action_press("move_forward")
			for i in 100:
				await physics_frame
				for collision_index in player.get_slide_collision_count():
					var hit := player.get_slide_collision(collision_index).get_collider()
					if hit == prop:
						touched = true
			Input.action_release("move_forward")
			for i in 5:
				await physics_frame
			var finish := player.global_position
			var progress := (settled - finish).dot(offset)
			var crossed := (finish - target).dot(offset) < -.35
			var ok := touched and not crossed and progress > .2
			var label := name + " from " + str(offset)
			print(("PASS " if ok else "FAIL ") + label + " touched=" + str(touched) + " crossed=" + str(crossed) + " progress=" + str(progress) + " finish=" + str(finish))
			if not ok:
				failures.append(label)
			results.append({"prop":name,"approach":str(offset),"touched":touched,"crossed":crossed,"progress":progress,"finish":str(finish),"pass":ok})
	var file := FileAccess.open("res://docs/world/period_prop_collision_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"results":results,"failures":failures},"\t")+"\n")
	print("PERIOD PROP COLLISION ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
