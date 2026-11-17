# Mangal's hideout environment

The hideout is the existing `RebelUndercroft` beside the ruined fort, owned by `story/rebellion_sites.gd`. Its descending passage, central follow route, briefing, weapon inspection, firing target and delivery bay continue to use the original mission owners. `story/rebel_hideout_environment.gd` adds the physical and visual environment around them: textured stone and earth, terrain-conforming solid berms, a framed entrance, terrace and terrain-rooted edge supports, bounded roof vegetation, timber supports, planning and sleeping areas, supply shelves and crates, reused household props, and shielded warm lights. The embedded fort's patrol-exclusion and supply chest behavior remain independent.

Validation: `python3 tools/world/run_tutorial_guard_check.py --checks validate_rebellion_story` exercises the real player on the descent, practice and story/save flow. `python3 tools/world/run_hideout_secrecy.py` covers actual-world New/Continue, authority exclusion and standalone fort behavior. `python3 tools/world/run_tutorial_guard_check.py --native --review --checks validate_hideout_environment` renders temporary entrance/passage/interior views in the populated world; the review runner removes its output after `hideout_done` is written in the displayed temporary directory or its review deadline expires.

The angular underlying ruin and undercroft remain the current authored environment; the native frames support only the inspected views. User-controlled approach, full story playthrough, moving character/clothing contact, lighting at other times and final visual approval remain open.

The populated-world `review_rebellion_world` run also passed the rescue, physical follow to the undercroft, briefing and target-practice path. The final roof-vegetation native capture produced usable views but reported a Metal fence timeout; an uncontended repeat is required.

## Private fort courtyard and travel disguise

The main-world fort is reserved for the player and the rebellion story. Ordinary population counterparts skip the fort approach routes, legacy positions inside the private zone are repaired, and routine authority movement and pursuit stop outside the fort. The rescue approach remains outside that boundary. The separate standalone fort still owns its original garrison encounter.

The first rifle lesson uses the open central courtyard. Arjun collects the Enfield in the undercroft, then follows the objective to the outdoor firing line and completes the same two-hit lesson. The yard has a stone backstop, flanking arch openings, room partitions, surviving timber roof fragments and supply caches. The western curtain breach stays clear of the relocated abandoned crate. An existing lookout assignment uses the surviving keep platform.

Mangal and his story crew use a head-bound cloth scarf when riding. The seated briefing uses an uncovered face, a timber chair and a restrained hand gesture. Mangal's presentation uses the complete existing rebel MPFB donor with its moustache and a warmer leader headwrap. The public image referred to for this direction is a later commemoration. [National Book Trust account](https://www.nbtindia.gov.in/writereaddata/attachment/thursday-july-28-202211-44-46-ammay-july-2022.pdf)

The new wall faces use a static batch with exposed stone courses and eroded plaster. Native review covered the courtyard, seated briefing and masked cart travel. A small scarf glint and possible knee cloth contact remain visible in close views. Dedicated facial structure and expression work remain open. Exact validation and cleanup are recorded in the project handoff.

## Arrival through the outer gate

The mountain access road now ends at a broken outer curtain and a deep gatehouse, with weathered timber leaves held open against its passage. The stone return just inside blocks the direct view from the road into the occupied courtyard and undercroft approach. A westward turn reveals the inner ruins. The service descent stays behind the curtain and its masonry cheeks.

The rescue arrival brings the coach to the road side. From there the player follows Mangal through the gate on foot, turns around the screen, and reaches the existing undercroft passage. A cinematic skip uses the same exterior arrival point. Older saves already partway down the passage retain their corresponding follow step. The standalone fort keeps its original entrance.

Run `python3 tools/world/run_tutorial_guard_check.py --checks validate_fort_entry review_rebellion_world validate_remote_mountain_world` for the gate sightline, actual Arjun walking route, complete story follow and mountain route regression. The optional `--native --review --checks validate_fort_entry` captures the road approach, threshold and interior turn in a disposable directory.

## Inner wards and galleries

The outer gate leads to a screened forecourt. The western route to the undercroft now runs under six pointed stone arches. Openings between the gallery piers lead to small rooms with supply crates and surviving roof timbers. The route to the practice yard bends around two more masonry returns, with worn earth marking the turns. The arrival coach parks beside the gate approach to keep the foot route clear.

The entry fixture checks sightlines from the road and first forecourt, then walks Arjun through the gate, into and out of a chamber, along the gallery and through the staggered ward openings. Native review includes the screened forecourt, gallery and chamber. The outdoor firing line remains in the central yard.

Gallery masonry refinement uses seven individually jointed pier courses and recessed pointed-arch wedge joints. Small deterministic erosion affects the outer arch edge, keeping the clear passage envelope and all existing story routes. Entry traversal and privacy checks pass after the change. Native entry review passed all 18 route/privacy checks. Continuous recessed stone bedding now backs the arch joints. Pier courses share the weathered plaster shader instead of periodic material swaps. Current-source native traversal/privacy18/18 passed and gallery/chamber views were inspected. Broader masonry silhouettes remain stylized.

Damaged entry-wall fragments now use full-height fractured masonry meshes with a continuous world-space upper profile and matching static triangle collision. Flat face normals remove segment-edge lighting bands. Three side rooms retain dark joist pockets and short broken timber ends at the old floor height. These construction remnants stay above circulation and do not change the courtyard firing lane. Final native entry traversal/privacy18/18 passed; forecourt and chamber views were inspected. This replaces the first cap-only version, whose stepped silhouette was rejected during review.

## Assigned camp jobs and free-time routine

The private camp now has fourteen separately saved members: two elevated lookouts, an outer gate watchman, a seated talking/listening pair, a relaxing member, two sleepers, a supply carrier, Mangal’s discussion partner, a gun cleaner, a cook and two members at a separate drinking corner. They reuse the complete existing MPFB rebel body. The cook uses the existing clay hearth/griddle with a wooden spatula; the cleaner holds an Enfield across his lap. The carrier pauses to transfer his crate to a depot, then returns empty-handed. Carrier travel and unloading phase survive saves.

When the story and conversations release him, Mangal cycles through discussion, planning with a folded map, rifle inspection and rest in his chair. The saved routine clock changes the activity encountered on later visits. Mission, consignment and conversation ownership take priority.

Daily life uses the shared simulation budget. Within 80 metres, work and contacts update at full rate; the middle tier uses 0.1-second work updates. Beyond 200 metres, resident AnimationTrees and lookout processing suspend, with the schedule clock retained and checked every 0.5 seconds. Mangal’s visual processing only suspends when free of mission ownership and resumes when a mission needs him. Nearby approach restores visual work immediately. Collision, living/dead identity, save ownership and story systems remain active. No whole-world FPS improvement is claimed without measurement.

Verification for assigned routines: current native environment review and headless environment fixture passed the14-role roster, distance suspension/resumption, saved clock and Mangal task changes. Headless fixture also verifies mission ownership wakes distant Mangal. Final isolated rebellion story/save fixture and populated ordered story fixture passed. Native cook, cleaner and drinking corner views were inspected; temporary output removed. These bounded checks do not establish whole-world FPS or every animation/clothing extreme.
