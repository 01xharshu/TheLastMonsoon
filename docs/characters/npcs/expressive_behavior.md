# NPC expressive behavior

Behavior contract and implementation status, 2026-10-25. See [independent activities and verification](../../world/npc_activities.md) for current sites, commands and remaining asset gates.

- Conversation: speaker mouth movement, facial expression, gaze, breathing, restrained varied hand/body gestures; listener attention/nods and turn taking. Use audio timing where actual speech exists; procedural subtitle acting must not be described as audio lip sync.
- Danger: perceive a witnessed fight or visible threatening weapon with sight/occlusion and context. Startle, recoil, guard, look toward danger, retreat, seek reachable shelter or escape. Confidence, job and circumstances vary responses; a capable defender can still show fear. A merely carried/stowed weapon must not trigger universal panic.
- Defense: unarmed confrontation may elicit guarded resistance; a drawn weapon changes risk assessment. Preserve police/mission combat owners, damage, identity and existing permissions.
- Collision: brush/bump, stumble and hard-impact fall depend on relative speed/severity. Do not knock people down for ordinary contact. Fall includes landing, grounded state, recovery and return to activity; avoid repeated overlapping reactions.
- Work: occupation-specific preparation, tool grips, repeated actions, carrying and cleanup. Keep props, hands, feet and garment contact correct; existing jobs need individual coverage.
- Sitting: seat-height-aware chair/bench, ground and other appropriate postures; approach, turn, entry, settled shifts, conversation and exit. Support pelvis, feet and hands; no instant pose changes or floating.
- Priority: death/incapacitation and authored critical interactions own the actor; immediate danger interrupts ordinary social/work activity; safe recovery resumes the retained schedule. Save durable identity/activity, avoid persisting invalid node references.
- Performance: reuse world-scoped sight/spatial/navigation owners and simulation_budget.gd; near threats/interactions full rate, remote updates accumulate time. No global per-frame actor scans or collision removal.
- Acceptance: inspect actual MPFB male/female actors at 1.0x through idle/walk/run/turn/seating/action extremes, including facial close views, clothing and body/prop/terrain contact. Functional tests alone do not grant visual or whole-world FPS approval. Temporary output must be deleted.

## Existing integration points

- `characters/npcs/british/british_npc_actor.gd`: shared skeleton, personal AnimationTree, hand/foot contact, ordinary resident pose cadence and combat setup; currently dirty from another scope.
- `combat/npc_combat_motion.gd`: tree branch for hit/strike/held/fall/down/rise, incoming pose easing and knockdown garment corrective.
- `combat/npc_vitality.gd`: health, incident reporting, knockout/death and posed hit bodies. Existing faction permissions must be preserved.
- `world/suryagarh/population_social.gd`: world-scoped spatial conversation pairing, availability and traffic awareness.
- `world/suryagarh/city_street_journey.gd`: conversation turn taking, hand gestures/head movement and swept journey owner.
- `story/community_social.gd`: existing seated discussion overlay; not a general seat transition solution.
- `story/dialogue_expression.gd`: story expression/speech/blink mesh deformation. Builds duplicated body meshes and skips pre-existing shapes; not yet a population-scale facial solution.
- `world/suryagarh/settlements/chacha_actor.gd`: story-specific advice gesture/expression integration.

## Current implementation and verification

`civilian_reaction.gd` and the world `civilian_awareness.gd` provide interruptible startle, guarded defense after direct unarmed assault, aimed-weapon escalation, queued physical escape, shelter/cowering and return. Existing combat motion supplies stumble/fall/down/rise; collider orientation follows the fall and recovery checks standing clearance. Sight respects solid occlusion; stowed and un-aimed carried guns do not trigger panic. Ordinary street/social/work owners yield while a civilian reaction owns the actor. Mission, police and externally controlled combat owners retain priority.

Ordinary actors share a world-scoped facial mesh cache; four new worker/academic assets have authored speech, fear and blink shapes. These are procedural conversation expressions, not phoneme/audio lip sync. New activity actors retain their personal AnimationTree combat branch and add eased work poses and hand/seat contact.

The reusable reaction fixture passed52 checks headless and native, including real escape movement, weapon discrimination, wall occlusion and nonlethal fall/recovery. Actual-world verification additionally exercised a defender's physical punch and attacker identity through existing damage policy. Native worker/college playback and save/Continue evidence is in the focused activity document. These checks do not approve every existing occupation, police/mission character or garment at every action extreme.

## Assigned independent activity sites

Implemented in the production world: House25 cart repair, House27 dairy handcart with six milk baltis, House30 seated potter at the retained wheel/drying pots, and four existing college residents studying/teaching/discussing. Separate controllers retain independent phase and save state. The river group has laundry, clothed bathing and seated conversation roles, a worn approach with grass clearance, stone working edges, opaque reed screening and eight shared shade trees.

River threat response prepares a physical return from the work area and retains alarm/route state through save. The old river garment has unresolved layer/art defects. A replacement source is isolated behind `TLM_RIVER_ACTIVITY_CLOTH=1` until strict full-body/layer/foundation and native motion checks pass. Neither this document nor functional checks grant final river clothing approval.

## Adult female secondary motion candidate (2026-10-26)

The river candidate uses `adult_secondary_motion.gd` with dedicated breast bones, damped acceleration response and clothing support. Motion follows walking, turning and stopping; idle does not generate a synthetic oscillation. Remote update gaps and teleports reset the spring. Explicit adult metadata is required.

`build_adult_breast_secondary.py` uses Blender MPFB to author three individual profiles (cup-size parameters .33/.45/.57) from the retained adult donor. The complete body and fitted foundation/upper garments receive the same profile displacement and bone influence. This models individual variation rather than assigning a body type by ethnicity. Editable inputs and sources are in `WorkingAssets/NPCs/river_activity/`; the original donor remains intact.

The candidate is selected with `TLM_RIVER_SECONDARY=1`; `TLM_RIVER_PROFILE=smaller`, `original` or `fuller` pins a profile for checks. Production promotion remains pending clothing and native review. The three river adults are the current integration scope; other female rigs still need their own authored fit and motion verification.

Reusable checks: `python3 tools/characters/run_adult_secondary_motion.py` (11 spring checks), and `python3 tools/characters/run_adult_secondary_motion.py --asset` (27 imported-asset checks). The asset check measured walking peaks of 2.247/2.427/2.618 mm and a maximum body/foundation displacement difference of 0.000477 mm across 308 paired vertices. These results establish restrained response and coherent binding, not visual or final deformation acceptance.

The river work fit also checks the actual bank height. The rinse bends both spine joints so the cloth can reach the water without extending the arms beyond their authored length. `TLM_RIVER_CONTACT_DIAGNOSTICS=1` records shoulder, target and available arm span when the route check finds its worst reach. The 15 mm reach gate remains unchanged. Exact rinse-bottom time 26.0 is included across the sampled members and roles.

Garment fitting stitches coincident construction vertices of a sewn cotton edge before checking self-intersections. The construction match is limited to 2 micrometres in the reference shape; projected copies may not diverge by more than 15 mm. The body is untouched. Corrective fitting and geometric checks are intermediate gates; the refreshed candidate still requires the complete layer/profile audit and native motion review before production promotion.


Adult female fuller proportion studies (updated 2026-11-02): all six independent
MPFB profiles now have separate fuller editable studies. Complete 19,158-vertex
source bodies and individual identities remain intact. The measured bust forward
increase ranges from 5.17 to 12.15 mm and rear backward increase from 5.92 to
6.93 mm; no head displacement was measured. These are local surface changes,
not circumference measurements. All six sampled upper/body and foundation/body
checks passed after refitting female_05's foundation (11 poses each).

Rebuild with `python3 tools/characters/build_indian_fuller_studies.py` and measure
with Blender `--background -noaudio --python-exit-code 1 --python
tools/characters/audit_indian_fuller_proportions.py`. Original candidates and
production GLBs remain separate. A clothing self-audit passed female_04 and
failed the other five fuller uppers. `build_indian_shared_tailoring_study.py`
adapts the cleaner retained blouse, foundation and separate sari panels to a
target's existing fuller body. It writes a new explicit study and preserves the
prior clothing. All five transferred outfits now pass the sampled foundation/body and upper/body
checks (11 poses), exact layer checks and three-piece self-fold checks (five
swings). This remains a source-level gate.

`python3 tools/characters/check_indian_fuller_studies.py --identity female_05
--fit-waist --review-seconds 60` exports the selected study into a temporary
project and removes its GLB, captures and diagnostics afterward. Add
`--foundation-only` for the covered base silhouette. The opt-in waist fitting
samples ten sections of the actual retained body once during setup, then joins
the fitted seat to the hem while retaining the moving-leg envelope. The
fuller_05 native lower check passed 46,240 probes with no detected intersections;
side/back inspection showed removal of the broad floating rim. This does not
approve the stiff upper, all garments, run/seated extremes, secondary motion or
live-world integration. Rear secondary motion and run review remain unfinished.


The full native check additionally samples the imported foundation and blouse/
panels with `--upper-contact`. It exposed foundation contact at the side
armholes during the actual walk, missed by the initial synthetic pose set.
`fit_indian_foundation_armholes.py` creates a separate `tailored_armhole_study.blend`
with smooth lower side armholes, interpolated weights and UVs, retaining the
opaque bust/lower foundation and unchanged full body. On female_05 this passed
466,412 native probes across all six garment pieces at seventeen idle/walk
samples; covered-base front/side/back and sampled walking views were inspected.
Edges and outer shoulder strips still require visual refinement. The equivalent
sources exist for all six identities. Their latest full native idle/walk checks
passed 2,800,614 probes in total, with no detected body/garment intersections:
467,891 / 466,616 / 467,211 / 465,426 / 466,412 / 467,058 for01–06.
These checks cover seventeen samples, all six garment pieces and the imported
complete skin; they do not cover running, seating, turns, final visual quality
or whole-world frame time.

Individual fit settings are retained in the editable armhole studies by
`calibrate_indian_outfit_studies.py`:03 uses0.18rad arm clearance, the others0.12.
The exporter carries a small allowlist in GLB node extras; Godot imports these
inside node metadata `extras`. The street actor reads the versioned fit there,
with explicit actor overrides taking precedence. The measured waist samples
actual deformed triangle/plane intersections from cached skin bindings, avoiding
holes caused by sparse vertex-row estimates. Uncalibrated existing assets keep
their previous behavior.03 was rechecked without test overrides:0.18rad and
waist fitting loaded from the asset, with467,211 probes passing again.

The body/outfit candidates remain unassigned to the live population. Floating
shoulder/pallu strips, rough garment edges and rigid lower fabric are still
visible defects. A local seam projection passed contact but introduced a pointed
edge and was rejected visually. A separate cotton settling study is undergoing
source/contact/visual review; it is not the authoritative body or live outfit.

The November 5 secondary motion studies retain four authored breast/glute bones
and coherent body/foundation weights in all six complete adult MPFB bodies.
The editable sources are
`WorkingAssets/NPCs/indian_body_candidates/female_01` through `female_06`,
each with a separate `run_tail_fit_study.blend`. The corrected sources passed
sampled walk and run contact checks, 3,459,561 probes per six-profile pass.
Profile 05 also required bounded foundation and blouse corrections during the
run. Retained sources and versioned body-fit metadata carry those corrections.

Street actors install the run branch by default. In the disposable review,
`TLM_STREET_RUN=1` selects the run sequence, alongside
`TLM_STREET_SECONDARY=1` for the authored secondary rig. Its AnimationTree
branch contains a separate 0.72-second gait and explicit phase sampling.
The dedicated foot solver pins each stance foot for 0.32 of a cycle and releases
it during flight. All six profiles passed the sampled stance check, with maximum planted ankle
error 0.163 mm, and the current run passed 3,459,561 garment probes.
Profile 05 required a further fitted foundation correction after foot planting.
The lower cloth uses cached skin bindings around the feet during the run to
keep the moving sole clear of the hem.

Review a source through
`python3 -u tools/characters/check_indian_fuller_studies.py --identity female_04 --source WorkingAssets/NPCs/indian_body_candidates/female_04/run_tail_fit_study.blend --upper-contact --realtime-walk --review-seconds 60`.
Set both environment variables above for the run. Captures and exported review
assets are temporary. The run fixture spans 8.4 metres centred on its origin.
Live world precision, terrain, frame cost, seated transitions and the visible
fabric defects remain open acceptance work.

## Civilian acting update, November 5

Ordinary civilians can now receive Arjun's attacks through the central damage
policy. Mission actors and allied actors with external combat ownership retain
their existing protection. An unarmed direct assault can produce guarded
resistance, with an open-hand slap for female defenders by default and a punch
for other defenders. The defender closes a short distance with swept collision,
yields its guard pose during the attack, and applies damage once when the moving
hand physically reaches the receiver within the contact window. A threatening
weapon changes the response to fear and escape.

Indian street actors now install the dedicated running branch during setup.
The civilian escape pace is 2.8 m/s, which selects that branch. Live movement
continues through the existing queued navigation, terrain support and swept
collision owner. Existing bodily hit reactions interrupt travel, lethal hits
enter fall then down, and nonlethal collision falls retain recovery. The sari
keeps its retained source skin during fall/down/rise and restores its standing
envelope after recovery. Dedicated run contact, body contact and garment
deformation still require the asset-specific checks described above.

Existing peer conversations include two-hand gestures and warmer facial
expressions. Confirmed adult pairs can receive a flirtatious tone. Stable
personality seeds select the tone, with approximately one in five eligible
adult pairs warmer and one in thirteen pairs arguing. Arguments use faster,
higher gestures and anger, and visible nearby witnesses can retreat and seek
cover. Both participants leave the conversation through their existing journey
and cooldown. Roadside solid walls can provide cover without a registered home,
using upper- and lower-body sight checks before requesting a physical route.

The focused fixture includes player assault permission, mission protection,
slap timing and actual receiver contact, both-hand conversation, a smile,
argument witnesses, wall cover, lethal fall/down and interrupted activity
recovery. Procedural mouth motion remains silent acting rather than audio
phoneme synchronisation. Existing cloth edge, hairstyle and action-extreme
defects remain documented in the handoff.
