extends RefCounted
## Stable, individual variation on existing complete MPFB skin textures.
## The small material cache belongs to the world, not to global process state.
const TONES := [Color(1.0,1.0,1.0), Color(1.12,1.09,1.06), Color(1.35,1.27,1.18)]
const CACHE_KEY := "population_skin_materials"

static func apply(actor: Node3D) -> void:
	if actor.has_meta("population_skin_tone"): return
	var identity := str(actor.name)
	if not (identity.begins_with("Street_") or identity.begins_with("Colleague_") or identity.begins_with("Village_")): return
	var world := preload("res://systems/world_context.gd").find_world(actor)
	if world == null: return
	var cache: Dictionary = world.get_meta(CACHE_KEY, {})
	var index := posmod(identity.hash(), TONES.size())
	var applied := false
	for part: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if not "makehuman_body" in str(part.name).to_lower() or part.mesh == null: continue
		for surface in part.mesh.get_surface_count():
			var source := part.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture == null: continue
			var key := [source, index]
			if not cache.has(key):
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color *= TONES[index]
				cache[key] = material
			part.set_surface_override_material(surface, cache[key])
			applied = true
	if applied:
		world.set_meta(CACHE_KEY, cache)
		actor.set_meta("population_skin_tone", index)
