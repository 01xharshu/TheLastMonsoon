# Rural field grazing

Small mixed herds graze in uncultivated pasture beside the western farmland. Three meadow centres near **(-690,185)**, **(-690,285)** and **(-600,365)** each receive two cows and one horse when the physical plot is clear. The household cow, cavalry horses and working draft teams retain their existing owners. No modern fencing, trough or street furniture is added.

`world/suryagarh/settlements/field_grazing.gd` installs after the existing terrain/nature setup in normal world startup. It finds supported, gently sloping positions outside cropped plots, houses, service lanes and public roads, then amortises animal creation across physics frames. The saved terrain collision supplies heights, with a bounded world-local sample cache. Existing animal meshes and Blender sources are reused unchanged.

`animals/field_grazer.gd` extends the existing draft-animal owner: unique identities, health/corpses, leading and hitching remain integrated. Free animals alternate grazing, looking up and short walks between feeding patches. The cow uses the existing breathing, jaw and four-leg solver; the horse uses its existing idle/walk clips with a blended neck/head grazing solve. Swept collision and destination checks retain fences, scenery and other actors. Shared simulation-budget tiers accumulate elapsed time for distant animals and restore full update cadence on approach. The original source meshes and culling remain in use. This mechanism is not a measured whole-world FPS claim.

The existing `DraftAnimalYards` save registry discovers these animals by identity and saves health, position and heading. An optional grazing record also retains feeding/walking state, remaining duration and validated next patch; other draft animals keep their existing record format. Old saves omit them and receive the default herd. Leading and draft-team ownership take priority over autonomous grazing.

Reusable checks (temporary project, private settings/saves and automatic output cleanup):

- `python3 tools/world/run_tutorial_guard_check.py --checks validate_field_grazing`
- `TLM_GRAZING_WORLD=1 python3 tools/world/run_tutorial_guard_check.py --native --review --checks validate_field_grazing`

The focused test checks nine unique animals, terrain and road/crop reservations, both behaviour cycles, physical patch travel, finite poses, muzzle contact, grazing-state round trips and swept movement against a solid barrier at remote update cadence. Full-world mode also checks normal startup and herd save registration. Native appearance and test outcomes are recorded in `CODEX_HANDOFF.md`; sampled checks do not establish sustained whole-world motion, all terrain cases or final animal art approval.
