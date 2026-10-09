# Repository-wide storage and gameplay integration — 9 October 2026

Scope: verify commit/push storage and recent gameplay wiring across the shared checkout. Preserve the active household, forest and other asset owners. Focused integration checks do not establish visual, cloth/contact, device, performance or whole-game approval.

## Applied fixes

- The new clerk physics candidate produced 242 UV-less morph tangent errors in a clean import. Its `.glb.import` now uses the existing safe tangent importer. No body, clothing, morph or rig geometry changed.
- Tangent preservation now discovers every runtime GLB opting into safe imports instead of relying on a fourteen-asset list. The clean-copy check found fifteen assets and passed 151 surfaces / 4,267 morph surfaces.
- Storage guards cover every staged asset type, required literal runtime resource paths, LFS tracking/pointers, and historical blobs in outgoing commits. New changed GLBs with UV-less morphs must include safe import settings and the enabled plugin. `install_storage_hooks.py` installs both guards once per clone without replacing unrelated custom hooks. Eight disposable regression fixtures passed.
- `check_game.py --integration` adds mobile input lifecycle, AnimationTree, inquiry/custody story, title-to-world sky, city route population and normal intro/movement checks. The runner chooses host-appropriate native/export options and supports an explicit compatibility-renderer check. Copying rejects files that change mid-copy; test output remains temporary.

## Current results and unresolved failures

Clean import, fifteen tangent-preservation assets, eight human-cache models, 128 contact-search comparisons and native title-menu smoke passed. Native Metal world smoke timed out at 240 seconds, with 21 fence timeout errors at `household_waist_fit.gd:16` (`surface_get_arrays`), through household drape/passenger configuration. World readiness was printed after 106.794 seconds; the movement/reload/save/load route did not complete. The household owner received this exact dependency; their actively edited clothing files remain untouched by this pass.

A subsequent expanded copy crashed during import with exit -11 before gameplay. Cause is not established. A fresh attempt with stable-file copying is running. Expanded gameplay and exported-pack results remain pending; previous historical PASS statements do not certify this current checkout.

## Reproduce

Run `python3 tools/maintenance/install_storage_hooks.py` once per clone, then `python3 tools/maintenance/check_push_sizes.py` before staging. Commit hooks check the index; push hooks check outgoing history. Run `python3 tools/maintenance/check_game.py --integration --packed --native` for the full current gate, using `--godot` when needed. Headless or `--compatibility` results do not certify Metal/Vulkan. All temporary projects, exports, logs and user data are deleted after success, failure or interruption.

For user play review after native startup is fixed: New Journey → watch intro → move to rise → follow the Dev inquiry → use the chacha tutorial → walk/ride through village, Civil Lines and cantonment → aim/reload → save and Continue → return to title and Quit. Check visible contact and continuity during those actions; code/resource checks alone do not establish them.
