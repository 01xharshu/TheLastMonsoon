# Living world requirements — 2026-10-05

User direction: improve greenery, grass, inhabited interiors, field escape, police patrols, transport and revolutionary support while keeping the whole game affordable to render and simulate. Requirements were sent directly to the eight existing owner chats below; delivery is confirmed, implementation and acceptance remain open. Continue existing work and incorporate additions rather than discard current tasks.

| Scope | Owner chat | Acceptance still required |
| --- | --- | --- |
| Village trees, crops and field edges | Refine Bhairavpur household kits | Region/season-specific planting evidence; believable canopy and cultivated plots; clear walking, cart and escape routes |
| Grass rendering | Improve terrain, roads, and barracks | Upright varied blade clumps, grounded roots and convincing near-camera silhouettes; rendered before/after and measured cost |
| Household rooms and occupancy | Improve house access and build fort | Purpose-specific rooms, doorways, circulation and staff routines; avoid universal hall layouts |
| Institutional rooms and workers | Add realistic cantonment buildings | Building-specific divisions, furnishings, workplace occupancy and accessible routes |
| Field stealth movement | Fix Arjun’s movement animations | Crouch/prone locomotion and transitions back to running; coordinate stance-dependent concealment with field and detection owners |
| Patrols and revolutionary assistance | Add fight-triggered music and police | Historically sourced torch searches and mounted patrol roles; nearby allies join Arjun against hostile police/sepoys, can die, and depart after combat |
| Police body variety | Create British NPCs | Believable adult height/build variants with fitted uniforms; coordinate civilian police ownership |
| Location travel | Speed up horse-drawn vehicles | Preserve usable cart/carriage travel and boarding/routes; clarify literal motor-car request before implementing it |

## Historical and story gates

The repository setting is fictional Suryagarh in 1857. Greener environments should follow regional ecology, water, season and land use, not blanket every area in the same vegetation. Owners must record dated/local evidence under `historical_accuracy.md`; this document records user intent, not researched historical approval.

The user clarified that the requested future field escape concerns **Tatya Tope**. Identity is confirmed; the exact date, route and episode still need research and story alignment. Establish reusable traversable crop cover now without inventing the sequence. Cover should account for crop height/density, posture, distance and sight lines, not grant invisibility merely for entering a field.

“Car” is provisionally interpreted as cart/horse carriage travel in the existing setting. A literal motor car requires resolving the timeline first.

All human variants and new workers must use MakeHuman/MPFB, retain complete bodies beneath clothing and separate opaque foundations, and receive clothing/contact review. Building identification must follow the existing no-visible-building-text rule.

## Performance and review

Use shared vegetation meshes/materials and spatial MultiMesh batches; budget near detail and distant visibility/LOD. Preserve paths, building clearances and farm bunds; avoid per-blade nodes or physics. Bound active workers, patrols and recruited allies by distance and participant caps; use cheaper distant simulation. Torch lighting/shadows require a simultaneous light budget. Interior detail and occupants require distance/visibility management that preserves state.

Record actual viewport pixels, hardware, source snapshot, frame p50/p95, draw calls, node/active actor counts and memory for matching village, field, interior and night-combat routes. Existing `runtime_optimisation.md` reports serious unresolved whole-world cost; subsystem improvements do not establish a whole-game performance pass. Do not increase density without profiling.

Capture actual rendered grass/field/interior/night scenes and playable crouch/prone escape and ally combat. Structural checks do not approve appearance, motion, contact, historical fit or frame budget. Keep current useful captures and editable sources; replace superseded evidence following AGENTS.md.

Next: owned implementations and integration, then integrated route/render/performance review. No feature is marked complete by message delivery. Routine acknowledgments and status requests are unnecessary.

## Main-checkout integration audit — 2026-10-05

The greenery chat verified the main-checkout crop-concealment contract with Godot 4.7.2: `tools/world/validate_crop_concealment.gd` exited 0 and reported posture, bounds, close sight, elevation, edge and sparse-low-plant checks PASS. This does not establish rendered field escape or final motion approval.

The main `tools/world/bake_landscape.gd` still supplies baked grass from the imported Bermuda mesh. The terrain owner's `d388` worktree instead contains authored `grass_blades.gd`, separate core/detail batches and a grass-only refresh. Its focused `ground_garrison.md` and grass implementation are absent from main at audit time. The terrain owner received this specific integration dependency, including the need to preserve concurrent landscape work and use a compatible grass-only refresh rather than replace the world from an older snapshot. Greenery coordination does not take over those owned implementation files.

Acceptance remains open until the authored grass is integrated into the playable main checkout and fresh rendered field/grass evidence plus measured cost are retained there. The original leaf-like-grass complaint is not resolved by an unintegrated worktree implementation.

## Follow-up work explicitly requested — 2026-10-05

Owner messages delivered for the six remaining areas; implementation/review remains open:

- Terrain: **Improve terrain, roads, and barracks** — seams, steep cuts, slopes, vegetation/ground contact and rendering cost.
- Stairs: **Improve Arjun stair climbing** — actual-controller ascent/descent, landing support, foot/camera clearance; coordinate controller edits with the movement owner.
- Continuous horse turning: **Speed up horse-drawn vehicles** — sustained steering, reversals and corners with consistent horse/cart/rider/rein motion; ordinary input and paid routes, continuous 1x evidence.
- Final uniforms: **Create British NPCs** and **Create Arjun’s sepoy brother** — period fit, varied bodies, cloth seams/clipping and gear contact across motion, with full MPFB bodies/foundations retained.
- Torch patrols: **Add fight-triggered music and police** — carried-torch contact, day/night activation, walking/mounted search, bounded lighting/shadows and active patrol simulation.
- Voices: **Add fight-triggered music and police** — audit approved recordings/pipeline; contextual patrol/search/combat triggers, subtitles, distance, concurrency and cooldown controls. Missing final voice recordings must remain explicitly open; placeholder sounds do not satisfy final voice approval.
