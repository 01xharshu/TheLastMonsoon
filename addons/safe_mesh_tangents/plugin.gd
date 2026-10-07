@tool
extends EditorPlugin

var tangent_importer: EditorScenePostImportPlugin

func _enter_tree() -> void:
	tangent_importer = preload("res://addons/safe_mesh_tangents/tangent_importer.gd").new()
	add_scene_post_import_plugin(tangent_importer)

func _exit_tree() -> void:
	remove_scene_post_import_plugin(tangent_importer)
	tangent_importer = null
