# Third-person reference framing — 2026-09-28

The requested screenshot defines the ordinary walking view: behind Arjun, with his head near the left third of the image and a clear view of the path ahead. The chosen camera has a 0.55 m pivot height, -10° initial pitch, 1.25 m spring length, 0.60 m right offset, and 75° field of view. Aiming keeps its separate closer framing. The camera distance remains adjustable in Settings (1.25–4.0 m); saved 1.8 m and 2.0 m former defaults migrate to 1.25 m.

The existing local `user://settings.cfg` had a custom 2.9 m distance that would override this request. Its camera distance was set to 1.25 m; other settings were left as they were.

Evidence: `/tmp/tlm_reference_camera_rear.png` is a fresh Godot 4.7.2 Metal/Forward+ capture using the saved distance and actual player camera; rear composition was inspected against the supplied screenshot. `tools/characters/validate_camera_controls.gd` passed (`/tmp/tlm_reference_camera_controls_final.log`). `tools/world/validate_world_camera_clearance.gd` passed at both Government House wall cases with no collider hit (`/tmp/tlm_reference_camera_clearance_final.log`). The latter fixture now compares camera distance to the configured spring length instead of a fixed 1.5 m threshold. `git diff --check` passed. `python3 tools/check_agent_docs.py` now fails only on the shared handoff's 6 KB limit; concurrent task sections expanded while this task was running, and their owners should condense them.

The screenshot's landscape, fort, lighting, and costume are reference content, not camera parameters. The capture checks stationary outdoor framing and two indoor obstructions; moving camera motion and every interior angle remain for owner play review.
