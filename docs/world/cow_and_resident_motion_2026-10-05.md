# Cow realism and runtime care

Updated 2026-10-07 20:46 IST, current root chat. Status IN_PROGRESS.

Scope: refine the shared original cow used by the household and paired bullock carts, preserving editable source, 19-bone rig, physique and functional mouth/hoof targets. Completed earlier: broader face and connected jaw, fitted eyelid cuff, shaped cloven walls with 2 mm authored soles, layered coat variation, restrained udder, corrected cart yoke and wider bows. Historical focused contact and local Metal checks passed, including a two-minute walk/care cycle; test media/reports are removed and do not establish current approval.

Current continuation: thinner fitted ear surfaces and an authored subtle breathing morph, activated in both household and draft motion. Keep source and complete animal geometry; no outside model or imagery.

Files: `tools/animals/build_household_cow.py`, `WorkingAssets/Animals/household_cow/household_cow.blend`, `WorkingAssets/Animals/household_cow/manifest.json`, `assets/animals/cow/household_cow.glb`, `animals/cow_coat.gdshader`, `animals/cow_motion.gd`, `vehicles/bullock_cart.gd`. Reusable validators/review helpers under `tools/animals/` and `tools/world/`.

Output policy: temporary test output only, removed after success/failure/interruption. No retained screenshots, movies, logs or generated test reports. Reusable code and editable sources remain. Completed travelling jobs and their baseline remain documented in `travelling_opportunities.md`; existing opportunities remain active.

Current source hash: 83da679ce35a54d30af7cc639de2d3b98eb53644cab3134470eb39aaa60391c6, 40456 vertices / 19 bones / Breath morph. Editable Blender source and runtime export retained.

Known limits: fine hock/leg anatomy and coat realism, unrestricted normal-player/art acceptance, exact historical breed and whole-game performance remain open. Shared handoff checker can exceed cap due concurrent owner entries; preserve those entries. Earlier full-world draft test loaded during a river-script edit, then a retry did not complete before interruption; repeat bounded test before claiming a fresh pass.

Current verification: `python3 tools/animals/run_cattle_checks.py source contact draft_cow` PASS. All 35 mesh surfaces have UVs; imported morph displacement max 6.082 mm; 19 bones retained. Complete isolated care loop covers idle/walk/graze/feed/drink and verifies breathing cycles; muzzle contact max 4.71 mm. Actual paired bullock-cart fixture advances 600 idle/travel/turn steps, verifies both breathing ranges and finite bone poses; posed yoke gap 4.863 mm. This fixture uses flat collision ground, not the full freight route. The full-world draft check timed out at 90 seconds and remains unverified.

Fresh native Metal/mobile 960x540 head, quarter and full-inhalation views inspected: fitted thin ears appear attached; subtle flank change does not visibly distort the body. Animal remains stylized; this does not grant final art, normal-speed live-world or performance approval. Temporary images deleted immediately after inspection. Source builder adds editable UV islands; whole-project import still emitted unrelated/unattributed tangent UV diagnostics, while all own cow surfaces passed the direct UV check. `git diff --check` PASS.

Reusable no-output validators and caller-managed temporary review helper added. `tools/animals/run_cattle_checks.py` stops children on timeout/interruption, deletes its temporary directory, and runs legacy cleanup. Review code defaults to writing nothing; set `TLM_TEST_OUTPUT_DIR` only inside a caller-owned temporary directory with unconditional cleanup. No retained screenshots, movies, logs or generated reports.

Exact next action: refine shoulder-to-leg transitions, hock anatomy and coat response, then repeat temporary native moving review and bounded full-world cart route when world startup completes. In-game review route: household cattle shelter beside Bhairavpur House27, around (-321,289); observe normal idle/walk/graze/feed/drink cycle and rib breathing. Public bullock cart around (-403,225), freight road (-416,230) to (-386,230); use normal driver boarding and movement controls, inspect yoke/hoof fit while travelling and turning.
