extends RefCounted
## Read actual authored nodes so map markers follow placement changes.
const NAMED := {
 "CustomsWarehouse":"Port Customs Warehouse", "MerchantShip":"Merchant Ship",
 "BhairavpurHouse0":"Arjun and Dev’s Home", "ChachaHouse":"Chacha’s House",
 "LandownerHousehold":"Landowner Residence", "MerchantHousehold":"Merchant Residence", "BritishHousehold":"British Household",
 "CollectorBungalowServiceQuarters":"Collector Service Quarters", "OfficerBungalowServiceQuarters":"Officer Service Quarters",
 "TownHall":"Town Hall", "DistrictPolice":"Police Thana",
 "DistrictJail":"District Jail", "CompanyArmoury":"Company Armoury",
 "ColonialCompound":"Company Compound", "BhairavpurBoatLanding":"Village Boat Landing",
 "MilitaryHospital":"Military Hospital", "MilitarySupplyDepot":"Military Supply Depot",
 "GrainFodderWarehouse":"Grain and Fodder Warehouse", "GunpowderMagazine":"Gunpowder Magazine",
 "CavalryStables":"Cavalry Stables", "BritishBarracks":"British Barracks",
 "OfficersQuarters":"Officers Quarters", "CantonmentChurch":"Anglican Church",
 "MilitaryCemetery":"Military Cemetery", "VillageStable":"Village Horse Stable",
 "BhairavpurVillageWell":"Village Well", "BhairavpurGrainStore":"Village Grain Store",
 "BhairavpurHarvestYard":"Harvest Yard", "GovernmentHouse":"Government House",
 "HooghlyPort":"Hooghly Reach Port", "OldFort":"Ruined Indian Fort",
 "WorldForestPatch":"Forest grove", "ForestShrine":"Forest Shrine", "TimberBridge":"Timber Bridge",
 "Collectorate":"Collectorate", "DistrictTreasury":"District Treasury",
 "BritishCourthouse":"British Courthouse", "CollectorBungalow":"Collector Bungalow",
 "OfficerBungalow":"Officer Bungalow", "CantonmentBazaar":"Cantonment Bazaar",
 "CivilLines":"Civil Lines", "BritishCantonment":"British Cantonment"
}
const GROUPS := ["bhairavpur_structure", "wealthy_household", "civil_lines_service_quarters", "sepoy_barracks"]

static func collect(world: Node) -> Dictionary:
 var sites: Dictionary = {}
 for node in world.find_children("*","Node3D",true,false):
  var label: String = str(node.get_meta("parking_label", NAMED.get(str(node.name),"")))
  if label == "":
   for group in GROUPS:
    if node.is_in_group(group):
     label = str(node.name).capitalize()
     break
  if label != "":
   var at: Vector3 = node.global_position
   sites[label] = Vector2(at.x,at.z)
   # These builders author geometry in world coordinates under an origin root.
   if node.name == "HooghlyPort": sites[label] = preload("res://world/suryagarh/landscape_layout.gd").PORT_CENTER
   if node.name == "ForestShrine": sites[label] = preload("res://world/suryagarh/forest_shrine.gd").CENTRE
 return sites
