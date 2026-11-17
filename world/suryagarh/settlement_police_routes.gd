extends RefCounted
## Ordinary duty stays on inhabited streets. Pursuit navigation does not use this filter.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const ROUTES = ["village_spine","village_west_lane","village_market_lane","village_north_lane","village_south_lane","village_west_link","civil_lines_avenue","cantonment_bazaar_lane","administrative_approach","cantonment_approach","police_to_compound","government_house_road","town_hall","port_approach","city_college_front_street","city_college_rear_lane","city_east_high_street","city_market_street","city_front_street","city_rear_lane","city_courtyard_lane","city_back_street","city_cross_lane","city_hospital_road"]
static func allows_route(label: String) -> bool:
 return label in ROUTES
static func inhabited(point: Vector2) -> bool:
 for label: String in ROUTES:
  var route: Array = Layout.ROUTES[label]
  for i in route.size()-1:
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,route[i],route[i+1])) < 22.0:return true
 return false
