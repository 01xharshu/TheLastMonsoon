extends "res://world/suryagarh/settlements/settlement_builder.gd"
## Reuse actual cantonment rooms, beds, aisles and collisions for worker checks.
var complete:=false
func _ready()->void:
	plaster=material(Color(.76,.70,.56));ochre=material(Color(.55,.40,.24));brick=material(Color(.44,.24,.16),true)
	wood=material(Color(.23,.13,.07));tile=material(Color(.43,.19,.105),true);stone=material(Color(.42,.40,.33),true);iron=material(Color(.13,.14,.13))
	var district:=Node3D.new();district.name="BritishCantonment";district.position=Vector3(500,8.5,470);add_child(district)
	var cantonment:=preload("res://world/suryagarh/settlements/cantonment.gd").new()
	cantonment.b=self;cantonment.district=district;cantonment.wall_surface=plaster;cantonment.roof_surface=tile
	var hospital:=cantonment.shell("MilitaryHospital",Vector3(-43,0,45),Vector2(24,10),"")
	for x in [-9,-3,3,9]:
		for z in [-2,2]:cantonment.bed(hospital,Vector3(x,.24,z),true)
	for label in ["GrainFodderWarehouse","CavalryStables","CantonmentChurch","MilitaryCemetery"]:
		var room:=Node3D.new();room.name=label;district.add_child(room)
	preload("res://world/suryagarh/settlements/cantonment_rooms.gd").install(self,district)
	preload("res://world/suryagarh/settlements/cantonment_service_detail.gd").furnish(self,district)
	var orderly:=preload("res://characters/npcs/households/household_npc_actor.gd").new()
	orderly.name="HospitalReceivingOrderly";orderly.movement_enabled=false
	orderly.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb",false))
	get_parent().add_child(orderly);orderly.global_position=hospital.to_global(Vector3(0,0,7))
	complete=true
