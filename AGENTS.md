# Agent read order

1. Read `CODEX_HANDOFF.md` for current status, failures and the exact next action.
2. Inspect `git status --short` and the exact files involved before editing; concurrent assets are often dirty.
3. Open only the relevant section or file from `docs/README.md`. Use `rg` to locate code. The long root `README.md` is project vision, not a live task log.
4. Keep `CODEX_HANDOFF.md` brief and current. Move finished detail to a focused document or dated history file; retain evidence paths and unresolved failures.
5. Do not equate structural checks with rendered appearance, motion/contact, or final asset approval.

## Evidence and source retention

- Keep the latest screenshots needed to demonstrate current work and unresolved defects. Replace superseded captures for the same view; retain distinct evidence that is still needed. Update evidence links when removing a capture.
- Keep useful editable Blender sources, active candidates and source assets required by exports or rebuild scripts. Delete established obsolete or unused sources and redundant Blender backups after checking references and recording the retained replacement. Age alone does not establish that a file is unused.

## Universal human creation rule

- Every human, including drivers, NPCs and placeholders, must be created with the MakeHuman/MPFB extension in Blender. Reuse an existing MakeHuman character or create a new one through that extension.
- Do not construct human bodies or human placeholders from Blender primitives, boxes, spheres, or procedural block meshes. This rule applies to every human creation task in this project.

## Complete human body beneath clothes

- Every human used in the game must retain their complete MakeHuman/MPFB body beneath all clothing, in editable assets and runtime exports. This includes player characters, NPCs, drivers, staff and placeholders.
- Disable clothing-driven body masks and do not delete covered body surfaces. Exclude only non-human MPFB helper geometry. Preserve the same physique under every outfit; fix intersections by fitting clothing.
- Retain separate opaque foundation garments for clearly adult characters. Full-body topology does not grant clothing/deformation/contact approval.
