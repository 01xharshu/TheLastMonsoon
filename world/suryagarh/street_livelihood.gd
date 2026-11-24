extends RefCounted
## Street destinations are approach points. Authored workplaces control their own staff.

const PROFILES := {
	&"clerk": [&"salaried", &"going_to_office", &"office_stop", 18.0],
	&"porter": [&"day_wage", &"seeking_loading_work", &"waiting_for_hire", 14.0],
	&"laborer": [&"day_wage", &"seeking_day_work", &"waiting_for_hire", 14.0],
	&"vendor": [&"self_employed", &"going_to_market", &"market_stop", 12.0],
	&"domestic_worker": [&"household_service", &"going_to_service", &"service_stop", 16.0],
	&"shopper": [&"unassigned", &"buying_supplies", &"supply_stop", 8.0],
	&"job_seeker": [&"unemployed", &"looking_for_work", &"asking_for_work", 10.0],
	&"visitor": [&"unassigned", &"visiting_neighbourhood", &"visit_stop", 8.0],
}

static func role_for(route: String, index: int) -> StringName:
	match route:
		"administrative_approach", "town_hall":
			return &"clerk" if index % 3 != 2 else &"visitor"
		"government_house_road":
			return &"domestic_worker" if index % 3 != 2 else &"visitor"
		"port_approach":
			return &"porter" if index % 3 != 2 else &"job_seeker"
		"village_market_lane", "city_market_street", "cantonment_bazaar_lane":
			return [&"vendor", &"shopper", &"job_seeker"][posmod(index, 3)]
		"village_spine", "village_west_lane":
			return &"laborer" if index % 3 == 0 else &"visitor"
	return &"visitor"

static func dwell(role: StringName, work_end: bool) -> float:
	return PROFILES[role][3] if work_end else 6.0

static func activity(role: StringName, direction: int, wait: float, closing: bool) -> StringName:
	if direction < 0:
		if closing: return &"returning_after_hours"
		return PROFILES[role][2] if wait > 0 else &"returning_from_destination"
	return &"neighbourhood_stop" if wait > 0 else PROFILES[role][1]
