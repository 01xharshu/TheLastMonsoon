# Documentation index

Start with [current handoff](../CODEX_HANDOFF.md) for what is active, what failed, and the next command. This index points to detail only when a task needs it. The root [README](../README.md) describes the game vision, controls, and long-term roadmap; its roadmap is not a live implementation checklist.

| Work area | Source of truth | Focused evidence |
| --- | --- | --- |
| World plots, grades, river and roads | [landscape layout](../world/suryagarh/landscape_layout.gd) | [civic layout audit](world/civic_layout_audit.json), [live civic validation](world/civic_world_validation.json), [bake report](world/bake_report.json) |
| World construction | [settlement builder](../world/suryagarh/settlements/settlement_builder.gd), [landscape bake](../tools/world/bake_landscape.gd) | [world captures](world/captures/) |
| Field map | [map control](../player/world_map.gd), [map raster bake](../tools/world/bake_field_map.gd) | [map capture](world/captures/08_map.png) — older capture; refresh after map edits |
| Arjun visual and actions | [reference notes](../WorkingAssets/Arjun/references/README.md), [Blender candidate builder](../tools/characters/build_arjun_candidate.py), [animation builder](../tools/characters/animate_arjun_candidate.py) | [candidate manifest](characters/arjun/candidate_manifest.json), [animation manifest](characters/arjun/animation_manifest.json), [renders](characters/arjun/) |
| Arjun equipment | [equipment script](../player/arjun_equipment.gd), [wheel](../player/weapon_wheel.gd) | [equipment validation](characters/arjun/equipment_validation.json) |
| Player/survival | [player controller](../player/player_controller.gd), [inventory](../player/inventory_component.gd), [consumables](../player/consumable_component.gd) | [charpai validation](world/charpai_validation.json), [day/stamina/forage](world/day_survival_forage.md) |

The [2026-09 handoff archive](agent/history/2026-09-23-pre-compact-handoff.md) preserves earlier decisions and commands. Open it only when the current handoff and focused evidence do not answer a historical question.

For a new feature, update the relevant source and focused docs. Keep the handoff to: status, material changes, evidence or failure, and one exact next action. Avoid copying console output or repeating milestones there.
