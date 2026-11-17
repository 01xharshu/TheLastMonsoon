# Independent NPC activities and expressive behavior

Current implementation: 2026-10-26, main checkout. Functional baseline integrated; river replacement clothing and final art acceptance remain open. No whole-world performance approval is implied.

## Where to find the activities

| Place | Independent activity |
|---|---|
| Bhairavpur House25 repair yard | Adult MPFB cart maker seated on a low stool, bracing a wheel and striking with a wooden mallet |
| Dairy strip beside House27, approximately world X−329/Z306 | Adult MPFB milkman pushing a separate instance of the same wooden handcart design, with six visible milk baltis and securing bars; six-metre delivery strip with pauses and reverse travel |
| Bhairavpur House30 | Adult MPFB potter seated beside the retained hand wheel, turning the rim and shaping the workpiece; existing drying pots preserved |
| Existing college district | Four existing residents, using scholar/teacher models: reading, reed-pen writing, discussion/listening, and standing teaching |
| Existing village river route | Three adult MPFB women assigned laundry, clothed bathing and seated conversation; physical walking route and individual water-pot state retained |

Workers operate independently during06:00–18:00. College study cycles are independent42-second phases. The river keeps its existing morning schedule. New actors are amortised during startup and use the shared simulation budget at distance; movement retains swept obstacle checks and collision.

## Sources and ownership

Every new human reuses an existing Blender MakeHuman/MPFB donor. No human is made from primitive geometry. `tools/characters/build_activity_people.py` imports retained donor runtime bind poses and writes editable sources under `WorkingAssets/NPCs/activity_people/{artisan,dairyman,scholar,teacher}/`, paired with `characters/npcs/activity_people/*.glb`. Each source folder contains its provenance manifest. Complete14517-vertex bodies and opaque foundation layers are retained. The new cotton garments follow the same physique and skin weights; original donor assets are preserved.

`characters/npcs/activity_actor.gd` adds named work poses beneath the existing combat branch of each personal AnimationTree. Incoming poses ease over0.65seconds. Hand IK uses actual rig orientation; seated contact uses cached samples from the retained MPFB body and supported feet. `named_occupations.gd` owns the three workers and `story/college_activity.gd` owns the existing college actors. `activity_props.gd` supplies the common cart, baltis and tools. `activity_save.gd` retains independent phase/travel and late-spawn restore state through the normal save manager.

`civilian_awareness.gd` senses actual threats with occlusion and informs `civilian_reaction.gd`. Ordinary civilian owners yield to startle, guarded self-defense, escape, shelter and return. A stowed or un-aimed gun does not trigger panic. Direct unarmed assault can cause a confident civilian to defend; an aimed weapon escalates fear. Defensive punches use the existing strike-contact and damage-policy owners. Impact severity separates ordinary contact, stumble and nonlethal fall/recovery. Mission/police/external combat actors retain their existing owners. Mouth/fear/blink shapes and conversation gestures are procedural acting; no audio phoneme lip sync is claimed.

## River and privacy

`river_ghat.gd` builds modest stone working edges, twelve opaque reed panels and eight shared shade trees beside the retained earth access. `river_access_path.gd` draws the worn approach and reserves matching grass instances at startup, leaving surrounding vegetation. The real river and boat route remain. These are fictional village working edges, not an exact reconstruction of a documented1857 site.

The river actor retains the original complete body, identity variations and opaque clothing. Laundry, forearm/cheek washing and conversation use separate roles. Alarm response eases out of work, prepares to leave, then follows the physical route home at a hurried pace. It saves alarm/preparation/water state and avoids a duplicate same-day departure.

The existing river clothing still has layer/art defects. The replacement `WorkingAssets/NPCs/river_activity/river_activity.blend` and corresponding `activity_people/river_activity.glb` are an unapproved construction study, enabled only by `TLM_RIVER_ACTIVITY_CLOTH=1`. Original sources and runtime remain intact. The study preserves complete body rest coordinates/topology and repairs inappropriate thigh influence on181 above-hip waist skin vertices; this does not change physique. Its pose cache and checkpointed fitter are rebuild inputs. Do not promote it before strict body, garment-layer, foundation, real-bank contact and native1.0x review pass. Revised work motion is separately gated by `TLM_RIVER_ACTIVITY_MOTION=1` and remains isolated until garment and rendered acceptance. Its wider squat opens the knees, seated feet stay along the bank, and elbows stay clear of the chest. The full219-pose body gate includes actual bathing and conversation roles.

## Reusable verification

Run from the project root. Runners use private temporary saves and delete diagnostic output, screenshots and logs on exit.

```sh
python3 tools/world/run_npc_activities.py
python3 tools/world/run_npc_activities.py --native --village --playback
python3 tools/world/run_npc_activities.py --world
python3 tools/characters/check_women_river.py
python3 tools/world/run_npc_pose_check.py --residents
```

Latest completed results:

- Reaction fixture52checks passed headless and native, including stowed/un-aimed/aimed discrimination, wall occlusion, physical escape, guarded defense, weapon escalation and hard-impact fall/rise. It also checks physical return with the original workplace heading and station-bound study props during interruption.
- Actual village/college34checks passed headless and native. Work hand contacts below1mm; cart maker/potter body-seat contacts0.890/0.039mm, seated ankle error below15mm. Milk cart travelled9.728m with zero blocks in the bounded fixture.
- Native ordinary-time playback42checks passed: repair8.013s, milk24s, potter16.001s, full scholar cycle44.004s, teaching4.003s. Worker/scholar maximum palm errors1.007/1.929mm; teacher16.422mm. Animation clocks tracked wall time.
- Actual production New Journey/disk-save13checks and fresh-processContinue12checks passed. Three workers and all four college actors retained independent phase/travel; actual defensive punch contact applied damage with correct attacker identity. Earlier same-process teardown/Jolt-capacity failures were rejected harness evidence and were corrected by fresh-process loading.
- Existing resident cadence7469checks passed. Default river route/schedule/save/far-cadence plus alarm-return regression passed; maximum wrist13.343mm, ankle0.061mm. The isolated refined squat/reach also passes these checks, wrist1.201mm, but remains gated pending clothing/native acceptance.

Worker/college views were inspected during the native checks. This establishes a usable baseline, not final cloth realism across every action/outfit or whole-world FPS. The original motion had knee/torso intersections despite passing hand/ankle targets. The current study squat and along-bank seated pose passed sampled imported-geometry torso/leg checks. The knee proxy uses a 60 mm radius scaled with the actor, checked against the actual mesh near the critical stand-up pose. The old motion was a failing negative control. These checks use actual imported Godot skin/morph data; they do not substitute for a rendered motion review. River replacement garment fit remains the active asset gate. Check the current owned entry in `CODEX_HANDOFF.md` before resuming its fitter.

For the isolated replacement study:

```sh
python3 tools/characters/run_river_activity_fit.py
TLM_RIVER_EXACT=1 TLM_RIVER_ACTIVITY_CLOTH=1 TLM_RIVER_ACTIVITY_MOTION=1 python3 tools/characters/check_river_cloth.py --layers --foundation-fit
```

The fitter checkpoints every eight poses and rejects excessive corrections. It exports the runtime only after all samples succeed. Follow a five-pose pass with the full252-pose audit and real-bank/native motion review; passing source import alone is insufficient.

For native ordinary-time river work, including lowering/fill, laundry/bathing, seated discussion, rise and pickup:

```sh
TLM_RIVER_ACTIVITY_CLOTH=1 TLM_RIVER_ACTIVITY_MOTION=1 python3 tools/characters/check_women_river.py --playback --review-seconds 60
```

This runs a48-second ordinary-time work cycle at wall-clock speed and checks hand/foot targets and elapsed time. Optional disposable frames remain briefly available for inspection and are deleted on exit. The body audit is `tools/characters/audit_river_body_contact.py`, invoked by the cloth checker; it compares disjoint rest-space torso/leg regions with the existing finite triangle crossing checker and checks knee ground clearance.


The shore approach now continues 0.5 m toward the water as a level earth edge. This keeps the three women on a consistent work surface while retaining the original approach grade and actual collision. The real route and hand/foot/knee checks pass. The optional relaxed clothing candidate is selected only with `TLM_RIVER_SECONDARY=1 TLM_RIVER_RELAXED=1`; it has separate editable sources and is not production-approved. `TLM_RIVER_WORLD_FIXTURE=1 TLM_RIVER_SEATED_ONLY=1 python3 tools/characters/check_river_cloth.py --skin-triangles --layers` checks the real bank, including exact body/wrap triangle crossings. Set `TLM_RIVER_WORLD_MEMBER` to 0, 1 or 2 for each actor.

## Occupation appearance follow-up — 29 October 2026

The cart maker, milkman and potter now use separately assigned fabric colors on their existing skinned shirt and trousers; the three individuals also retain their original complete bodies and textures with small individual skin-material adjustments. This is a first visual distinction, not an occupation-specific garment redesign or a world-wide skin-tone solution. Headless and native village fixtures passed 50 checks including active material assignments, textured full bodies, work contacts and the milk cart route. Temporary close native views showed the shirts still follow body contours tightly with jagged neck and hem edges; new fitted garment cuts and ordinary-time clothing/contact review remain open. The other jobs and broader population skin variation are not covered by this change.

2026-10-31 population follow-up: ordinary Street_, Colleague_ and Village_ MPFB actors now receive stable individual skin-material variation, preserving original textures and full geometry. Duplicated materials are cached in the owning world. The actual city fixture passed with all188walkers receiving variation and all three values represented, plus188moving walkers and16moving carts in its bounded sample. The six-person headless/native texture/cache fixture passed, and its corrected front lineup was inspected. Whole-world hue/lighting/art and native frame-cost acceptance remain open; this does not resolve the rejected garment studies. Run `python3 tools/world/run_population_skin.py --native --review` for a disposable lineup check.

2026-11-02: Native private-world skin comparison (`python3 tools/world/run_population_skin.py --native --world`) passed for188 override surfaces at1280×720, Medium, scale1. Baseline p50/p95=161.257/177.505ms, variation160.795/176.579ms, repeated baseline157.717/174.697ms. No added material cost was measured in this bounded changing-world sample. Overall city performance remains poor; this does not accept whole-game FPS or skin appearance in all lighting. Temporary output/userdata removed.

The read-only `audit_activity_foundation.py ROLE` now uses strict volume confirmation and checks an inverse-skin known-displacement control without saving sources. All four retained sources pass that numerical control (worst error<0.00007mm), but their current foundations fail seated-angle vertex clearance: artisan75, dairyman76, scholar76, teacher76; idle0 for each. `--require-clear` makes geometry rejection explicit. This locates an existing folded hip/skin-shell problem; no replacement garment has been integrated or approved. Real animations, transitions, garment layers and native visual review remain required.

2026-11-02 patterned foundation study: the disposable CC0 MPFB-pattern candidate clears sampled body penetration (outer0/6256 and foundation0 in each simplified idle/walk/seated pose), after separate walk and seated correction passes. This is **rejected**, not production clothing. The conservative coverage screen still flags11/14/30 points; temporary front/side renders confirm seated waist/crotch layer intersections and jagged fabric. Upper and lower garments need separate fitting and garment-to-garment collision checks before actual AnimationTree/native motion review. Sources/runtime remain unchanged; temporary study/captures are deleted.

2026-11-05 workwear follow-up: `WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_workwear.blend` retains the unchanged complete artisan body, original face morphs, packed textures and separate opaque foundation. The active CC0 MPFB-pattern candidate passes independently reopened idle/walk/seated geometry: frozen topology,6,040 outer body samples, exact self/interlayer crossings and951 foundation visibility samples per pose; all rejection counts zero, with an active body-only visibility negative control. Temporary front/side/back authoring views were inspected. This is an editable candidate, not runtime approval.

`export_occupation_workwear.py` exports two separate cotton components with all skin weights and walk/seated morphs. The temporary GLB passed102 actual Godot ActivityActor samples with speech/fear/blink and fabric morphs preserved. The candidate-only `occupation_cloth_correctives.gd` binds fabric keys to actual leg pitch. This removes the sampled lower-body body intersections, but native relaxed-arm shirt contacts and intermediate foundation/trouser crossings remain. Native-pose replay must match the unchanged body before further fitting. `run_occupation_native.py` owns temporary exports, pose JSON and private userdata cleanup; Python failure codes are explicit. No replacement has been integrated into live occupations.

The artisan wardrobe now has two editable sources under `WorkingAssets/NPCs/occupation_wardrobe/artisan`. The sleeveless candidate uses the game's named skin bindings and actual seat and ankle solver. Retaining lower support between seated work labels cleared the large lower cloth folding previously observed when switching tasks in the fixture. The village regression passed 50 checks. Native renders showed seated knee punctures between earlier point samples, so the independent native audit now also checks exact intersections against body triangles. Repair those, the remaining motion contacts and the armhole edges before replacing the live costume.

The retained `artisan_motion_workwear.blend` passes all 119 captured native samples with a moving root, planted feet and the standard 0.45 m fixture seat. Use `run_occupation_native.py --candidate WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_motion_workwear.blend --moving-walk --all-samples` to repeat the check. The original village stools measured 0.27 m for the cart maker and 0.26 m for the potter. The potter’s deeper pose still needs a separate fit.

The cart maker now wears a fitted sleeveless cotton vest and trousers in the default village, with his original complete body and separate foundation garment. The editable source is `cartmaker_repair_workwear.blend` and the runtime asset is `characters/npcs/activity_people/cartmaker.glb`. The 0.45 m stool has four terrain-supported wooden legs. A 0.02 m lateral adjustment keeps his feet clear of the wheel while retaining his reach to the mallet and axle. Headless and Metal village runs each passed 53 activity checks and 39 exact garment samples through sitting and the first full mallet cycle. The candidate also passed real-time repair playback and the installed outfit and stool were inspected in the village view. Other occupations still need distinct fitted cuts.
