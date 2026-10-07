# Obstacle components — 2026-10-01 IST

Four original reusable candidates in `objects/obstacles/`. No world placements, interaction prompts or existing gate behavior changed.

Fence, barricade, cover and gate (test output deleted)

| Scene | Geometry and references | Final animation requirements |
| --- | --- | --- |
| `timber_fence.tscn` | 2 m post spacing, 1.25 m posts, two rails and nine palings. JoinLeft/JoinRight references for adjacent sections. | None for static boundary dressing; climbing, if enabled, needs hand/sole targets, clearance and landing review. |
| `timber_barricade.tscn` | Freestanding 1.95 m planks, upright supports and projecting feet; top about 1.18 m. Left/right handhold references. | Cover entry/exit, lean/peek if enabled; vault requires palm contact, planted takeoff, clearance over protruding feet and grounded landing. Moving it requires lift/carry mechanics and additional grips. |
| `low_masonry_cover.tscn` | Twenty blocks, 2 m wide, 0.46 m deep and 0.915 m tall. CoverLeft/CoverRight/TopContact references. | Crouch/enter/leave, edge peek/aim, obstacle-specific mantle if enabled. Enemy sight/bullet blocking needs gameplay verification separately. |
| `timber_gate.tscn` | Two 1.55 m posts, 1.6 m opening, leaf boards, rear rails, hinge straps and latch. HingePivot holds leaf geometry AND collision. HandleContact moves with it. | Approach, stow weapon, reach latch, unlatch, push/pull with hand following leaf, step clear and release; close/latch if supported. Controller, locking state, saves, sound, cancellation and sweep obstruction remain unimplemented here. |

All roots have Approach markers. Gate swing reference is 0 to -95 degrees; this is a component, not a new operable gate. Individual box colliders follow each solid timber/stone member. Fence gaps remain real gaps; collider tests are at rails/palings rather than asserting a solid sheet. No automatic cover/climb registration is added.

Builder `tools/assets/build_obstacle_batch.gd`; review `tools/assets/review_obstacle_batch.gd`. Headless/native Metal checks PASS for scene loading, visible floor bounds, Approach markers, blocked rays at four solid surfaces, and the same central gate ray clearing after manually rotating HingePivot. Reports `obstacle_validation_headless.json`, `obstacle_validation_metal.json`; captures `obstacle_overview.png` and four individual `obstacle_*.png`. Native overview inspected. This is basic geometry/material evidence; timber grain, ageing/joinery, masonry variation, final art, capsule routes, combat and normal-speed hand/sole contact remain open.

Next: placement/integration audit for these and the earlier unplaced household candidates before expanding more reusable assets. Keep animations last and retain existing world gates/controllers when choosing integration points. Ledges and rubble remain open in batch 4.
