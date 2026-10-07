# Arjun window traversal — 2026-09-30

Space, the existing jump/climb control, starts a 3.2-second traversal when Arjun faces a nearby registered open window. He reaches the sill, lifts the lead leg, lifts the trailing leg, crosses with his torso lowered beneath the lintel, and descends onto the far-side floor. Palm targets follow the sill; boot targets lift above it before crossing. The sequence uses the selected runtime rig and procedural bone poses rather than an imported window animation.

The eight side openings on Bhairavpur houses 4, 11, 19 and 28 are registered. Entry works from either side. The route requires a clear opening, a supporting floor and room for the standing player at the landing. Closed shutters, grilles and obstructed landings are rejected. The existing wall step climb remains a separate route. `player/window_climb.gd` owns the window path and pose; `ClimbComponent` routes input and the visual layer invokes it.

Evidence: lead leg (test output deleted), trailing leg (test output deleted), and 3.2-second Metal motion preview (test output deleted). The movie advances the actual traversal at fixed 30 Hz and renders every frame in a physical aperture fixture. It is a repeatable motion diagnostic, not player-driven full-world footage.

`tools/characters/validate_arjun_window_climb.tscn` passes both directions, sampled boot/head frame clearance, collision restoration, supported landing, blocked landing and closed shutter rejection. It tests bone clearance; cloth/boot mesh margins and fingers need closer review. `tools/characters/validate_arjun_window_world.tscn` finds all eight windows and accepts all eight entry routes. The world emits the existing missing-skeleton errors for FortCook/FortSteward; those are outside this change. Full-world player camera, continuous stone contact and final animation realism remain open. The temporary character appearance is not approved by this work.

Run the fixture with `-- --movie` to save its 97 rendered frames to `/tmp/tlm_window_frames`; encode at 30 Hz for a normal-duration preview.

## Gate and shutter recovery — 2026-10-07

Side windows with timber shutters now register traversal portals; the physical closed leaves still prevent crossing. Iron grilles remain blocked. Open shutters with E from inside, face the side opening within about one metre, and press Space once to cross; window traversal no longer waits for a second jump at the sill. Rear apertures are smaller and remain outside this traversal registration. Night latches restrict outside entry while permitting inside egress; the schedule closes doors at the closing transition rather than every minute. Dawn unlocks scheduled doors. Blocked opening swings try the opposite direction without disabling collision.

Focused checks: `Godot --headless --path . tools/world/validate_access_recovery.tscn` covers rotated side checks, night egress, morning unlock and alternate opening swing. `Godot --headless --path . tools/characters/validate_arjun_window_climb.tscn` covers collision, landing and hinged-shutter traversal. No test captures or reports retained. Full populated-world camera, moving garment/contact and owner play acceptance remain open.
