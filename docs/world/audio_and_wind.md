# Sound coverage and shared wind — 2026-10-06

Status: broad action/ambience implementation and world behaviour checks PASS; owner listening and final visual/asset acceptance OPEN. This does not certify sound for every possible game event.

## Sound and contact

`systems/world_audio.gd` caches 25 action keys, six recorded footstep variants and caps simultaneous one-shot voices at 24. `systems/environment_audio.gd` uses eight positional fire-loop voices and one river voice; `systems/wind_system.gd` uses one wind player. All retire or mute when their scene/location is unavailable.

Arjun footsteps now trigger from newly accepted stance contacts in the existing locomotion foot solver, with a per-foot duplicate guard that rearms only after visible sole clearance. Distance timing remains for unsupported low stances and swimming. Nearby Indian, British, household and purpose actors use planted-side changes when their solver supplies them, with distance fallback. Cattle hoof contacts follow their actual stance acquisition. Collider/ancestor surface names and explicit `audio_surface` tags select material sounds; untagged ambiguous surfaces retain a dirt fallback. These sounds do not approve clothing or sole fit.

Successful inventory additions, treasure opening, water-pot/river filling, drinking, Satchel/document handling, blade/bow/melee contact, boat water strokes and flag cutting are connected. Currency uses a metallic handling cue. Hinged doors play only after collision accepts movement. Successful market sorting has a table-contact cue; completed office services have paper handling. Repeated completed paperwork produces no success sound. Fodder handling follows the actual transfer count; water bearers slosh while moving; cart frames creak while travelling. Existing firearm/horse/carriage/menu/bell/opening audio remains.

Generic player-dispatched interaction fallback indicates dispatch, not guaranteed transaction success. Quill sounds are bound to the seated writing candidate's pen contact and pause while responding, but the live offices currently install standing staff; no quill audio is falsely emitted there. Workshops without active tool animations remain quiet.

## Location/state ambience

Recorded fire plays only for nearby visible gathering-fire lights and stops when extinguished or remote. Recorded river water follows the closest bank and stops inland; roof exposure also lowers its level. Recorded house sparrows call intermittently at nearby mango canopies during daylight and adequate outdoor exposure. Live idle cattle vocalize occasionally; chewing/drinking cues require established mouth contact. Dead/knocked-out actors are suppressed. Fire and river loops use overlap-crossfaded WAV derivatives; starts are staggered.

[Audio credits](../../AUDIO_CREDITS.md) retain authors, source URLs and licences; original recordings/archive, SHA-256 checksums and reproducible processing are in `WorkingAssets/Audio/world_sources` and `tools/audio`. Cow and river field recordings are generic sound candidates recorded outside India; they are not claimed as exact local/breed recordings. House sparrows were recorded in India. Cattle chewing, hoof and cart/work contact textures remain synthesized candidates.

## Wind

Wind gradually changes strength/direction and supplies a travelling spatial gust field shared by grass, forest foliage, mango leaves, flags and Arjun's existing damped cloth spring. Displacement is transformed into each mesh's local space and roots stay fixed. Flag roots turn gradually into the wind, while their actual authored `wind` clip varies speed with local gusts. This remains an authored flutter animation rather than cloth simulation.

A four-per-second overhead-collision sample smooths camera shelter exposure and reduces wind audio, river noise and Arjun's cloth response indoors. Wind was reduced in the mix after the first world recording. This is an approximate roof test, not room acoustics or full wall occlusion. No wind force is added to player movement or ballistics.

## Verification and evidence

- Isolated audio/wind checks: 25 valid cached keys, six recorded footstep variants, 24 voice cap, ramp and spatial gust variation PASS.
- [Input-driven footstep checks](footstep_audio_validation.json): walking emits grounded material footsteps, standing and airborne motion stay silent, and the voice cap remains intact.
- [World environment checks](environment_audio_validation.json): fire on/off/distance, river distance, daylight bird scheduling, live cattle, successful/repeated paperwork, contact duplicate suppression and actual office-roof/open-lane wind exposure PASS headless.
- `tools/world/capture_audio_world_route.gd` records the live Suryagarh master mix across walking, river bank, cattle yard, office, night gathering fire and roadside wind; latest evidence: [video with sound](audio_world_route.mp4), [listening route](audio_world_listening.wav), [walking](audio_route_footsteps.png), [river](audio_route_river.png), [cattle](audio_route_cattle.png), [office](audio_route_office.png), [fire](audio_route_fire.png), [wind](audio_route_wind.png). Final native run/mix metrics are recorded in the validation report.
- The earlier isolated [wind motion fixture](wind_motion_review.mp4) remains useful for close grass/leaf/flag animation comparison. The current world route supplies in-world evidence.
- World capture uncovered a pre-existing fort chair-back `ArrayMesh.size` error. The sizing call now scales the mesh using its bounding-box height. First native route completed with Metal fence timeouts; the final route uses an early 1280x720 window and completes without script errors, but still logs one Metal fence timeout. Full-world performance acceptance remains open. The recording predates the final sole-clearance rearm guard; that guard has its own input-driven regression.

Open gates: owner listening/mix/naturalness acceptance; final character/clothing/contact art; exact local cattle/water asset preference; seated writing and active workshop animations owned by their character/work scopes; wall occlusion/underwater acoustics and species-specific night ambience. Do not represent structural checks, sample levels or screenshots as those approvals.
