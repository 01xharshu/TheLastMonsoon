extends RefCounted
## Reusable period furnishings. Original geometry; shared CC0 surface maps.
static func furnish(b: Node3D) -> void:
	# Door leaves are fixed open against the jambs, leaving the 4.4 m entrance clear.
	for level in 2:
		var y: float = level*b.floor_y
		for side in [-1,1]:
			b.piece(b,"OpenDoorLeaf",Vector3(side*2.25,y+1.4,b.depth*.5-1.05),Vector3(.14,2.8,2),b.wood)
			for rail_y in [.25,1.25,2.55]:
				b.piece(b,"DoorPanelRail",Vector3(side*2.15,y+rail_y,b.depth*.5-1.05),Vector3(.045,.10,1.8),b.wood,false)
			for hinge_y in [.4,2.3]:
				b.piece(b,"IronStrapHinge",Vector3(side*2.12,y+hinge_y,b.depth*.5-.65),Vector3(.045,.07,.95),b.iron,false)
		# Window shutters and deep stone sills in existing openings.
		for side in [-1,1]:
			for z in range(-int(b.depth*.5)+2,int(b.depth*.5),4):
				b.piece(b,"WindowSill",Vector3(side*b.width*.5,y+1.32,z),Vector3(.8,.12,2.4),b.stone,false)
				for edge in [-1,1]:
					b.piece(b,"ShutterFrame",Vector3(side*(b.width*.5+.3),y+2.25,z+edge*.95),Vector3(.10,1.75,.50),b.wood,false)
					for slat in 9:
						b.piece(b,"ShutterLouvre",Vector3(side*(b.width*.5+.37),y+1.48+slat*.18,z+edge*.95),Vector3(.12,.09,.44),b.wood,false).rotation.z = side*.25
		# Timber ceiling structure, joinery and board seams.
		for z in range(-int(b.depth*.5)+2,int(b.depth*.5),4):
			b.piece(b,"CeilingBeam",Vector3(0,y+5.02,z),Vector3(b.width-.5,.32,.22),b.wood,false)
		for row in 3:
			var z: float = -6+row*5
			for x in [-.4,6.4]:
				b.piece(b,"TableTrestle",Vector3(x,y+.4,z),Vector3(.16,.75,1.3),b.wood)
			for side in [-1,1]:
				for x in [-.4,6.4]:
					b.piece(b,"BenchLeg",Vector3(x,y+.2,z+side*1.4),Vector3(.12,.4,.42),b.wood,false)
			# Ledgers and folded paper on desks (no modern objects).
			b.piece(b,"Ledger",Vector3(1.5,y+.94,z),Vector3(.42,.08,.31),b.wood,false)
			b.piece(b,"PaperStack",Vector3(2.2,y+.93,z+.1),Vector3(.26,.025,.34),b.plaster,false)
		# Record shelves in the accessible rear office.
		for shelf in 5:
			b.piece(b,"RecordsShelf",Vector3(b.width*.5-1,y+.4+shelf*.52,-b.depth*.5+3),Vector3(.8,.07,4.4),b.wood)
			for book in 8:
				b.piece(b,"BoundRegister",Vector3(b.width*.5-1,y+.6+shelf*.52,-b.depth*.5+1.2+book*.45),Vector3(.52,.32,.17),b.wood,false)
		for z in [-b.depth*.5+1,b.depth*.5-1]:
			b.piece(b,"Skirting",Vector3(0,y+.14,z),Vector3(b.width-.8,.28,.12),b.wood,false)
		# Hanging oil lamp: brass-like frame, glass chamber and warm local glow.
		for x in [-5.0,8.0]:
			b.piece(b,"LampChain",Vector3(x,y+4.5,0),Vector3(.025,.85,.025),b.iron,false)
			b.piece(b,"LanternCap",Vector3(x,y+4.05,0),Vector3(.38,.10,.38),b.iron,false)
			b.piece(b,"LanternBase",Vector3(x,y+3.62,0),Vector3(.32,.08,.32),b.iron,false)
			for side in [-1,1]:
				for end in [-1,1]:
					b.piece(b,"LanternFrame",Vector3(x+side*.13,y+3.84,end*.13),Vector3(.035,.38,.035),b.iron,false)
	# Balustrade ends and roof drains make the large silhouette legible.
	for side in [-1,1]:
		b.piece(b,"BalconyEndRail",Vector3(side*b.width*.5,b.floor_y+.6,b.depth*.5+1.6),Vector3(.3,1.2,3.5),b.plaster)
		b.piece(b,"Downpipe",Vector3(side*(b.width*.5+.38),5.2,-b.depth*.5+.5),Vector3(.15,10.4,.15),b.iron,false)
		for y in [1.0,4.0,7.0,10.0]:
			b.piece(b,"PipeBracket",Vector3(side*(b.width*.5+.38),y,-b.depth*.5+.5),Vector3(.25,.07,.25),b.iron,false)
