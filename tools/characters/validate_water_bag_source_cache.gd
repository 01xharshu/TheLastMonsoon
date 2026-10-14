extends SceneTree
## Verify retained runtime inputs against the unchanged authoritative source.
const Inputs = preload('res://player/water_bag_source_arrays.gd')
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(('PASS ' if ok else 'FAIL ')+label)
	if not ok: failures.append(label)
func run() -> void:
	var mesh: ArrayMesh = load(Inputs.SOURCE)
	for surface in mesh.get_surface_count():
		var cached := Inputs.arrays(mesh,surface)
		var original := mesh.surface_get_arrays(surface)
		check(var_to_bytes(cached)==var_to_bytes(original),'stopper CPU payload is byte-exact to source surface '+str(surface))
		var first: Vector3 = cached[Mesh.ARRAY_VERTEX][0]
		cached[Mesh.ARRAY_VERTEX][0] += Vector3.ONE
		check(Inputs.arrays(mesh,surface)[Mesh.ARRAY_VERTEX][0]==first,'caller mutation cannot change retained source')
	var stale := Resource.new()
	stale.set_meta('revision',1); stale.set_meta('source_sha256','changed')
	check(Inputs.arrays(mesh,0,stale).is_empty(),'changed source checksum rejects cached inputs')
	check(Inputs.arrays(BoxMesh.new(),0).is_empty(),'procedural and unrelated meshes retain reference path')
	var missing := Resource.new(); missing.set_meta('revision',1)
	missing.set_meta('source_sha256',FileAccess.get_sha256(Inputs.SOURCE))
	check(Inputs.arrays(mesh,0,missing).is_empty(),'missing surfaces reject cache')
	print('POUCH SOURCE CACHE '+('PASS' if failures.is_empty() else 'FAIL'))
	preload('res://tools/test_audio_cleanup.gd').finish(self,0 if failures.is_empty() else 1)
