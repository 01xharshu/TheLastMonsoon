# Civil Lines and cantonment service bazaar

Updated 2026-10-01 IST. Task /root, IN_PROGRESS.

Objective: integrate the four requested settlement functions: spacious Civil Lines separated from the dense Indian town, Collector and officer bungalows, existing Government House retained as major regional residence, and an Indian service bazaar beside the cantonment. Preserve existing household routes, Government House and concurrent building approach edits. No building text.

Completed: inspected current handoff, status, settlement builder, surveyed plots, administrative district and regional baker. Existing Government House and British household confirmed; undeveloped Civil Lines and missing bazaar confirmed from location tracker.

Next: author new construction, survey and regional bake; validate terrain support and actual player collider access; capture and inspect Metal views. Staffing, daily routines, economy and final historical/art acceptance remain outside construction approval.

Construction authored: `world/suryagarh/settlements/civil_lines.gd`, integrated by `settlement_builder.gd`. Survey/roads/map markers in `landscape_layout.gd`. Civil Lines at (680,245), grade 10, 190 × 130 m; Collector (640,235), officer (720,235), separate gardens, open carriage gates, rear service quarters. Bazaar (640,470), grade 8.5, six service stalls around a ten-metre aisle, cart standing and tether rail. Government House and British household retained. Incremental `tools/world/bake_civil_lines_region.gd` authored to rebuild nine affected tiles and clear vegetation only around new plots/routes. Next: native regional bake and live validation.

Native regional bake PASS: nine tiles (tx 9–11, tz 7–9), 8,208 nature instances cleared. `world/suryagarh/generated/landscape.scn`, nine tile resources, road mask and terrain material updated. Command: `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/bake_civil_lines_region.gd` (log `/tmp/civil_lines_bake.log`). Initial baker parse errors repaired before successful run; exit warns one leaked ObjectDB instance. Next: `validate_civil_lines.gd` live entrance/route/terrain checks and Metal views.

Validation refinement: bazaar customer positions stop in front of physical counters; counters are intentional obstacles. The cart spur turns around the eastern stall row rather than passing through the Farrier stall. A rerun will check the corrected service route and regenerated road mask.

First native validation: 13 of 14 walks PASS; only old bazaar spur failed at the Farrier counter (639.89,9.56,487.40). All 193 resident terrain samples PASS. Three Metal captures inspected: spatial separation and roofs visible, but ridge cut is visually steep and garden beds sparse; final landscaping/historical art remain open. Bazaar added simple service cues (grain sacks, folded cloth, cook hearth, leather work, farrier anvil). Next: rebake corrected eastern spur and rerun all walks/captures.

Corrected spur rebake PASS; no additional vegetation clearance required. `git diff --check` PASS. Documentation gate currently FAIL: shared handoff 64 lines/6613 characters exceeds 60/6000; other active task sections preserved. Next: final live validator, evidence review and location tracker update.

User steering: some trees float; add more trees. Scope extended to saved-world tree root grounding against resident terrain colliders and more trees, especially district gardens and lane edges. Next: measure existing mesh foot gaps before modifying tree transforms; preserve non-tree nature and existing access.

Corrected native validation PASS: 14 player collider walks, 208 saved-terrain support samples, zero failures; three captures saved. User further requests realism for interiors and exteriors. Next: finish saved-world tree grounding/planting, then bungalow joinery/interior furnishings and market fabric/trade detail; fresh player-height interior/exterior views and route regression.

Tree bake PASS: 1,823 existing trees checked against resident physics terrain; 634 transforms corrected; maximum positive pre-repair foot gap 1.358 m; 227 new trees (27 district shade trees and 200 additional grove trees), corresponding trunk colliders added/shifted. Command: `--script res://tools/world/ground_and_plant_trees.gd`, log `/tmp/tree_grounding.log`, report `tree_grounding_validation.json`. Save to `generated/landscape.scn`. Initial type-inference parse errors repaired. Post-save verification pending.

Realism construction authored: textured wood/mineral plaster with restrained surface normals; actual side window apertures and paired physical shutters; framed paired entrance doors, floorboards/skirting, bedroom partition with doorway, office/reception chairs, folio/oil lamp, water and brass vessels, sleeping mat/pillow/cover, veranda chair. Dynamic doors excluded from visual merging. Next: verify all routes, post-save tree roots and new player-height interior/exterior Metal captures.

Seven native views inspected. Corrected two visible realism defects from these views: interior roof tile underside replaced by an opaque lime ceiling with timber tie beams; framed wall pieces moved off rear window apertures onto solid front masonry. Desk chairs turned toward work surfaces. New roof material removes the oversized brick-course pattern. Next: recapture/route regression after these corrections.
