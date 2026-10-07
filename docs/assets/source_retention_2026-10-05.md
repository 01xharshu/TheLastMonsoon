# Source and evidence retention — 2026-10-05

Historical record. Capture retention is superseded by the [2026-10-07 user policy](repository_storage.md); redundant backups and historical Leela snapshots were subsequently removed.

The project now follows the evidence/source retention rule in root `AGENTS.md`: keep current useful evidence and editable sources; remove established superseded sources and redundant backups after recording their retained replacements.

## Applied cleanup

Blender's library directory reader validated the retained `.blend` source files before cleanup. Removed 36 automatic `.blend1` backups and three superseded unsuccessful Arjun studies: continuous drape, drape/boots, and hair clumps. Their rejected-study builders were subsequently retired on 2026-10-07; the residual/projected-drape inputs and later sculpted/material/eye/boot chain are retained. None of the removed studies is a downstream builder input. Existing character/runtime files and foundation sources remain. This source read does not establish visual approval.

Reclaimed **399,415,889 bytes** (399.4 MB / 380.9 MiB). The audit retains 78 files, including backups belonging to concurrent modified sources. Removal SHA-256 hashes, reasons, validated replacement paths, and retained file inventory are in [the audit JSON](source_retention_2026-10-02.json). The JSON filename records the audit's start date; its applied date is 2026-10-05. All listed removals are absent and all listed retained files exist.

The dated source-audit script was retired on 2026-10-07 after its cleanup completed. Its historical results remain above. Active source files and rebuild dependencies are retained.

## Building evidence

Current building captures use fixed view filenames at 1280 × 720, replacing older captures of the same view. Nine distinct exterior/interior views are useful for the current refinement. Capture inventory and evidence details are in `docs/world/building_realism_2026-10-01.md`. Other active tasks' screenshots remain because they demonstrate separate work or unresolved defects.
