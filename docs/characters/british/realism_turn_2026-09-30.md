# British NPC iris and stepping-turn revision — 30 September 2026

Status: **RUNTIME_IMPLEMENTED / STRUCTURAL_PASS / VISUAL_CONTACT_OPEN**.

## Eye export correction

The MPFB eye shader uses a MixRGB tint. The runtime exporter classified that connection as procedural fabric and disconnected its image, producing white eyes. `tools/characters/export_british_roster.py` now gives each eye mesh a direct image-to-base-color material using the original MPFB iris map and 0.35 roughness. This correction preserves the editable Blender source shader.

All eight pairs (sixteen independent GLBs) were re-exported and imported. Embedded eye validation (test output deleted) PASS: each GLB has an authored iris material, nonblank 1024×1024 image with dark pupil pixels, and matching source/runtime hashes. Tool: `tools/characters/validate_british_eye_exports.py`.

Fresh Godot 4.7.2 Forward+/Metal closeups were inspected:

Male iris (test output deleted)

Female iris (test output deleted)

Face surfaces, brows, hair and headwear remain art candidates. Correct iris pixels do not approve body realism or identity.

## Tree-driven stepping turn

Endpoint reversals previously rotated the root through 180° while playing idle. The personal tree now includes a half-second `turn` clip, progress-driven TimeSeek and final `turning` Blend2. It blends in over 0.08 s. Alternating thigh/knee/ankle rotations lift one foot and then the other while counter-rotating the ankle. The walk cadence and foot-plant branches are retained.

Turn validation (test output deleted) PASS for all sixteen: both ankles lift 0.027–0.036 m, turn weight reaches 1, roots remain at the endpoint, facing reverses, and the next steps follow the expected direction. Tree playback/idle recovery/independent stop, cadence, full-patrol foot planting and runtime separation also passed after re-export. These are measured skeleton/behavior checks, not mesh sole friction or continuous contact approval.

Fresh Suryagarh Metal frames at both lift phases were inspected:

Male first lift (test output deleted)

Male second lift (test output deleted)

Female first lift (test output deleted)

Female second lift (test output deleted)

Capture tool: `tools/characters/capture_british_stepping_turn.gd`; default selects PrivateMan, `-- --female-only` selects PrivateWoman, and `--face` adds a closeup. These 1280×720 views are paused samples in the actual world. They do not approve normal-speed turning. The skirt conceals female feet and remains rigid; support-foot pivot/contact and weight transfer require further refinement. Actual 8GB-device performance remains unmeasured.
