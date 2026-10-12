extends Node
## District membership follows surveyed footprints. Scene paths and save owners stay stable.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const DISTRICTS := {
	"village": ["Bhairavpur", "BhairavpurEstate"],
	"city": ["UrbanWest", "TownHall"],
	"government": ["GovernmentHouse"],
	"police": ["DistrictPolice"],
	"administration": ["AdministrativeDistrict"],
	"company": ["CompanyCompound"],
	"civil_lines": ["CivilLines"],
	"cantonment": ["BritishCantonment", "CantonmentBazaar"],
	"port": ["HooghlyPort"],
	"fort": ["OldFort"],
}
var active_district := "countryside"
var age := 0.0

static func district_at(at: Vector3) -> String:
	var point := Vector2(at.x, at.z)
	for identity: String in DISTRICTS:
		for plot_name: String in DISTRICTS[identity]:
			var plot: Dictionary = Layout.PLOTS[plot_name]
			if Rect2(plot.center - plot.half, plot.half * 2.0).has_point(point):
				return identity
	return "countryside"

static func road_district(road: String) -> String:
	if road.begins_with("village_"): return "village"
	if road.begins_with("city_") or road in ["merchant_city_drive", "town_hall"]: return "city"
	if road.begins_with("government_"): return "government"
	if road.begins_with("civil_") or road.ends_with("bungalow_drive"): return "civil_lines"
	if road.begins_with("cantonment_"): return "cantonment"
	if road.begins_with("administrative_"): return "administration"
	if road.begins_with("compound_"): return "company"
	if road.begins_with("port_"): return "port"
	if road.begins_with("fort_"): return "fort"
	return "travel"

func _ready() -> void:
	name = "WorldDistricts"
	get_parent().set_meta("world_districts", self)
	for identity: String in DISTRICTS:
		var district := Node.new()
		district.name = identity.to_pascal_case()
		district.set_meta("surveyed_plots", DISTRICTS[identity])
		var roads: Array[String] = []
		for road: String in Layout.ROUTES:
			if road_district(road) == identity: roads.append(road)
		district.set_meta("roads", roads)
		add_child(district)

func _process(delta: float) -> void:
	age += delta
	if age < 0.2: return
	age = 0.0
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera): active_district = district_at(camera.global_position)
