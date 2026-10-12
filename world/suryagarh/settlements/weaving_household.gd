extends RefCounted
## Yarn/work/output layout around the inherited loom placeholder.
func furnish(village, home: Node3D) -> void:
	var b = village.settlement
	var yarn: Material = village.house_detail.cloth[2]
	var cloth: Material = village.house_detail.cloth[0]
	home.set_meta("livelihood","weaving")
	home.set_meta("regional_basis","Awadh candidate; late June 1857 provisional")
	home.set_meta("loom_status","inherited placeholder; regional mechanism unresolved")
	home.set_meta("production_flow",["dry yarn hanks","preparation mat","loom placeholder","indoor folded cloth"])
	var old := home.get_node_or_null("HouseholdProp")
	if old: old.free()
	var kit := Node3D.new()
	kit.name = "WeavingKit"
	home.add_child(kit)
	# Low preparation surface under the left threshold shade.
	b.piece(kit,"PreparationBoard",Vector3(-3.0,.43,5.25),Vector3(1.5,.08,.7),b.wood)
	for x in [-3.6,-2.4]:
		for z in [5.0,5.5]:
			b.piece(kit,"PreparationLeg",Vector3(x,.195,z),Vector3(.09,.39,.09),b.wood)
	b.piece(kit,"YarnPreparationMat",Vector3(-3.0,.48,5.25),Vector3(1.2,.02,.58),yarn,false)
	# Hanks hang on separate pegs, apart from cooking and stored finished cloth.
	for x in [-3.7,-2.3]:
		b.piece(kit,"YarnRackPost",Vector3(x,.48,4.5),Vector3(.08,.96,.08),b.wood)
	b.piece(kit,"YarnRackRail",Vector3(-3.0,.88,4.5),Vector3(1.55,.08,.08),b.wood,false)
	for x in [-3.5,-3.0,-2.5]:
		b.piece(kit,"HankPeg",Vector3(x,.85,4.60),Vector3(.045,.045,.24),b.wood,false)
		var hank := MeshInstance3D.new()
		hank.name = "StoredYarnHank"
		var ring := TorusMesh.new()
		ring.inner_radius = .12
		ring.outer_radius = .16
		ring.rings = 16
		ring.ring_segments = 12
		hank.mesh = ring
		hank.material_override = yarn
		hank.position = Vector3(x,.68,4.66)
		hank.rotation.x = PI*.5
		hank.scale = Vector3(.7,1.0,1.6)
		kit.add_child(hank)
	# Simple yarn-winding cores, decorative; no spinning-wheel mechanism implied.
	for x in [-3.3,-2.8]:
		b.piece(kit,"WindingCore",Vector3(x,.5075,5.25),Vector3(.035,.035,.34),b.wood,false)
		b.piece(kit,"WoundYarn",Vector3(x,.53,5.25),Vector3(.075,.08,.18),yarn,false)
	# Dry finished goods in the front-right indoor bay, away from rear hearth.
	b.piece(kit,"ClothStoreDeck",Vector3(3.35,.675,1.3),Vector3(1.5,.09,.80),b.wood)
	for x in [2.75,3.95]:
		for z in [1.02,1.58]:
			b.piece(kit,"ClothStoreLeg",Vector3(x,.435,z),Vector3(.10,.39,.10),b.wood)
	for i in 3:
		b.piece(kit,"FoldedCloth",Vector3(3.35,.745+i*.055,1.3),Vector3(1.05,.05,.62),cloth,false)
	for x in [3.63,3.97]:
		b.piece(kit,"LampShelfCorbel",Vector3(x,1.22,3.3),Vector3(.15,.20,.24),b.wood,false)
	kit.set_meta("fibre","unresolved; no local cultivar or fibre claim")
	kit.set_meta("actions","decorative; no weaving or spinning prompts")
