extends SceneTree
func _initialize() -> void:
	print("AUTOLOAD SETTING ",ProjectSettings.get_setting("autoload/SaveManager","MISSING"))
	call_deferred("inspect")
func inspect() -> void:
	print("AUTOLOAD NODE ",root.get_node_or_null("SaveManager"))
	quit()
