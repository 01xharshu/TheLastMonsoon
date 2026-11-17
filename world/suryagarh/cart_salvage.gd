extends RefCounted

const GOODS := {
	"salvaged_brass": {"label": "Brass fittings", "price": 5},
	"salvaged_cloth": {"label": "Cotton bundle", "price": 3},
}
const LABELS := {"rupees": "rupees", "roti": "roti", "mango": "mango", "bandage": "bandage"}
const CACHES := [
	{"rupees": Vector2i(2, 7)},
	{"roti": Vector2i(1, 2), "mango": Vector2i(1, 2)},
	{"salvaged_brass": Vector2i(1, 1)},
	{"salvaged_cloth": Vector2i(1, 2)},
	{"bandage": Vector2i(1, 2), "rupees": Vector2i(1, 3)},
]

static func label(item: String) -> String:
	if GOODS.has(item): return GOODS[item].label
	return LABELS.get(item, item)

static func available_good(inventory: InventoryComponent) -> String:
	for item: String in GOODS:
		if inventory.get_item_count(item) > 0: return item
	return ""

static func roll(random: RandomNumberGenerator) -> Dictionary:
	var profile: Dictionary = CACHES[random.randi_range(0, CACHES.size() - 1)]
	var found := {}
	for item: String in profile:
		var amount: Vector2i = profile[item]
		found[item] = random.randi_range(amount.x, amount.y)
	return found
