extends RefCounted
static func surface(color:Color,kind:int=0)->ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://world/suryagarh/settlements/military_surface.gdshader")
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("kind",kind)
	return mat
static func prop(parent:Node3D,path:String,p:Vector3)->Node3D:
	var node:Node3D=load(path).instantiate()
	parent.add_child(node)
	node.position=p
	return node
static func room(b,room:Node3D,w:float,d:float,roof_ties:bool=true)->void:
	var timber:=surface(Color(.27,.17,.095),2)
	var lime:=surface(Color(.72,.68,.56))
	# Veranda eaves and framing clear the central approach.
	for x in [-w*.5+1.0,w*.5-1.0]:
		b.piece(room,"VerandaPost",Vector3(x,1.95,d*.5+1),Vector3(.16,3.42,.16),timber)
	b.piece(room,"VerandaBeam",Vector3(0,3.62,d*.5+1),Vector3(w+.3,.18,.18),timber)
	b.piece(room,"EaveShade",Vector3(0,3.74,d*.5+.65),Vector3(w+.6,.12,1.7),timber,false)
	if roof_ties:
		for x in range(-int(w*.5)+2,int(w*.5),3):
			b.piece(room,"RoofTie",Vector3(x,3.35,0),Vector3(.12,.18,d-.35),timber,false)
	for side in [-1.0,1.0]:
		b.piece(room,"DampPlinth",Vector3(side*w*.5,.48,0),Vector3(.43,.48,d),lime)
		b.piece(room,"WindowSill",Vector3(side*(w*.5+.08),1.35,0),Vector3(.58,.12,2.3),b.stone)
		for z in [-1.08,1.08]:
			b.piece(room,"WindowJamb",Vector3(side*w*.5,2.0,z),Vector3(.48,1.3,.12),timber)
		b.piece(room,"WindowHead",Vector3(side*w*.5,2.68,0),Vector3(.48,.13,2.3),timber)
		for z in [-1.72,1.72]:
			b.piece(room,"OpenTimberShutter",Vector3(side*(w*.5+.25),2.0,z),Vector3(.10,1.25,1.0),timber,false)
	if str(room.name).contains("Barracks") or str(room.name).contains("Sepoy"):
		prop(room,"res://objects/household/storage/bench.tscn",Vector3(-w*.32,.24,2.1))
		prop(room,"res://objects/household/storage/bucket.tscn",Vector3(w*.4,.24,2.2))
	if room.name=="OfficersQuarters":
		for x in [-8.0,8.0]:
			prop(room,"res://objects/household/storage/stool.tscn",Vector3(x,.24,1.1))
			prop(room,"res://objects/household/supplies/record_folio.tscn",Vector3(x,1.06,-.1))
			prop(room,"res://objects/household/oil_lamp_visual.tscn",Vector3(x+.6,1.06,-.1))
