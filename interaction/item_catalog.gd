extends RefCounted
## Shared collection names and filled-symbol keys. Unknown future items remain readable.
const ITEMS := {
	"paper_cartridges": ["Paper Cartridges", "ammo"],
	"pistol_ball": ["Pistol Balls", "pistol_ammo"],
	"shot_charge": ["Shot Charges", "shot_ammo"],
	"pistol": ["Adams Pistol", "pistol"],
	"enfield": ["Enfield Rifle", "weapon"],
	"double_gun": ["Double-barrel Gun", "double_gun"],
	"talwar": ["Talwar", "sword"],
	"bow": ["Bow", "bow"],
	"arrow": ["Arrows", "arrow"],
	"water_bag": ["Water Bag", "water"],
	"mango": ["Mango", "mango"],
	"roti": ["Roti", "food"],
	"rupees": ["Rupees", "coin"],
	"medkit": ["Bandage", "medicine"],
	"bandage": ["Bandage", "medicine"],
}

static func display_name(item_id: String) -> String:
	return str(ITEMS[item_id][0]) if ITEMS.has(item_id) else item_id.capitalize()

static func icon(item_id: String) -> String:
	return str(ITEMS[item_id][1]) if ITEMS.has(item_id) else "item"
