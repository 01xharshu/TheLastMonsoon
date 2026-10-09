# Ruined hill fort — playable encounter and realism batch, 2026-10-07

**Status: usable main-world encounter; final art remains open.** `OldFort` is integrated in Suryagarh at `(520,120,-350)`. The playable footprint is 120 × 100 m, with additional peripheral scenery. The shared landscape owns the hillside and access trail; embedded mode adds no duplicate ground layer.

## Implemented

Five zones climb approximately 8 m from approach to keep. A direct route, a longer west flank and an enclosed east flank connect broken rooms, arches and courtyards. The upper supply platform now has a continuous twelve-step ascent; the earlier steps began too high and failed physical traversal.

Architecture uses 5,029 instances of a reusable chipped stone module, plus arch, floor, column and stair pieces. Shared Poly Haven rock textures already recorded in `asset_manifest.json` provide surface variation. Rock faces have irregular silhouettes and grounded bases. Six room remnants contain broken floor slabs and 18 reused crates, sacks, baskets, pots, barrels and benches. Two abandoned goods carts reuse the existing cart construction without horses, riders or vehicle logic. Grass uses 240 clustered tufts in one MultiMesh.

There are 44 deliberately offset cover pieces, including the additional flank cover. Each has ground-level CoverPoint and left/right peek markers. A west wall has eight visible hold rows and a supported wall walk, integrated with the existing player climbing component.

A four-person garrison activates only near the fort. It reuses the existing complete-body MPFB British private and independent locomotion/combat AnimationTrees. Guards use terrain contact, collision-aware navigation, sight checks, cover/peek goals, finite cartridges, delayed fire and melee fallback. Their Enfields use the shared loading contact path, a visible paper cartridge and a smoothly lowered loading pose. Disabled guards leave their guns on the ground. Distant actors stop processing.

Defeat all four guards, lethally or nonlethally, then recover the watchtower chest: six paper cartridges, four pistol balls and 26 rupees. The existing save system's institution-operation contract records guard health, cartridges and defeat state. Its chest persistence also prevents a second reward. No shared player, save-system or human asset files were changed for this batch.

## Checks and honest limits

- Saved embedded navigation: **1,338 polygons**.
- Fort feature checks: **PASS**, 44 ground markers and supported climb landing.
- Actual CharacterBody traversal through all three routes to the upper platform: **PASS** in the focused scene. Sample route lengths approximately 97 m, 152 m and 137 m.
- Real jump/catch/hold transfer/mantle, physical cover entry, blocked/exposed gunfire and finite cartridge timing: **PASS**. Settled measured loading-hand errors below 3 mm; measurements do not establish final finger or cloth approval.
- Garrison trees, lethal/nonlethal clearance, supply reward, duplicate-reward rejection and save restoration: **PASS**.
- Main-world ground/trail/placement/navigation: **PASS**, 62-point entry-to-keep path and access grade 0.2523. The shared cart/settlement null-world failures were repaired by the game-error owner. The fort validator now uses `SaveManager.quit_game()` to drain audio. Its latest rerun exited with **zero errors and zero warnings**. A physics-body quota failure prompted two changes: the fort now constructs noncolliding scenery as Node3D instead of empty StaticBody3D instances, and the game-error owner raised the expanded world capacity from 10,240 to 16,384 bodies in project.godot. The clean rerun used the current combined configuration; the fort reduction alone was not separately proven sufficient.
- Fresh 1280 × 720 Metal/Forward+ main-world overview, central view and guard weapon pose inspected. Inward-facing mesh surfaces caught in the first review were repaired. Test screenshots and logs were deleted; no retained capture is evidence for current approval.

The fort still looks like a developing environment: masonry forms repeat, some arch/prop silhouettes are coarse, vegetation is sparse and the watchtower needs a stronger architectural silhouette. Full normal-speed AI tactics, finger/trigger placement, clothing deformation, measured sightline distributions, owner art acceptance and actual 8 GB hardware performance remain open. Some focused fixtures still report shutdown resource leaks; the main-world validator is now clean. Exit code alone is not final art or motion acceptance.

## Test in-game

1. Start Suryagarh. Use F4 to cycle review locations until **Old fort approach**, or follow the east-bridge road onto the fort trail.
2. Enter through the south gate. Compare the central path with the west and east flanks.
3. Use C for crouch/cover, or H against solid cover. At the west wall near local `(-34,-18)`, face the projecting stones, jump to catch, then press Space for each hold transfer, or hold W + Space, to climb and mantle.
4. Fight or knock out the four guards. Go through the inner fort and climb the keep stairs.
5. Hold E at the supply chest. Save and reload; defeated guards and claimed supplies must remain resolved.

Reusable checks: `python3 tools/world/run_fort_checks.py`; add `--main-world` for landscape integration. The runner uses an OS temporary directory and cleans output on exit. `review_ruined_fort.gd` accepts a caller-owned temporary `TLM_FORT_REVIEW_DIR`; the caller must delete that directory in its finally/exit cleanup.

## Next art batch

Improve damaged arches and tower silhouette, more natural stone size variation and debris piles, shrubs/vines along ruined room bases, close player/guard motion and clothing review, and objective sightline/cover-distance measurements. Keep all changes scoped to the fort and coordinate shared character dependencies with their owners.
