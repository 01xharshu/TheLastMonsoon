extends RefCounted
## Per-person fabric colours on the existing skinned garments. Body and
## foundation materials remain owned by the imported MPFB character.
const CLOTHES := {
	"cart_maker": [Color("776149"), Color("534734")],
	"milkman": [Color("ddd4bc"), Color("a89d83")],
	"potter": [Color("4c6570"), Color("765744")],
	"student": [Color("cabd9f"), Color("827865")],
	"lecturer": [Color("675b49"), Color("423d37")],
	"printer": [Color("718073"), Color("595850")],
}
## Individual appearance, independent of the worker's occupation.
const SKIN_MULTIPLIERS := {
	"CartMaker": Color(1.0, 1.0, 1.0),
	"Milkman": Color(1.12, 1.09, 1.06),
	"Potter": Color(1.35, 1.27, 1.18),
}
const INDIVIDUAL_TONES := [Color(1.0, 1.0, 1.0), Color(1.12, 1.09, 1.06), Color(1.35, 1.27, 1.18)]

static func apply(actor: Node3D, role: String) -> int:
	if not CLOTHES.has(role): return 0
	var changed := 0
	for part: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		var label := str(part.name).to_lower().replace("_", " ")
		if "complete makehuman body" in label:
			var identity := str(actor.name)
			var tone: Color = SKIN_MULTIPLIERS.get(identity, INDIVIDUAL_TONES[posmod(identity.hash(), INDIVIDUAL_TONES.size())])
			for surface in part.mesh.get_surface_count():
				var skin := part.get_active_material(surface) as StandardMaterial3D
				if skin == null: continue
				var individual := skin.duplicate() as StandardMaterial3D
				individual.albedo_color *= tone
				part.set_surface_override_material(surface, individual)
			continue
		var slot := 0 if label.begins_with("activity cotton shirt") else 1 if label.begins_with("activity cotton trousers") else -1
		if slot < 0 or part.mesh == null: continue
		for surface in part.mesh.get_surface_count():
			var original := part.get_active_material(surface)
			if original is StandardMaterial3D:
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color = CLOTHES[role][slot]
				part.set_surface_override_material(surface, material)
			elif original is ShaderMaterial:
				var material := original.duplicate() as ShaderMaterial
				material.set_shader_parameter("cloth_color", CLOTHES[role][slot])
				part.set_surface_override_material(surface, material)
			else: continue
			changed += 1
	actor.set_meta("occupation_fabric_role", role)
	return changed
