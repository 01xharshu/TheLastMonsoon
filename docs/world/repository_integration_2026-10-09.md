# Repository-wide storage and gameplay integration — 9 October 2026

Scope: verify commit/push storage and recent gameplay wiring across the shared checkout. Preserve the active household, forest and other asset owners. Focused integration checks do not establish visual, cloth/contact, device, performance or whole-game approval.

## Applied fixes

- The new clerk physics candidate produced 242 UV-less morph tangent errors in a clean import. Its `.glb.import` now uses the existing safe tangent importer. No body, clothing, morph or rig geometry changed.
- Tangent preservation now discovers every runtime GLB opting into safe imports instead of relying on a fourteen-asset list. The clean-copy check found fifteen assets and passed 151 surfaces / 4,267 morph surfaces.
- Storage guards cover every staged asset type, required literal runtime resource paths, LFS tracking/pointers, and historical blobs in outgoing commits. New changed GLBs with UV-less morphs must include safe import settings and the enabled plugin. `install_storage_hooks.py` installs both guards once per clone without replacing unrelated custom hooks. Eight disposable regression fixtures passed.
- `check_game.py --integration` adds mobile input lifecycle, AnimationTree, inquiry/custody story, title-to-world sky, city route population and normal intro/movement checks. The runner chooses host-appropriate native/export options and supports an explicit compatibility-renderer check. Copying rejects files that change mid-copy; test output remains temporary.

## Current results and unresolved failures

Current baseline: main `3eda3bb7` plus the active startup-loading changes. Local and remote main match. Earlier 240-second Metal waist-readback failure is superseded: the household owner now supplies offline body-derived waist profiles, and native world startup no longer emits those fence errors.

Latest native full integration run passed clean import; all 728 GDScripts / 45 shaders; fifteen tangent assets (151 surfaces / 4,267 morph surfaces); eight independent human-cache models; 128 contact comparisons; studio-ident-to-title startup; mobile input; AnimationTree; draft-team detach/reattach/death behavior; inquiry/custody; New Journey and Continue sky wiring; city population; and normal intro/movement. City population: 72 walkers, 10 police and 8 carts; 64 walkers, 9 police and 7 carts progressed. Eight walkers and one cart did not meet the motion threshold; the existing aggregate gate passed, not every individual journey. Whole-game FPS and art/contact remain open.

Final native source/pack rerun PASS with exit 0 and no diagnostics: clean import; all 735 GDScripts / 45 shaders; tangent/cache/contact checks; actual studio startup/title; world intro skip and movement through three districts; aiming and Enfield reload; save/read/restore; graceful shutdown; export; and isolated packed-world run from an empty folder. Native world readiness was 49.868 s (route 80.1 s); packed readiness 30.685 s (route 84.3 s). The packed check uses the headless backend; the source check uses Metal. These shared-host timings are not FPS or performance approval.

Rifle failures were test-context/timing defects: native input was not captured and a short wall-clock wait advanced too little clamped simulation time. The fixture now focuses/captures the window, uses a bounded 90-second reload wait and records simulated delta. Native reload completed with one round after 1.581 simulated seconds / 20 frames; packed reload completed after 1.533 simulated seconds / 92 frames. No combat timing, ammo, capacity or availability rule changed.

The prior transient import crash (-11) was not reproduced by subsequent clean imports. Test-shutdown audio leaks were fixed by using the game's graceful shutdown path. The sky test now waits for the real journey overlay to retire before freeing its world; startup tests follow the configured studio scene instead of bypassing it. Temporary projects, packs, logs and user data are deleted after each run.

## Remaining scope

Art, full-body/clothing/contact approval, per-route blockage, device builds, FPS/memory budgets and ongoing owners’ edits remain outside this functional baseline. The native city gate allowed eight walkers and one cart below its movement threshold; do not label all NPC journeys perfect. The checks cover a disposable snapshot of the shared checkout, not an independently rebuilt Blender clone or every story/combat path.

## Reproduce

Run `python3 tools/maintenance/install_storage_hooks.py` once per clone, then `python3 tools/maintenance/check_push_sizes.py` before staging. Commit hooks check the index; push hooks check outgoing history. Run `python3 tools/maintenance/check_game.py --integration --packed --native` for the full current gate, using `--godot` when needed. Headless or `--compatibility` results do not certify Metal/Vulkan. All temporary projects, exports, logs and user data are deleted after success, failure or interruption.

For user play review after native startup is fixed: New Journey → watch intro → move to rise → follow the Dev inquiry → use the chacha tutorial → walk/ride through village, Civil Lines and cantonment → aim/reload → save and Continue → return to title and Quit. Check visible contact and continuity during those actions; code/resource checks alone do not establish them.
