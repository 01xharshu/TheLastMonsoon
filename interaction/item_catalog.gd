extends RefCounted
## Shared collection names and filled-symbol keys. Unknown future items remain readable.
const ITEMS := {
	"stable_fodder": ["Stable Fodder", "food"],
	"military_mail": ["Sealed Military Mail", "item"],
	"military_consignment": ["Military Supply Consignment", "item"],
	"disputed_account": ["Disputed Account", "item"],
	"court_order": ["Court Order", "item"],
	"revenue_assessment": ["Revenue Assessment", "item"],
	"revenue_clearance": ["Revenue Clearance", "item"],
	"treasury_key": ["Treasury Inspection Key", "item"],
	"lock_tools": ["Lock Tools", "item"],
	"petition_receipt": ["Petition Receipt", "item"],
	"court_receipt": ["Court Registration", "item"],
	"revenue_receipt": ["Revenue Receipt", "item"],
	"paper_cartridges": ["Paper Cartridges", "ammo"],
	"pistol_ball": ["Pistol Balls", "pistol_ammo"],
	"shot_charge": ["Shot Charges", "shot_ammo"],
	"pistol": ["Adams Pistol", "pistol"],
	"enfield": ["Enfield Rifle", "weapon"],
	"double_gun": ["Double-barrel Gun", "double_gun"],
	"talwar": ["Talwar", "sword"],
	"utility_knife": ["Knife", "sword"],
	"spear": ["Spear", "weapon"],
	"smoke_bomb": ["Smoke Pouch", "item"],
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
