extends RefCounted
## Supplemental production dressing for the existing asset-first carpenter station.
func furnish(village, home: Node3D) -> void:
	var b = village.settlement
	home.set_meta("livelihood", "carpentry")
	home.set_meta("regional_basis", "Awadh candidate; late June 1857 provisional")
	home.set_meta("production_flow", ["covered timber", "existing bench", "offcuts", "finished stools"])
	var prop := home.get_node_or_null("HouseholdProp")
	if prop: prop.free()
	var old_stock := home.get_node_or_null("TimberStock")
	if old_stock: old_stock.free()
	var kit := Node3D.new()
	kit.name = "CarpenterMaterialKit"
	home.add_child(kit)
	# Stock stays off damp ground and clear of the centre approach.
	for x in [-3.65, -1.75]:
		b.piece(kit, "TimberSleeper", Vector3(x, .12, 4.25), Vector3(.14, .24, .90), b.wood)
	for layer in 3:
		for row in 3:
			b.piece(kit, "StoredPlank", Vector3(-2.7, .27 + layer * .10, 3.96 + row * .28), Vector3(2.7, .075, .22), b.wood)
		if layer < 2:
			for x in [-3.65, -1.75]:
				b.piece(kit, "StackSticker", Vector3(x, .318 + layer * .10, 4.25), Vector3(.07, .025, .82), b.wood, false)
	# The main project already supplies the supported bench and fitted hand tools.
	# Keep output and offcuts outside that station's collision and work surface.
	b.piece(kit, "OffcutFloor", Vector3(3.45, .025, 5.5), Vector3(.80, .05, .70), b.wood, false)
	for x in [3.05, 3.85]:
		b.piece(kit, "OffcutSide", Vector3(x, .17, 5.5), Vector3(.05, .34, .7), b.wood)
	for z in [5.15, 5.85]:
		b.piece(kit, "OffcutEnd", Vector3(3.45, .17, z), Vector3(.85, .34, .05), b.wood)
	for i in 7:
		var offcut = b.piece(kit, "ShortOffcut", Vector3(3.25 + (i % 3) * .18, .0775 + (i / 3) * .065, 5.48), Vector3(.12, .055, .43), b.wood, false)
		offcut.rotation.y = float(i % 3 - 1) * .17
	for x in [-3.2, -2.3]:
		b.piece(kit, "FinishedStoolSeat", Vector3(x, .48, 5.4), Vector3(.58, .08, .48), b.wood)
		for dx in [-.22, .22]:
			for dz in [-.17, .17]:
				b.piece(kit, "FinishedSeatLeg", Vector3(x + dx, .22, 5.4 + dz), Vector3(.065, .44, .065), b.wood)
	kit.set_meta("tool_forms", "existing fitted tools retained; exact Awadh profile unresolved")
	kit.set_meta("stock_species", "unresolved; no species claim")
