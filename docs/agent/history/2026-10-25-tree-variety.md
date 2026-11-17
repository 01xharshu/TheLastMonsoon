# Tree variety implementation notes —24–25October2026

## Visible tree variety — chat 01a12cad-e9bb-7952-bc7e-4e2cc95dd947, /root
Updated: 2026-10-25T10:59:02.899399+05:30; **IN_PROGRESS**. User sees no tree diversity. Main authoritative; preserve concurrent rendering/NPC/cannon work.
- Found: main Landscape and WildernessExpansion baked BroadleafTrees reuse island_tree_02; existing editable forest canopy/broad/small assets limited to60m grove.
- Scope: deterministic shared tree palette across existing placements, visibly distinct crowns/branching; terrain-root/trunk/road contracts and LOD retained, no added tree population. Inspect native normal-world views and measure bounded native rendering before acceptance.
- Implemented initial palette after original trunk repair: four stable spatial choices (existing broadleaf, dense mango, spreading forest crown, young small tree), shared imported meshes, no new tree slots. Re-ground and rebuild each variant woody collision, preserve batch visibility and source slots. Next compile/geometry and native review; reusable variety/grounding/route checks, native review in temporary outputs. No current tree edits; other owner cannon renderer active, wait for own native review.

- Tree milestone: native focused32slot test fourmesh identities/island10,mango10,spreading6,young6; terrainembed/solidtrunks/idempotence pass; palette pixels inspected. Headless procedural MultiMesh returns unusable transforms, so validator explicitly requires native rather than claiming pass. Shared imported PBR forest shader+wind reused; generated mesh LODs. Next actual-world counts/views and same-view baseline/variety native frame sampling; outputs disposable.

- World review first attempt rejected harness readiness: OpeningSequence accessed before creation. Stop only own renderer, wait for tree palette + opening node. No production failure established. Fixed test-only reference rendering for batches with zero retained island trees. Rerun normal-world native; no acceptance from rejected run.

- Actual-world native rejected: all4types Landscape1759/Wilderness1606; roots1759/1759 supported, but per-variety StaticBodies exceeded existing16384 Jolt body cap. Fix: retain/reuse exactly one original SolidTrunks body per tile; append each variant actual wood shapes to it, shared shapes cached. Pure mesh trunk profiles now cached across tiles. Stop only own rejected renderer and rerun; no budget setting increase/collision removal.

- Consolidated collision native fixture cleanPASS (fourforms,all32roots/solidtrunks). Final actual-world review session54854/fii7dtih running with cached profiles/onebodypertile; root checks and baseline/palette frame sampling across village/east/wilderness. Docs `docs/world/tree_variety.md`; final results pending.

- Actual world onebody-per-tile clean tree/root pass3365/3365; views inspected, initial60frame perregion medians reference/variety143.30/134.36 village,81.39/166.87 east,136.31/97.78 wilderness (dynamic-world variance; no FPS approval). Mango original611829vertices too heavy for common use; build retained gameplay mesh from original via LOD+whole-leaf sampling,51146vertices/137292indices, source unchanged. Palette weighted triangles now near original budget; rerun native asset/route and final world cost/views with reduced mango.

- Reduced mango native consignment fixture cleanPASS49.9s:4shared tree meshes,7,922.88m route0supportgaps/0blocks, actual policehits and4FPVkills/twowaves/reward/save/cleanup intact. Runtime mango1.7MB derived .res from retained .blend/GLB;51146vertices vs611829source, whole-leaf sampling preserves silhouettes, automatic LOD. Next final world native reduced-resource views/roots/geometrybudget/frame samples.

- Final reduced-asset world attempt aborted/cleaned due another native streaming profile + headless heavy job on host; only owned PID77268 stopped. No performance evidence accepted from overlap (prior dynamic frame samples also not speed-up evidence). Native runner now waits for free renderer and aborts its own run on new overlap. Final reduced-asset world pixels/geometry/frame gate still pending; all route/32slot functional gates passed.

- Reduced mesh exposed actual woody-band sampling hole: triangle edges crossed a lower trunk band with no vertices inside it. Add edge cross-section fallback only for empty woody bands in tree_trunk_collision.profile, keeping actual low mesh collision continuous (no looser test). Another new renderer overlapped final attempt; discarded/stopped own renderer. Need focused32slot native after fallback, then final world when free.
- 25Oct resume: current source reconciled; no surviving owned tree runner/output. Other owner headless import active; no native renderer at resume. Next native32slot/cross-section check then final native world; preserve newly dirty carried-weapon/stance owner files.

- 25Oct final reduced-mesh native32slot check cleanPASS after cross-section fallback: all4forms, all32roots embedded, all woody segments solid, onebody/tile, unchanged source, repeat idempotence. Native reduced crown pixels inspected; retained dense-vs-open contrast. Temp4j4x9dey cleaned. Next isolated native world geometry/root/camera/frame gate.

- Other native jobs repeatedly entered during world startup, preventing final sampling. Reusable world runner now pauses ONLY its owned renderer on overlap, resumes when other jobs finish; epoch marker restarts any interrupted60frame window with20warmupframes. No concurrent measurements accepted; no other job signalled. Focused review continues to reject overlap outright. Next resume final world and finish, no production changes in this coordination fix.

- Final reduced-asset actual-world native cleanPASS after collision fallback: Landscape1759/1759, Wilderness1606/1606 grounded; all4forms both. Base triangles reference/variety31,662,000/32,344,648 main (+2.16%),28,908,000/28,006,224 wilderness (-3.12%); combined slightly below old total.60frames per mode/view Medium720p same-camera med/p95 ms: village127.030/160.344→118.991/150.591;east64.701/65.529→68.925/70.109;wild33.678/45.350→32.780/43.393. No overlapping windows; actual images inspected (east view partly foreground-trunk obscured; fixture views show whole forms). No global smooth-FPS or final tree-art approval. Temp_q2vse1z cleaned; next main import + final route regression then concise docs/ledger/cleanup.


Final scoped implementation/native checks complete; current concise status in CODEX_HANDOFF and docs/world/tree_variety.md. No raw test output retained.

## Four-form baseline documentation before named-species extension

# Visible tree variety — 24–25 October 2026

The main landscape and wilderness previously repeated `island_tree_02` across their baked BroadleafTrees batches. The existing forest asset palette only appeared within the small forest-grove patch. Consequently normal village travel and the expanded consignment route mostly showed the same open-branched silhouette.

`world/suryagarh/tree_variety.gd` now distributes four shared visual forms over the existing tree slots: the original open-branched tree, dense mango, spreading forest crown and a smaller young tree. These are visual forms, not a claim that every generic forest asset depicts a named botanical species. Deterministic world-root hashing chooses a form independently of batch order and save/load. Existing orientation/scale variation remains, with controlled mature/young height differences. No new tree positions or population are added.

Reduced woody meshes sometimes span a lower-trunk band without a vertex inside it. The shared trunk profiler now measures triangle-edge cross-sections for those empty bands, preserving continuous solid wood without restoring high-detail render geometry. Existing populated bands retain their previous measurements.

The palette runs after original terrain/trunk repair and before broadleaf render-record compaction. Each replacement retains the original visible root point, samples actual terrain support, and rebuilds wood collision from its own mesh profile. All forms within a tile share the original trunk StaticBody, avoiding extra physics bodies. The original shared mesh resources are not mutated. Saved render source-slot indices and instance colour/custom channels remain. Existing tile visibility distances/culling remain; replacement meshes are cached once and include generated mesh LODs. Forest bark/foliage shaders, photographed textures and wind are reused through the existing forest mesh loader. Pure geometry trunk profiles are cached across tiles.

Editable source assets remain `WorkingAssets/Environment/Forest/{canopy_broad,small_tree}.blend` and `WorkingAssets/Environment/MangoTree/mango_tree_01.blend`, with their original GLBs and textures. The shared gameplay mango is `environment/vegetation/world_palette/mango.res` (about 1.7 MB), rebuilt using `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/environment/build_world_tree_palette.gd`. It uses 51,146 vertices / 137,292 indices, versus 611,829 vertices / 1,644,999 indices in the original. Whole connected leaves are sampled evenly and modestly enlarged to retain crown coverage; arbitrary leaf triangles are not removed. Mesh LODs remain. No source body/leaf geometry or texture inputs are overwritten. Original baked terrain/nature scenes remain unchanged.

Reusable native checks (GPU-backed MultiMesh transforms require native rendering):

- `python3 tools/world/run_tree_variety_check.py`: four distinct mesh identities, all 32 fixture slots retained, one physical body per mixed tile, terrain embed, solid visible trunks, setup idempotence and source preservation.
- Add `--review` for disposable palette pixels.
- `python3 tools/world/run_tree_variety_check.py --world --review`: actual New Journey, all four forms in main and wilderness, every visible root supported, village/east/wilderness views, and same-camera reference/palette frame samples. Reference rendering is available only under the test environment flag; it retains reference resources only for that test. Temporary user data, logs and captures are removed on exit. The world runner yields its own renderer when another native job starts and resets interrupted frame windows after resuming; overlapping frame samples are not accepted.

Final native verification **PASS** on 25 October: 32 fixture slots retain four mesh identities, one trunk body per tile, continuous solid woody bands, grounded roots, unchanged source data and idempotent setup. The reduced palette and actual village/eastern slope/wilderness views were inspected; the eastern camera has a foreground trunk partially obstructing its view, so that frame is not a complete close-art review.

The actual New Journey world retains all 3,365 trees: main landscape 1,759/1,759 supported roots, wilderness 1,606/1,606. All four forms occur in each. Main counts are 434 open-branched, 459 mango, 441 spreading and 425 young; wilderness 382/388/399/437. Combined base triangles are 60,350,872 versus 60,570,000 for the old palette. Main rises 2.16%; wilderness falls 3.12%. Runtime culling and mesh LODs remain additional reductions.

Same-camera native Metal Medium1280×720 samples, 60 frames per mode/view, with interrupted windows discarded/restarted:

| View | Original p50/p95 (ms) | Mixed palette p50/p95 (ms) |
| --- | --- | --- |
| Village | 127.030 / 160.344 | 118.991 / 150.591 |
| Eastern wooded slope | 64.701 / 65.529 | 68.925 / 70.109 |
| Wilderness route | 33.678 / 45.350 | 32.780 / 43.393 |

These bounded dynamic-world observations do not establish a whole-game speed-up or smooth FPS. The wooded view has a small measured increase; existing populated-world performance remains open. No overlapping native samples were accepted. Temporary captures/logs/saves were deleted.

Final consignment native regression **PASS, 36.1 s**, including all four shared tree meshes, the 7,922.88 m route with zero support gaps/covered-cart blocks, real police hits, four rifle kills/two waves, one-time reward/save/merchant/camera cleanup. Main editor import **PASS**, exit 0 / zero errors; scoped whitespace and runner Python syntax **PASS**. No commits or pushes.

To see the palette in normal play, reload the world through Continue or New Journey. Existing saves require no migration: the terrain setup reconstructs the same deterministic tree choices. Look beyond the village into the wooded hills and along the extended consignment route; the small original forest patch is no longer the only place with varied tree silhouettes.
