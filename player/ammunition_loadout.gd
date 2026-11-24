extends RefCounted
## Reserve ammunition; chamber capacities remain tied to each firearm mechanism.
const RESERVES := {"enfield": ["paper_cartridges", 24], "pistol": ["pistol_ball", 30], "indian_pistol": ["pistol_ball", 12], "double_gun": ["shot_charge", 16], "bow": ["arrow", 24]}

static func grant_for_weapon(actor: CharacterBody3D, weapon_id: String) -> void:
	if not RESERVES.has(weapon_id): return
	var reserve: Array = RESERVES[weapon_id]
	actor.inventory.add_item(reserve[0], reserve[1])
	var component: Node = actor.get_node_or_null({"enfield":"RifleCombat", "pistol":"PistolCombat", "indian_pistol":"IndianPistolCombat", "double_gun":"DoubleGunCombat"}.get(weapon_id, "Missing"))
	if component == null: return
	component.rounds = 5 if weapon_id == "pistol" else (2 if weapon_id == "double_gun" else 1)
	if weapon_id not in ["pistol", "indian_pistol"]: component.loaded = true
