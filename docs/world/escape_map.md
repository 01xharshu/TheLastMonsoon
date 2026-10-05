# Escape map, game actions and settings

Updated 2026-10-05 IST. Active task: root / Escape map integration.

Escape or controller Options opens a paused map, with three gold SVG icon tabs: map, journey actions, and settings. Escape resumes. Controller shoulders switch tabs; Circle backs out. M and D-pad-left now open the existing identity scroll. The original map raster, authored infrastructure markers and coach destination flow are preserved.

Map: pointer-centred wheel zoom 1–8×, drag pan, click terrain or a site, right-click clear, R reset; left stick pans and vertical right stick zooms. Fifteen site icon families cover houses, ports, military, trade, nature, water, bridges, clinics, churches, stables, jails, civic offices, treasury, cemeteries and parking. The two-column legend and map board use separate responsive areas. Names show on hover/selection; crowded overview markers have count badges, and selecting them zooms to reveal individual destinations. Site collection runs on open; pointer map redraws on interaction rather than continuously. The raster is reused.

Journey actions use real SaveManager slots: save, load, latest save, resume and main-menu confirmation. Settings retain audio/camera/display/controller features and add persisted keyboard remapping with conflict rejection. Graphics presets apply immediately:

| Preset | 3D scale | MSAA | Sun shadow distance | SSAO / SSIL |
|---|---:|---|---:|---|
| Low | 65% | Off | 40 m | Off / Off |
| Medium | 85% | 2× | 80 m | On / Off |
| High | 100% | 4× | 130 m | On / On |

Waypoint: destination coordinates are projected onto real collision support, with landscape fallback. A random location gets a wood-coloured tapered stake with yellow tip; a selected named site gets the yellow beacon without a stake, at its centre/support surface. Distance text is fixed-size and depth-tested, so player/world geometry can occlude it. Within 3 m horizontally it fades for 0.7 seconds and clears. Coordinate and selected-site identity persist in saves; old saves still work.

Files: `ui/game_menu.gd`, `ui/settings_panel.gd`, `player/world_map.gd`, `player/world_waypoint.gd`, `systems/save_manager.gd`, `assets/ui/map_icons/`. One integration parser repair in concurrent `interaction/interaction_overlay.gd` replaced a stale removed distance reference with the existing squared-distance threshold.

Verification commands:

- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/world/validate_escape_map.gd` → `/tmp/tlm_escape_validation_final.log`. Uses disposable save/config paths; verifies actual Escape input, pause/tab/resume, projection/zoom/click, quality effects, binding persistence/conflicts, save/latest slot, destination placement/depth and arrival fade.
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/world/capture_escape_menu.gd` → `/tmp/tlm_escape_capture_final.log`. Lightweight native Metal layout fixture. Captures `docs/world/captures/escape_map.png`, `escape_game.png`, `escape_settings.png`; fixture is explicitly not a populated gameplay capture.

Evidence status (2026-10-05 12:50 IST): **implementation COMPLETE; owner art/physical controller acceptance open**.

- Final full-world headless regression: PASS, no script errors, resource warnings or leaks; `/tmp/tlm_escape_validation_final.log`.
- Native full-world Metal regression: PASS, no fence timeouts/errors; `/tmp/tlm_escape_metal_final.log`. The earlier overloaded run is superseded.
- Native UI fixture: PASS without warnings; `/tmp/tlm_escape_capture_final.log`. Final 15-family legend, themed location picker, tab highlights, footer and settings spacing inspected. Fixture captures are layout evidence, separate from gameplay.
- Full-world marker pixels inspected in `waypoint_grounded.png` and `waypoint_character_occlusion.png`: compact gold serif distance/tip, supported wooden shaft; character obscures the marker at 4 m. Test actor placement uses 0.95 m support clearance; this staged capture is not a locomotion/contact approval.
- Integrated concurrent `world/suryagarh/errands/destination_marker.gd`: onscreen map pins use the depth-tested world marker; offscreen arrows and real errand endpoint guidance remain. This removes the duplicate always-on-top pin discovered in native review.
- Target changes cancel an existing arrival fade, and waypoint teardown releases its tween. Settings panel disconnects controller callbacks on exit.
- `git diff --check` and `python3 tools/check_agent_docs.py`: PASS at completion.

The checks establish functional integration and inspected renderer pixels. They do not establish whole-game FPS improvements, physical DualSense feel, or owner acceptance. Optional next review: normal-speed player route to random road and named building pins, controller USB/Bluetooth navigation, and low-resolution UI feel. No outstanding implementation blocker.

## Wide map and minimap follow-up — COMPLETE
2026-10-05 IST/root. Owner requests wide map + legends only, zoom confined to the fixed map area, a map waypoint pin, and bottom-left minimap. Finder/title/help removed; aspect-correct rectangular projection uses a clipped child canvas. Main-map pin remains shared with depth-tested world waypoint. Bottom-left minimap reuses raster, player heading, site icons and shared waypoint (edge pin for distant targets), updates at 10 Hz and inherits HUD modal hiding. Vitality moved above minimap. Files: player/world_map.gd, map_canvas.gd, minimap.gd, historical_hud.gd; existing facility-picker regression migrated to icon selection. Completed: native clipped zoom/HUD evidence and runtime regression.

Minimap clarified as circular GTA-style radar: centre player arrow, camera-heading-up terrain, circular shader mask, north indicator and yellow waypoint clamped to the rim when distant. Raster sampling and icon positions share the same rotation; refreshed at 10 Hz with no extra world-camera pass. Existing coach travel command moved to the game-actions tab so the map view remains map + legends only. Native full-world follow-up PASS in `/tmp/tlm_map_wide_minimap_native.log`; tested wide aspect/projection, fixed frame across zoom, clipping, shared minimap waypoint/modal lifecycle and arrival clearing. Captures show circular minimap and vitality clearance; yellow-pin update and coach action move included in final capture.

Minimap authored road routes added with segment/circle intersection clipping (including the main curved road); the raster alone does not contain all live roads. Final headless regression PASS, no errors/warnings (`/tmp/tlm_map_wide_minimap_final.log`); native full-world roads/circular minimap capture PASS (`/tmp/tlm_map_wide_minimap_native.log`).

Completed 2026-10-05 13:06 IST/root. Main map is wide and fixed: at a 1280×720 viewport its content area is `(268,100)` / `984×592`. Zoom changes only the contents. `map_canvas.gd` clips terrain/routes/icons/labels. Removed finder, title/help and map travel button; coach travel remains in the game-actions tab. The same gold diamond waypoint appears on the main map and circular minimap, with edge indicators when outside the viewed area. Radar terrain/roads rotate with camera heading, player arrow stays centred, north remains indicated. Site icons and local roads visible; 10 Hz radar updates reuse the existing terrain texture. Vitality/horse stats moved above radar.

Final evidence: `docs/world/captures/escape_map_world.png` shows the wide map and yellow 426 m pin; `waypoint_grounded.png` shows the circular radar with roads, yellow pin and HUD clearance; `waypoint_character_occlusion.png` retains world marker depth evidence. Native renderer and explicitly sized headless fixture pass fixed-frame zoom, world projection aspect, clipped canvas, shared waypoint, minimap visibility after resume, graphics/binding/save compatibility and arrival fade. No physical controller or whole-game FPS claim. Scoped diff check and docs checker pass; full dirty-worktree diff check has unrelated trailing whitespace in `tools/characters/build_village_farmer.py:402`, preserved.

## Nearby-direction minimap — COMPLETE
2026-10-05 IST/root: owner requests a zoomed-in nearby view. Radar diameter reduced from 260 m to 120 m (60 m radius, ~2.17× closer). Nearby roads/sites and heading stay shared; distant waypoints now use a directional arrow on the circular rim, nearby waypoints use a gold diamond. Native gameplay regression PASS without errors/warnings: `/tmp/tlm_minimap_nearby_native.log`. Refreshed `docs/world/captures/waypoint_grounded.png` inspected: only local road bends and nearby stable/parking icons visible; centred player and near yellow pin readable. Distant targets retain direction on the rim.
