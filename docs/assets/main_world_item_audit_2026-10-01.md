# Main-world item integration audit — 2026-10-01 IST

**Placement follow-up:** the previously absent props are now integrated; see [locations, behavior and checks](world_placement_batch_08.md). The JSON inventory has been refreshed. The missing-instance tables below describe the earlier snapshot, not current absence.

Scope: current asset-first checklist and household batches 01–06, compared with a fresh instantiated `world/suryagarh/suryagarh_world.tscn`. Runtime report: [instance inventory](main_world_item_audit_2026-10-01.json). Audit tool: `tools/world/audit_main_world_item_integration.gd`; explicit MAIN WORLD ITEM AUDIT PASS in `/tmp/tlm_item_audit.log`. This checks scene/script presence, not appearance, contact, player reachability, source authenticity or final performance. Existing procedural equivalents are distinct from new prefab integration.

## Built but absent as main-world instances

| Asset | Evidence / remaining integration |
| --- | --- |
| Grain sack | `objects/household/grain_sack.tscn`: 0. Existing market sacks are older geometry; new candidate not substituted. |
| Woven mat | `objects/household/woven_mat.tscn`: 0. Older gathering/rest dressing can remain; new candidate not placed. |
| Folded letter | 0. Needs location, authored text/meaning, and read/collect behavior if intended. |
| Record folio | 0. Needs records-desk/office placement and content; reading/page-turn is unsupported. |
| Supply parcel | 0. Needs location and assigned contents; sealed visual alone is not loot. |
| Bandage-roll prefab | 0 of reusable supplies prefab. Two separate scripted medical supplies already exist; bandage gameplay is present. Replace/reuse visuals without adding duplicate rewards. |
| Cooking-corner set | 0. Some homes/fort have procedural kitchens; this new assembly has not been placed. Cooking gameplay remains absent. |
| Records-desk set | 0. Existing police/home desks do not instantiate this new paper/lamp assembly. |
| Rest-corner set | 0. Existing scripted charpai remains (1); new mat/stool/lamp arrangement not integrated. |
| Market-supply set | 0. Existing village markets remain; this new counter/parcel/stock assembly is absent. Trading is not implemented by the set. |
| Armoury-supply set | 0. Existing weapons/ammunition/medical pickups remain; new shelving arrangement is absent. |
| Roti pickup | `objects/roti.tscn`: 0, and no `objects/roti.gd` world node. Mesh/pickup/consumption code exist, but no placed world roti pickup. |
| Loose water-bag pickup | `objects/water_bag.tscn`: 0. Player carries 1 visual pouch and receives its starting bag; collectible loose bag placement is absent. |
| Indoor interactive water-pot wrapper | `objects/water_pot.tscn`: 0. Three pot visuals are present, and one water-pot script is the existing village well. Decorative pot presence does not establish indoor fill gameplay. |

## Present in this snapshot

| Asset | Main-world count / caveat |
| --- | --- |
| Crate / bucket / brass pot / basket | 10 / 2 / 18 / 9 shared storage instances. Static dressing, not automatic container/carry gameplay. |
| Stool / bench / barrel | 3 / 2 / 7 shared instances. Static dressing; seat behavior not implied. |
| Oil lamps | 34 wrapper/visual instances, switching scripts present. Final lighting/hand animation review remains separate. |
| Water pouch | 1 shared carried visual. No loose pickup instances. |
| Water-pot visuals | 3. Indoor interactive wrapper absent. |
| Medical pickups | 2 scripted building bandages. Healing/inventory/save exist; reusable visual substitution, animation/contact and NPC corpse loot remain open. |
| Charpai | 1 scripted rest object. New rest-set instance absent; sleep transition contact still open. |
| Weapon pickups | 11 scripted pickup nodes. Does not imply every requested weapon is usable. |

## Broader checklist gaps

- Craft tools and complete weapon-rack set are still marked unfinished in batch 3; some carpenter/weaver furniture and existing racks are procedural equivalents.
- Reusable fence, barricade, cover, gate/ledge and rubble components are the next asset batch; existing gate/climb/fort prototypes do not complete it.
- Spear model exists under `environment/weapons/period_spear`, but no world/player source reference was found; placement/equipment/combat integration is missing.
- Dev placement and Leela model/rig/placement remain open; Indian NPC candidates have failed motion review. Existing British/police actors are placed, with independent costume/contact work still open.
- Patrol/search/ambush scenarios are proposed categories, not a completed authored mission set. Cargo ship/port is newly integrated but traversal/swim validation is still in progress per its focused handoff.
- Asset use animations, transfer timing, hero grip/contact, material/period approval and 8 GB performance review remain separate gates. No scene count closes those gates.

Suggested next placement pass: grain sack/mat and existing roti/water-bag pickups; indoor pot functionality; papers with explicit content/behavior; then integrate assembled sets with route/support checks, preserving existing charpai, lamps, ammo and bandage behavior. Do not add invented clue text or automatic parcel rewards.
