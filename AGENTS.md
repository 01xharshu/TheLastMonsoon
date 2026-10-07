# Agent read order

1. Read `CODEX_HANDOFF.md` for current status, failures and the exact next action.
2. Inspect `git status --short` and the exact files involved before editing; concurrent assets are often dirty.
3. Open only the relevant section or file from `docs/README.md`. Use `rg` to locate code. The long root `README.md` is project vision, not a live task log.
4. Keep `CODEX_HANDOFF.md` brief and current. Move finished detail to a focused document or dated history file; retain evidence paths and unresolved failures.
5. Do not equate structural checks with rendered appearance, motion/contact, or final asset approval.

## Assignment completion and coordination

- Continue the chat's existing assigned responsibility through implementation, integration and verification. Establish a usable in-game baseline, then complete the remaining scope; realism may be delivered in focused batches. Include applicable AnimationTree wiring, transitions, motion, clothing fit and contact in that responsibility.
- Do not stop at an inventory of missing work, a plan, structural checks, or an intermediate candidate when actionable assigned work remains. Continue fixing and reviewing. Report completion only with evidence; retain honest unresolved defects and identify any genuine blocker that cannot be resolved autonomously.
- Do not pause another chat, interrupt its work, or repeatedly request status. Send a message only to the specific owner when an actionable dependency, shared-file conflict, required decision or integration handoff makes it necessary. Do not request acknowledgements or routine replies to coordination messages.
- Preserve existing ownership and concurrent changes. Status/coordination chats must not take over another owner's files merely to make progress; resolve their own assigned scope and contact an owner only when needed.

## Test output and source retention

- User policy (2026-10-07): do not retain test screenshots, videos, recordings, logs or generated test reports. Prefer a concise result in chat and exact instructions for the user to test in-game. Keep reusable test code.
- Use an OS temporary directory for test output and delete it in a finally/exit cleanup after success, failure or interruption. If legacy tools write into the checkout, run `python3 tools/maintenance/clean_test_artifacts.py --apply` afterward and remove any other output created by that run. Do not commit generated test artifacts.
- Existing documentation may describe historical checks; removed captures/reports do not provide current evidence or final approval. Record unresolved defects honestly in concise text.
- Keep useful editable Blender sources, active candidates, textures, references and rebuild inputs. Remove established obsolete copies and redundant backups only after checking dependencies and retained replacements. Never ignore all `.blend` files: a recoverable clone needs its editable sources.
- Do not use Git history as a backup for disposable output. History migration and asset storage changes must preserve a verified fresh-clone rebuild; see `docs/assets/repository_storage.md`.

## Universal human creation rule

- Every human, including drivers, NPCs and placeholders, must be created with the MakeHuman/MPFB extension in Blender. Reuse an existing MakeHuman character or create a new one through that extension.
- Do not construct human bodies or human placeholders from Blender primitives, boxes, spheres, or procedural block meshes. This rule applies to every human creation task in this project.

## Complete human body beneath clothes

- Every human used in the game must retain their complete MakeHuman/MPFB body beneath all clothing, in editable assets and runtime exports. This includes player characters, NPCs, drivers, staff and placeholders.
- Disable clothing-driven body masks and do not delete covered body surfaces. Exclude only non-human MPFB helper geometry. Preserve the same physique under every outfit; fix intersections by fitting clothing.
- Retain separate opaque foundation garments for clearly adult characters. Full-body topology does not grant clothing/deformation/contact approval.
