extends SceneTree
## Imported MakeHuman instances must share immutable meshes, not mutable animation.
const Humans = preload("res://characters/human_scene.gd")
var failed := false

func require(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in [
		"res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb",
		"res://characters/npcs/motion/village_woman/village_woman_rigged_candidate.glb",
		"res://characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb",
		"res://characters/npcs/motion/fort_staff/fort_staff_rigged_candidate.glb",
		"res://characters/npcs/dev/dev_idle_candidate.glb",
		"res://characters/npcs/households/staff_farmer.glb",
		"res://characters/npcs/households/staff_woman.glb",
		"res://characters/npcs/motion/errand_passenger/errand_passenger.glb",
	]:
		var first := Humans.instantiate(path)
		var second := Humans.instantiate(path)
		require(first != null and second != null, "Imported human loads")
		var first_rig: Skeleton3D = first.find_children("*", "Skeleton3D", true, false)[0]
		var second_rig: Skeleton3D = second.find_children("*", "Skeleton3D", true, false)[0]
		require(first_rig != second_rig and first_rig.get_bone_count() == second_rig.get_bone_count(), "Independent intact skeletons")
		var first_player: AnimationPlayer = first.find_child("AnimationPlayer", true, false)
		var second_player: AnimationPlayer = second.find_child("AnimationPlayer", true, false)
		require(first_player != null and second_player != null, "Animations preserved")
		for library_name in first_player.get_animation_library_list():
			var a := first_player.get_animation_library(library_name)
			var b := second_player.get_animation_library(library_name)
			require(a != b, "Independent animation libraries")
			for name in a.get_animation_list():
				require(a.get_animation(name) != b.get_animation(name), "Independent mutable clips")
		var a_meshes := first.find_children("*", "MeshInstance3D", true, false)
		var b_meshes := second.find_children("*", "MeshInstance3D", true, false)
		require(a_meshes.size() == b_meshes.size() and not a_meshes.is_empty(), "All human mesh nodes retained")
		for index in a_meshes.size():
			require(a_meshes[index].mesh == b_meshes[index].mesh, "Immutable geometry is shared")
		first.free()
		second.free()
	print("HUMAN CACHE ", "FAIL" if failed else "PASS", " | 8 models, independent skeletons/clips, shared immutable geometry")
	root.get_node("SaveManager").quit_game(1 if failed else 0)
