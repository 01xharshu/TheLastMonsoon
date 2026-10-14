extends SceneTree
## Rebuild retained CPU stopper inputs from the authoritative mesh, headlessly.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name() != 'headless':
		push_error('Build CPU inputs with --headless'); quit(2); return
	var source := 'res://assets/props/household/pouch_stopper.res'
	var target := 'res://assets/props/household/pouch_stopper_cpu.res'
	var mesh: ArrayMesh = load(source)
	var surfaces: Array = []
	for surface in mesh.get_surface_count(): surfaces.append(mesh.surface_get_arrays(surface))
	var cache := Resource.new()
	cache.set_meta('revision',1)
	cache.set_meta('source_sha256',FileAccess.get_sha256(source))
	cache.set_meta('surfaces',surfaces)
	var temporary := target.trim_suffix('.res')+'.building.res'
	var error := ResourceSaver.save(cache,temporary,ResourceSaver.FLAG_COMPRESS)
	if error == OK: error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(target))
	if error != OK: DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	print('POUCH CPU INPUT BUILD ', 'PASS' if error==OK else 'FAIL', ' surfaces=',surfaces.size())
	preload('res://tools/test_audio_cleanup.gd').finish(self,0 if error==OK else 1)
