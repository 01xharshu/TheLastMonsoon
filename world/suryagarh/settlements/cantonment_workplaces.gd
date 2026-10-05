extends Node3D
## Five anchored service attendants; shared audited MPFB model, bounded nearby idles.
const Staff = preload("res://characters/npcs/households/fort_staff.gd")
static var shared_staff: PackedScene
var workers: Array[Node3D] = []
var elapsed := 0.0
var update_usec := 0
var active_workers := 0
var garment_materials: Dictionary = {}

static func install(b, district: Node3D) -> void:
	var manager = load("res://world/suryagarh/settlements/cantonment_workplaces.gd").new()
	manager.name = "ServiceWorkplaces"
	district.add_child(manager)
	manager.configure(b,district)

func configure(b, district: Node3D) -> void:
	var started := Time.get_ticks_usec()
	var specs := [
		["GrainFodderWarehouse","Storekeeper",Vector3(-6,.24,4.25),PI],
		["CavalryStables","Groom",Vector3(-12.5,.24,3.8),PI],
		["MilitaryHospital","Orderly",Vector3(.9,.24,-2.0),PI],
		["CantonmentChurch","LayCaretaker",Vector3(-3.8,.44,-5.5),0.0],
		["MilitaryCemetery","GroundsKeeper",Vector3(-4.5,0,8.8),0.0]
	]
	for spec in specs:
		var room: Node3D = district.get_node(spec[0])
		room.set_meta("workplace_role",spec[1])
		var marker := Marker3D.new()
		marker.name = "Workplace"
		marker.position = spec[2]
		room.add_child(marker)
		if shared_staff == null:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			assert(document.append_from_file(ProjectSettings.globalize_path("res://WorkingAssets/NPCs/fort_staff/fort_staff_rigged_candidate.glb"),state)==OK)
			var imported := document.generate_scene(state)
			shared_staff = PackedScene.new()
			assert(shared_staff.pack(imported)==OK)
			imported.free()
		var actor = Staff.new()
		actor.name = spec[1]
		actor.household_job = "Steward"
		actor.movement_enabled = false
		actor.position = spec[2]
		actor.rotation.y = spec[3]
		actor.set_meta("service_role",spec[1])
		actor.set_meta("workplace",marker.get_path())
		actor.set_meta("visual_status","shared MPFB attendant candidate; role acting/contact open")
		actor.add_child(shared_staff.instantiate())
		actor.add_to_group("cantonment_service_workers")
		room.add_child(actor)
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var override: Material = mesh.get_surface_override_material(surface)
				if override != null:
					var key: String = str(mesh.name)+str(surface)
					if not garment_materials.has(key): garment_materials[key] = override
					mesh.set_surface_override_material(surface,garment_materials[key])
			mesh.visibility_range_end = 120
			mesh.visibility_range_end_margin = 10
		actor.set_process(false)
		if actor.animation_tree != null: actor.animation_tree.active = false
		workers.append(actor)
	set_meta("build_usec",Time.get_ticks_usec()-started)
	set_meta("maximum_active_workers",3)
	set_meta("shared_runtime_source","WorkingAssets/NPCs/fort_staff/fort_staff_rigged_candidate.glb")

func update_activity(observer: Vector3) -> void:
	var started := Time.get_ticks_usec()
	var nearest := workers.duplicate()
	nearest.sort_custom(func(a,b): return a.global_position.distance_squared_to(observer)<b.global_position.distance_squared_to(observer))
	active_workers = 0
	for actor in nearest:
		var distance: float = actor.global_position.distance_squared_to(observer)
		var active: bool = distance < 45*45 and active_workers < 3
		if active: active_workers += 1
		actor.set_process(active)
		if actor.animation_tree != null: actor.animation_tree.active = active
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if distance<25*25 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_usec = Time.get_ticks_usec()-started
	set_meta("active_workers",active_workers)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .25: return
	elapsed = 0
	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player != null: update_activity(player.global_position)

func _exit_tree() -> void:
	shared_staff = null
