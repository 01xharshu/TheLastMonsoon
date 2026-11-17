extends SceneTree
## Second process verifies the key written by validate_kick_binding is restored.
func _initialize()->void:run.call_deferred()
func run()->void:
 var settings:Node=root.get_node("SaveManager")
 var key:=InputEventKey.new();key.physical_keycode=KEY_L;key.pressed=true
 var original:=InputEventKey.new();original.physical_keycode=KEY_K;original.pressed=true
 var ok:bool=settings.options.key_bindings.get("kick")==KEY_L and key.is_action_pressed("kick") and not original.is_action_pressed("kick")
 print(("PASS " if ok else "FAIL ")+"kick rebind restores in a fresh game process")
 if ok:ok=settings.bind_key("kick",KEY_K)
 settings.quit_game(0 if ok else 1)
