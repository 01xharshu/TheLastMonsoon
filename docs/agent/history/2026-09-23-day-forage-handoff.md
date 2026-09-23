# Current handoff

Updated: 2026-09-23 14:22 IST. Project: The Last Monsoon. Read this file first, then only the focused doc/code named by the task. Detailed former ledger: `docs/agent/history/2026-09-23-pre-compact-handoff.md`. Doc index: `docs/README.md`.

## DOCS / CONTEXT COST — COMPLETE
- Goal: small durable agent entrypoint with proper deeper docs. Replaced 84-line ledger with this 25-line current state; archived full text; added `AGENTS.md`, `docs/README.md`, `tools/check_agent_docs.py`; corrected the prominent stale README status/link.
- Evidence: `python3 tools/check_agent_docs.py` PASS (handoff within 60-line/6000-character budget; index links resolve); `git diff --check` PASS. No blocker. Next: maintain current-state entries only; move completed detail to focused docs/history.

## WORLD — IN_PROGRESS
- Goal: fixed civic/British plots, connected roads, no vegetation/road overlap or floating buildings; then review zoomable map.
- Done: shared plot/route data in `world/suryagarh/landscape_layout.gd`; settlements read plots; terrain shader uses baked road mask; landscape rebaked (144 tiles); 1024² field map generated; map zoom/pan/marker code added. `tools/world/audit_civic_layout.gd` PASS; `docs/world/civic_layout_audit.json`.
- Changed: `world/suryagarh/{landscape_layout.gd,shaders/terrain.gdshader,generated/}`, `world/suryagarh/settlements/settlement_builder.gd`, `tools/world/{bake_landscape.gd,bake_field_map.gd,audit_civic_layout.gd,validate_civic_world.gd}`, `player/world_map.gd`, reports.
- Evidence: `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/validate_civic_world.gd` PASS on Forward+/Metal: four foundations grounded, 96 route contact samples (max 0.043 m mismatch), 2132 trees and 743 rocks with zero plot/road intrusions. `docs/world/civic_world_validation.json`. Headless MultiMesh transform reads collapsed to tile origins, giving false tree reports; use a renderer for this test. Map interaction and fresh pixels are not yet verified.
- Map milestone: `tools/world/validate_field_map.gd` PASS on Forward+/Metal: high-resolution raster, invertible projection, pointer zoom, pan, marker and gameplay input release. Inspected `docs/world/captures/10_map_zoom.png`; hid HUD during map and kept labels within border. Building approach pixels still pending.
- Civic visual milestone: captured `docs/world/captures/11_town_hall_approach.png`, `12_police_approach.png`, `13_compound_gate.png`. Town hall revealed its old straight entrance slab buried mid-route. Replaced with ground-following supported segments and graded a 20 m entry corridor; layout audit PASS with hall ramp maximum 23.7% and 0.06 m minimum surface clearance. Terrain and field map must be rebaked for this latest change.
- Next: rebake, recapture hall, rerun Forward+/Metal live validation; then implement save/load/settings and river water pouch.

## ARJUN / EQUIPMENT — IN_PROGRESS
- Owner chose the improved MPFB candidate for playable Arjun; references are `WorkingAssets/Arjun/references/`. Candidate and authored actions are recoverable in `WorkingAssets/Arjun/candidate/`; runtime `characters/arjun/arjun.glb` was exported but needs live animation/appearance review. Existing Enfield colors were baked to GLB and visually checked; source .blend preserved.
- Runtime H stow/draw, swim forced stow and hold-~ wheel are implemented in `player/arjun_equipment.gd`, `player/weapon_wheel.gd`, `player/arjun_visual.gd`. Sword palm grip remains under correction; last equipment check failed right-hand rifle palm reach (~3 cm). Render/contact/cloth/likeness are not approved.
- Next: use `tools/world/validate_arjun_equipment.gd` and inspect its captures; correct grip and inspect authored walk/sit/prone/swim clips.

## ARJUN TRAVERSAL — IN_PROGRESS
- `player/player_controller.gd` now snaps to walkable ground and tries a clearance-checked 0.38 m step when forward movement is blocked; `player/arjun_visual.gd` adds a brief knee lift on a successful step. This is intended for low stairs and raised road edges. Godot headless load passed; traversal in a rendered stair/road scene is still unverified.
- Existing `player/climb_component.gd` handles tagged masonry via Space. `tools/world/validate_river_climb.gd` passed completion and landing, but measured hand-to-wall target errors of 0.44–0.63 m; visible contact is not approved. Untagged reachable ledges and horse mount/dismount transition animation remain to implement.
- Next: build a focused rendered traversal course with low stairs, sloped road, blocked high ledge and tagged wall; verify forward input/foot contact, then extend climb detection and animate hand contact and horse transitions.

## HORSE / STABLE — IN_PROGRESS
- One horse and village stable spawn near Bhairavpur; F mounts/takes/dismounts, WASD rides, Shift gallops, Space jumps. `tools/world/validate_horse_stable.gd` PASS. Evidence and limitations: `docs/world/horse_stable.md`; Metal capture: `docs/world/captures/18_village_horse_mounted.png`.
- Next: improve anatomy, gait, Arjun contact, period detail, and theft response. Approval pending.

## GAME FLOW — PLANNED
- Order after world audit: save/load/continue + functional settings and title flow; river drinking/filling the carried waist water pouch; then Blake wall-climbing/combat and British/Indian NPC/story systems. These are user priorities, not completed features.

## IDENTITY SCROLL / FAME — IN_PROGRESS
- `O` opens an animated parchment record: name, stamina, weapon, fame, recognition and wound placeholder. Files: `player/{identity_scroll,fame_component,talwar_slash}.gd`.
- Talwar left-click near a checkpoint flag drops cloth and awards +1 once; `award_help()` reserves +4 for a future helping interaction. Soldiers, capture and damage tracking are pending. Recognition thresholds are provisional.
- Flags scaled to 55% with matching collision after owner feedback. Forward+/Metal captures: `docs/world/captures/{17_identity_scroll,18_flag_slash,19_flag_fallen}.png`. `tools/world/validate_identity_scroll.gd` passes state/points/one-shot/scale. Sword tip remains ~1.45 m from rope at scripted impact: blade contact and pose are NOT approved.
- Next: correct blade-to-rope contact and recapture; then add a helping interaction. Source Creative Commons audio with license records when adding sounds.

## DAY / STAMINA / FORAGE — IMPLEMENTED
- One clock/light/environment setup; 600 real seconds per day in both worlds, dynamic sky/fog, 5 stamina/second sprint drain. Facing/occlusion/range-aware E pickup and Shift+E eating; mangoes near Bhairavpur and Satchel eating.
- Evidence: `tools/world/validate_day_survival_forage.gd`, `docs/world/day_survival_forage_validation.json`, `docs/world/captures/forage_{12,18,0,prompt}.png`. Details/limits: `docs/world/day_survival_forage.md`. Functionality and lighting/prompt captures verified; final fruit art and hand-contact animation not approved.
- Next: owner playtest the 10-minute pacing and fruit discovery; adjust tuning from feedback.

## SAFE RESUME
- Worktree has many concurrent dirty assets (including Arjun, boat, Sang, vegetation and generated tiles); inspect exact diffs before editing. No broad reset/clean/stage. Prior charpai integration is complete: `docs/world/charpai_validation.json`.
- Keep this handoff to current state, failures, evidence and exact next action. Move completed history to focused docs; do not append turn-by-turn logs here.
