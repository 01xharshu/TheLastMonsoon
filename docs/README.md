# Documentation index

Start with [current handoff](../CODEX_HANDOFF.md) for what is active, what failed, and the next command. This index points to detail only when a task needs it. The root [README](../README.md) describes the game vision, controls, and long-term roadmap; its roadmap is not a live implementation checklist.

| Work area | Source of truth | Focused evidence |
| --- | --- | --- |
| River, boat, fish and climb status | [focused status](world/river_boat_climb_status.md) | [live captures](world/captures/14_river_boat_water.png), [underwater fish](world/captures/14b_fish_underwater.png) |
| World plots, grades, river and roads | [landscape layout](../world/suryagarh/landscape_layout.gd) | [civic layout audit](world/civic_layout_audit.json), [live civic validation](world/civic_world_validation.json), [bake report](world/bake_report.json) |
| Government House estate | [period/design note](world/government_house.md), [building module](../world/suryagarh/settlements/government_house.gd) | [fixed-site audit](world/civic_layout_audit.json); rendered/traversal approval pending |
| Civic interiors and sidearms | [civic building](../world/suryagarh/settlements/civic_building.gd), [period details](../world/suryagarh/settlements/civic_details.gd) | [historical and licence review](world/historical_accuracy.md), [material hashes](world/civic_materials.json), [interior test](../tools/world/validate_civic_interiors.gd) |
| World construction | [settlement builder](../world/suryagarh/settlements/settlement_builder.gd), [landscape bake](../tools/world/bake_landscape.gd) | [world captures](world/captures/) |
| Field map | [map control](../player/world_map.gd), [map raster bake](../tools/world/bake_field_map.gd) | [map capture](world/captures/08_map.png) — older capture; refresh after map edits |
| Arjun visual and actions | [reference notes](../WorkingAssets/Arjun/references/README.md), [rejected runtime appearance](characters/arjun/rejection_2026-09-23.md), [Blender candidate builder](../tools/characters/build_arjun_candidate.py), [animation builder](../tools/characters/animate_arjun_candidate.py) | [candidate manifest](characters/arjun/candidate_manifest.json), [animation manifest](characters/arjun/animation_manifest.json), [renders](characters/arjun/) |
| Arjun equipment | [equipment script](../player/arjun_equipment.gd), [wheel](../player/weapon_wheel.gd), [weapon set status](characters/arjun/weapon_set_status.md) | [weapon set review](characters/arjun/weapon_set_review_2026-09-23.png); [older equipment validation](characters/arjun/equipment_validation.json) uses rejected appearance |
| British NPC visual direction | [rank and companion notes](characters/british/README.md) | Eight [multiview pair sheets](characters/british/references/); [private pair 3D blockout](characters/british/candidates/private_pair_front.png) is unapproved and not runtime ready |
| Indian village NPC pair | [period basis and candidate status](characters/npcs/indian_peasant_pair.md) | [first in-world Metal capture](characters/npcs/indian_peasant_pair_world.png); static cloth blockouts, visual review failed |
| Period evidence and placement rule | [historical accuracy](world/historical_accuracy.md) | [weapon store validation](../tools/world/validate_weapon_store.gd) |
| Animal tools and DualSense | [tool and controller status](world/animal_tools_and_controller.md) | [controller mapping check](../tools/world/validate_controller_map.gd); physical device review pending |
| Player/survival | [player controller](../player/player_controller.gd), [inventory](../player/inventory_component.gd), [consumables](../player/consumable_component.gd) | [charpai validation](world/charpai_validation.json), [day/stamina/forage](world/day_survival_forage.md) |
| Save, title and pause menus | [save manager](../systems/save_manager.gd), [menus](../ui/) | [state round-trip](world/save_flow_validation.json), [menu navigation](world/menu_navigation_validation.json) |
| River drinking and pouch fill | [river component](../player/river_water_component.gd) | [live validation](world/river_water_validation.json), [pose capture](world/captures/20_river_drink.png) |

The [2026-09 handoff archive](agent/history/2026-09-23-pre-compact-handoff.md) preserves earlier decisions and commands. Open it only when the current handoff and focused evidence do not answer a historical question.

For a new feature, update the relevant source and focused docs. Keep the handoff to: status, material changes, evidence or failure, and one exact next action. Avoid copying console output or repeating milestones there.
