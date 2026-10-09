# Sound coverage and shared wind — 2026-10-07

Status: broad action/ambience implementation retained; 2026-10-07 bounded asset/player/environment checks PASS. Fresh full-world environment run timed out before assertions at 180 seconds; integration, owner listening and final visual/asset acceptance OPEN. This does not certify sound for every possible game event.

## Sound and contact

`systems/world_audio.gd` caches 25 action keys, six recorded footstep variants and caps simultaneous one-shot voices at 24. `systems/environment_audio.gd` uses eight positional fire-loop voices and two bounded river/current-bank voices; `systems/wind_system.gd` uses one wind player. Environment loops retire or mute when their scene/location is unavailable. Failed or voice-capped dispatch does not count as an emitted ambience event.

Arjun footsteps now trigger from newly accepted stance contacts in the existing locomotion foot solver, with a per-foot duplicate guard that rearms only after visible sole clearance. Distance timing remains for unsupported low stances and swimming; grounded fallback now uses the same tagged/ancestor material lookup and swimming retains its splash sound. Nearby Indian, British, household and purpose actors use planted-side changes when their solver supplies them, with distance fallback. Cattle hoof contacts follow their actual stance acquisition. Collider/ancestor surface names and explicit `audio_surface` tags select material sounds; untagged ambiguous surfaces retain a dirt fallback. Inactive, dead and knocked-out NPCs do not emit movement sounds. These sounds do not approve clothing or sole fit.

Successful inventory additions, treasure opening, water-pot/river filling, drinking, Satchel/document handling, blade/bow/melee contact, boat water strokes and flag cutting are connected. Currency uses a metallic handling cue. Hinged doors play only after collision accepts movement. Successful market sorting has a table-contact cue; completed office services have paper handling. Repeated completed paperwork produces no success sound. Fodder handling follows the actual transfer count; water bearers slosh while moving; cart frames creak while travelling. Existing firearm/horse/carriage/menu/bell/opening audio remains.

Generic player-dispatched interaction fallback indicates dispatch, not guaranteed transaction success. Quill sounds are bound to the seated writing candidate's pen contact and pause while responding, but the live offices currently install standing staff; no quill audio is falsely emitted there. Workshops without active tool animations remain quiet.

## Location/state ambience

Recorded fire plays only for nearby visible gathering-fire lights and stops when extinguished or remote. Recorded river water follows the closest bank and stops inland; roof exposure also lowers its level. Recorded house sparrows call intermittently at nearby mango canopies during daylight and adequate outdoor exposure. Live idle cattle vocalize occasionally; chewing/drinking cues require established mouth contact. Dead/knocked-out actors are suppressed. Fire and river loops use overlap-crossfaded WAV derivatives; starts are staggered.

[Audio credits](../../AUDIO_CREDITS.md) retain authors, source URLs and licences; original recordings/archive, SHA-256 checksums and reproducible processing are in `WorkingAssets/Audio/world_sources` and `tools/audio`. Cow and river field recordings are generic sound candidates recorded outside India; they are not claimed as exact local/breed recordings. House sparrows were recorded in India. Cattle chewing, hoof and cart/work contact textures remain synthesized candidates.

## Wind

Wind gradually changes strength/direction and supplies a travelling spatial gust field shared by grass, forest foliage, mango leaves, flags and Arjun's existing damped cloth spring. Displacement is transformed into each mesh's local space and roots stay fixed. Flag roots turn gradually into the wind, while their actual authored `wind` clip varies speed with local gusts. Flag updates continue even while no camera is active. This remains an authored flutter animation rather than cloth simulation.

A four-per-second overhead-collision sample smooths camera shelter exposure and reduces wind audio, river noise and Arjun's cloth response indoors. The current mix retains the later near-field audibility adjustments. This is an approximate roof test, not room acoustics or full wall occlusion. No wind force is added to player movement or ballistics.

## Verification and in-game review

Reusable checks: `python3 tools/world/run_audio_checks.py`; `--quick` runs the bounded asset/player/environment checks without loading Suryagarh. Add `--native-route` for a six-location Forward+/Metal route. The runner gives concise console results and deletes temporary logs, frames and recordings on completion or interruption; no report is written into the checkout. The capture script requires the runner's temporary output directory. Editable sound sources, licence manifests and runtime WAV assets are retained.

Current quick checks PASS: cached recordings and voice limits; tagged ground material; walking, standing and airborne footsteps; fire state/distance; river distance; day/night bird calls; missing-camera/clock loop retirement; actual flag asset grounding/alignment and gust-driven authored flutter with no camera. Full-world tests additionally cover bird voice attenuation reset, cattle, successful/repeated paperwork, duplicate foot contacts and actual office shelter, but their current run timed out before assertions. These functional checks do not approve sound naturalness or final visual motion.

`git diff --check` passes. The shared handoff size check currently fails (51 lines, over 6000 characters); concurrent owner entries remain preserved.

Historical native route completed six locations without script errors but reported one Metal fence timeout. Its disposable media/reports have been removed and are not current evidence. Full-world performance acceptance remains open.

To review in-game:

1. Start or continue Suryagarh. Walk, stop and jump on dirt, tagged stone and timber surfaces; footsteps should follow planted steps, stop when standing and stay silent while airborne. Low-stance fallback should retain surface material; swimming should splash.
2. Walk toward and away from the river and a lit evening gathering fire. Their level should follow location and fire state. Listen near mango trees by day; daytime bird calls should cease at night. Visit the cattle yard for occasional idle calls and contact-driven feeding/drinking cues.
3. Complete an available office service and repeat it: successful paperwork should sound once. Try a blocked door movement: collision-rejected motion should remain silent.
4. Watch grass, mango leaves and roadside flags for at least a minute. Poles should stay rooted while cloth direction gradually follows the breeze and flutter speed changes with gusts. Enter an office then return outdoors: wind sound and Arjun's existing cloth response should ease under the roof and recover outside.

Open gates: owner listening/mix/naturalness acceptance; final character/clothing/contact art; exact local cattle/water asset preference; seated writing and active workshop animations owned by their character/work scopes; wall occlusion/underwater acoustics and species-specific night ambience. Do not represent structural checks or sample levels as those approvals.

River follow-up: [river flow realism](river_flow_realism.md) adds stronger upper-reach current sound and shoreline wash tied to the actual bank, plus current/wave gameplay. Full Suryagarh environment-audio regression now PASS; the earlier startup timeout is superseded for that check.
