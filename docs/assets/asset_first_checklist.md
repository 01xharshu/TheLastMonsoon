# Asset-first production checklist

Updated: 2026-10-05 IST. Ordered by manageable production effort, not story chronology. This inventories the checked project files and established vision; no complete chapter-by-chapter story script was found, so it is not a claim that every future story asset is covered. Add concrete story requirements here when supplied.

## Production order

Owner direction (2026-09-30): continue assets first; character animations are done in the final pass. Keep per-asset animation/contact requirements attached to each row. Model-batch completion does not close the corresponding interaction or whole-game task.

## Completion rule

Track **model/material**, **placement/collision**, **gameplay**, **hero animation/contact**, and **normal-speed review** separately. An interactive prop is not finished just because its mesh renders or inventory changes. Decorative objects need no hero animation unless an action is explicitly supported. Do not show a usable prompt for unsupported actions.

For every animated interaction, specify: standing/table/ground approach; weapon stowing; hand grip and object attachment; manipulation; exact pickup/resource-transfer moment; return/stow; cancellation and movement restrictions; missing item/full bag/empty source behavior; save/load during the action. Check visible palms, fingers, feet, pouch/mouth contact, and clipping in normal-speed target-renderer video. Match transfer timing to the visible action and prevent duplicate rewards on cancellation/retry.

## Ordered batches

| Batch | Asset group | Existing state / remaining work | Required animation work |
| --- | --- | --- | --- |
| 1A — candidates built | Roti, tied grain sack, woven mat | Three reusable candidates; see [first-batch evidence](household_batch_01.md). Sack/mat await location integration and owner art review. | Roti pickup → carry → open satchel/store; retrieve → eat → put away. Sack decorative unless handling is added. Mat decorative unless sit/rest is added. |
| 1B — candidates built | Pot, water pouch, lamps | Hollow pot, stitched pouch and brass lamp built; [batch evidence](household_batch_02.md). Pickup/fill/light checks pass; village replacement dressing separate. | Pouch pickup/store; unclip → open → fill at pot → close → reattach; unclip → drink → close → reattach. Lamp lighting/extinguishing requires wick-level hand action; source of ignition must be decided. |
| 1C — reusable scenes built | Crate, bucket, brass pot, basket, stool, bench, barrel | Seven shared scenes now placed; floor normalization and crate collider repaired. [Review/evidence](household_batch_03.md). Art/period/LOD review open. | None for static dressing. Carrying, container opening, pouring, or stool/bench sitting needs its own action if enabled. |
| 2 — visual candidates built | Letters, records, clues, bandages, supply bundles | Four reusable visual prefabs; [paper/supply evidence](household_batch_04.md). Exact clue text, placement and animation topology open; existing medical gameplay retained. | Pick up/store/read/fold paper; apply bandage at body location; collect supplies; grip/hand attachment. |
| 3 — five assembled candidates | Cooking, bedding, market/craft, police desk, armoury sets | Five set candidates: cooking/desk [part A](household_batch_05.md), rest/market supply/armoury shelf [part B](household_batch_06.md). Five craft-tool visuals and two work surfaces now built: [craft evidence](craft_batch_10.md); workshop placement/art/contact open. Weapon-rack refinement remains. Cooking/workstation gameplay not implied by dressing. | Charpai sit/lie/wake exists but authored lie transition open; cooking and crafting need task-specific manipulation if usable. |
| 4 — seven component candidates | Gates, fences, cover, ledges, barricades, rubble | [Fence/barricade/masonry/gate components](obstacle_batch_07.md) placed; [two ledges and rubble](ledge_rubble_batch_09.md) built, unplaced. Collision/Metal checks pass; art/controller/contact review open. | Gate push/pull or unbar; climb/mantle; enter/exit cover, peek and shoot. Match handholds and cover height. |
| 5 | Village houses, courtyards, farms, market, well, stable | Existing expanded village; rejected pond/access removal remains tracked separately. | Door interaction; well drawing/lifting/pouring; any harvesting, animal tending or seated activity requires explicit actions. |
| 6 | Police, Company, civic and Government House interiors | Existing building candidates; finish dressing and routes. | Reuse compatible door/container/seat/weapon-pickup actions; adapt contact to actual dimensions. |
| 7 | Roads, paths, riverbanks, crossings, forest, rest places | Existing landscape/forest/river prototypes; species/art/traversal review open. | Slope walking, swimming, shore entry/exit; shoreline crouch/kneel → retrieve pouch → immerse/fill → close/stow → stand. Pond action uses a supported water source, not river-coordinate detection. |
| 8 | Firearms, talwar, bow, arrows, quiver, spear | Existing models and some functioning combat; materials, mechanics and final hero fit open. | Draw/stow, aim, fire, recoil, reload; sword strikes; bow nock/draw/release; spear handling if enabled. |
| 9 | Horse/tack, boat, carts, carriage | Existing playable candidates; body/seat/motion contact open. | Mount/dismount, rein grip, ride/jump/land, cart boarding/driving; boat board/seat/row and paddle contact. |
| 9A — requested 2026-10-01 | Hooghly cargo ship, quay and sea | Original 51 m three-masted merchant ship, port and estuary integrated; route/Metal validation in progress. [Port evidence](../world/hooghly_port.md). | Walking aboard, deck/cabin exploration, hold stairs and crew berths use locomotion; swimming boundary/shore return checked separately. Large-ship sailing and cargo handling are unsupported. |
| 10 | Fort and forest cave/shrine | Fort isolated blockout; shrine in-world preview failed art review. | Reuse traversal/combat actions, check against each route/handhold; shrine interaction only if specified. |
| 11 | Arjun, village/police residents | Arjun appearance rejected; Indian candidate gait/cloth failed; police review open. | Shared locomotion/action rig; role idles, grounded travel, clothing deformation and all prop contacts. |
| 12 | Dev, Leela, British personnel, other story roles | Dev motion study, Leela anatomy study, British preview actors; story-specific roster incomplete. | Character locomotion, conversation gestures, role tasks and combat where required; Leela placement deferred until later entry defined. |
| 13 | Patrol, search, ambush, escape, defended-position scenarios | Proposed reusable scenario categories; confirm against actual story before expansion. | Enemy alert/search/attack/reload/hit/death, civilian responses, synchronized encounters as needed. AI behavior is separate from animation. |

## Food and water action audit

| Action | Current code behavior | Missing work |
| --- | --- | --- |
| Pick up roti | `objects/roti.gd` adds inventory and deletes world object; generic low reach exists. | Ground and table-height reach, visible roti attachment, finger grip, lift, satchel opening and storage; visible transfer timing. |
| Eat roti | `ConsumableComponent.eat_roti` removes item and restores satiety immediately. | Retrieve, hand/mouth contact, bite/chew or tear/eat, remainder handling, recovery, appropriate reward timing. |
| Pick/store/eat mango | Specialized carried mango and bitten mesh exist in `InteractionPoseComponent`. | Normal-speed contact review; use as a reusable foundation, not proof that roti has animation. |
| Fill from indoor pot | `objects/water_pot.gd` adds water immediately. | Retrieve/unstop pouch, bring pouch to source, credible transfer using a vessel or source-specific pouring method, close/stow. Contact targets at pot opening, pouch neck and grips. |
| Fill at river/pond | River component has timed filling and visual crouch. Pouch follows pelvis in `EquipmentVisuals`. No generic pond implementation verified. | Actual pouch hand attachment and water contact, opening/closing, planted feet/knees, stand recovery; generic water-source support for pond. |
| Drink from pouch | Inventory consumption/hydration behavior exists; direct source drinking is currently disabled. | Visible pouch retrieval, stopper, tilt/mouth contact, swallow, return to belt; prevent duplicate belt/hand copies. |

World placement follow-up: [locations and checks](world_placement_batch_08.md). Earlier household/set candidates and four obstacle components are integrated; art, full routes and final interaction/contact remain open. Craft tool/work-surface candidates are built; workshop integration and weapon-rack refinement remain; ledge/rubble candidates need world placement and contact review. After asset batches, complete the final hero-animation pass, including roti pickup/store/eating, pot and shoreline filling, pouch drinking, and lamp use. Coordinate the accepted hero rig and satchel attachment; keep all pending contacts listed.
