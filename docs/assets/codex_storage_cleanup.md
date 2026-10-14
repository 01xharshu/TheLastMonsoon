# Codex storage cleanup — 2026-10-12

User authorized removal of caches, temporary/redundant copies and direct integration of needed work.

First completed pass: removed 13.013 GiB of untracked, unopened Godot caches from inactive worktrees 15a3, 1ce9, 1dbd, 4df9, 584b, 6546, 9746, ceff, d4e5 and fabe. Original project cache and active/ownership-sensitive worktrees 296c, 8eab, f9b2 and 290b excluded. Removed unused untracked Python bytecode caches. Cache regeneration requires fresh imports when those old worktrees are opened.

Removed redundant a233 checkout: HEAD was an ancestor of main; only local change was CODEX_HANDOFF.md; no untracked or ignored files. Historical note retained in docs/agent/history/2026-10-12-retired-a233-worktree.md. No unique game implementation required merging.

Measured after Godot-cache and a233 removal: ~/.codex 39.645 GiB; worktrees 32.966 GiB; disk free about40 GiB. Remaining dirty worktrees contain unique historical implementations/assets and require file-by-file comparison against current contracts before integration/removal. Preserve editable sources and active owners. Chat histories, credentials/settings/databases, plugins and generated source images preserved. No blanket merge, Git storage rewrite or reset performed.

## Preserved source and retired copies

Original repository recovery refs preserve the full remaining source state; every retained file was checked against its Git blob before removing its checkout. Disposable media were removed using the reusable consumer-aware cleaner before snapshots. These refs are source recovery, not gameplay feature approval or completed feature merges.

- `15a3`: `refs/heads/codex/storage-recovery-20261012-15a3` (`108b29a3441b00a26bb649e95c262573265fa077`).
- `1ce9`: `refs/heads/codex/storage-recovery-20261012-1ce9` (`9a6dd31b09e0584ceb4e62b653b835d093a57206`).
- `36d7`: `refs/heads/codex/storage-recovery-20261012-36d7` (`faf41f4462627e11c21aea94def5432632a45118`).
- `4df9`: `refs/heads/codex/storage-recovery-20261012-4df9` (`de46e44fb9be4757a27edc827c89ae52b2fadd89`).
- `584b`: `refs/heads/codex/storage-recovery-20261012-584b` (`bce36eada7d0dd7f9022de37aa66a3dc39cbbeb0`).
- `6546`: `refs/heads/codex/storage-recovery-20261012-6546` (`83d9059950492c7749e877976453c8115974ab29`).
- `9746`: `refs/heads/codex/storage-recovery-20261012-9746` (`b351c0b9aa122dcf3eb54a605a1e10582fee7190`).
- `ceff`: `refs/heads/codex/storage-recovery-20261012-ceff` (`b7e683fcbb807100f7281869bbdf6ee2b0a538f6`).
- `d4e5`: `refs/heads/codex/storage-recovery-20261012-d4e5` (`0c7fd77271364f12d2758d0357174d54c6634cbd`).
- `fabe`: `refs/heads/codex/storage-recovery-20261012-fabe` (`9232a54ece471f82b1cb1f0583a9733ca752f1b9`).

- `290b`: all five implementation/test/doc changes byte-identical to original; redundant checkout retired. Handoff retained in `refs/heads/codex/storage-recovery-20261012-290b` (`80411d2ca6d46eed2f3a3dd9edfb4ed1f6419fb9`).

## Remaining protected storage

Active/ownership-sensitive worktrees296c (optimization),8eab (historical research) andf9b2 (rebellion integration) remain. Three pre-existing locked initializing registrations are not pruned during active Codex use. Chat sessions/archived sessions (~5.3GiB), credentials/settings/databases, plugins and generated source images remain. Unopened old catalog cache removed (~47MiB); recently active bundled-marketplace temporary cache retained.

All recovery refs are local source preservation in the original project repositories. They have not been pushed or merged as old gameplay implementations. Main branches and their existing staged/unstaged implementation changes were not overwritten. Original project imports and native jobs were not interrupted.

Project Made in India source was retained in its own original Git repository, including the ignored touring-cabin Blender master and backup. Its51ed unique parent commit remains reachable through its recovery ref.

- `1dbd`: `refs/heads/codex/storage-recovery-20261012-1dbd` (`0efced7ba1dc50f9a651b989a6a6d2fe1b95b308`).
- `51ed`: `refs/heads/codex/storage-recovery-20261012-51ed` (`5e4439d39eac35ab36dd53f7023c8f4f31397365`).

Final measurement: ~/.codex14231944KiB (13.57GiB), worktrees7276416KiB (6.94GiB); available disk~64GiB. Removed14 inactive worktrees;13 recovery commits verified to exist in the original repositories (11 TheLastMonsoon,2 Project Made in India). Main HEADs remain8bac978a and0d252a9 respectively.

## Continuation — 2026-10-13

Reconciled current main6e0ada13 and4 remaining real worktrees. Removed inactive296c generated `.godot` cache (~576MiB), after verifying no tracked files, symlink or open file handles. Source worktree retained. Current f9b2 active;8eab recently active;new a7a8 unfinished clothing/motion candidate retained. Prior source-recovery snapshots are not equivalent to completed feature ports. Scoped recovery audit underway.

296c retired on2026-10-13: `refs/heads/codex/storage-recovery-20261013-296c` (`827091268fa30d566f2d8b747738a7e184b8ac9d`), all3476 retained files verified against snapshot blobs. Initial verification compared through the original index and treated new snapshot files as deleted; full working-file/hash-set verification corrected that check. No source loss or main-index change. Consumer-aware disposable cleaner removed0files. Deferred cart fix ported; remaining cloth/render/profiler source stays recoverable without gameplay activation.

## Recovery disposition after current-main audit

The following distinction is explicit: source snapshots retain work; they do not mean every historical gameplay candidate has been merged. Current main and concurrent owners take precedence over older full-file replacements.

| Recovery | Current disposition |
| --- | --- |
|15a3|AreaArrival HUD component/UID and current-contract reusable check ported. Existing façade removals already contained. Old fort-outpost dressing still a candidate; current fort geometry differs substantially.|
|1ce9|Older story-planning documents retained; current Dev/rebellion/consignment story owns the latest narrative and implementation. No old narrative replacement applied.|
|36d7|Historical cleanup changes/notes retained; no unique runtime implementation to promote.|
|290b|Implementation/test/doc copies already identical to main; retired as redundant.|
|296c (20261013)|Functional delayed-cart restore, occupied priority, quick re-save and player-control hold ported; current identity/permission/doubled/cart-gravity contracts preserved. Physical boarding-completion and paid re-save/idempotence races repaired. Experimental cloth/render/shadow/profiling material retained as candidates.|
|4df9/ceff|Older startup/render/firearm/save optimization candidates retained. Shared runtime/save/firearm implementations have since changed; no wholesale replacement.|
|584b|Coastal lighthouse/watchtower source remains unmerged candidate. Requires current port geometry/support/traversal integration before activation.|
|6546|Communications/dak district source remains unmerged candidate. Requires current terrain, staffing/body, errands/identity/save contracts before activation.|
|9746|Crime/settings source largely superseded by current integration; older conflicts/import metadata retained only for recovery. No rollback of current mounted patrol/custody/sight.|
|d4e5/fabe|Old roster/editable character inputs and horse-parking/recall candidates retained. No replacement of current complete-body/foundation/motion/horse ownership contracts.|
|Project Made in India1dbd/51ed|Vehicle/cabin and cleanup sources remain in their own original repository's verified recovery refs. Separate current-project integration is not falsely marked complete.|

2026-10-13 final verified implementation checks: AreaArrival headless/native Metal PASS incl tutorial gating; actual-world morning tutorial PASS; cart delayed-spawn/queue/control/pause/paid re-save/replacement/idempotence/headless and native Metal PASS; final actual-world SaveManager Continue PASS (fresh world, passenger seat/destination,6rupees, full carts/patrols ready), zero script diagnostics. Tests use OS temporary directories and remove output; no screenshots/reports/logs/saves retained. Reusable runner: `python3 tools/world/run_cart_continue.py [--native] [--integrated]`. No commit/push or history rewrite performed.

Remaining3source checkouts8eab/a7a8/f9b2 retained for their unfinished owners. Unopened8eab/a7a8 `.godot` caches removed (1107224+790120KiB), with identical Git source status before/after and no tracked contents/open handles. Their next Godot use will reimport. Activef9b2 and original-main cache untouched; initializing registrations retained.

Final continuation measurement: `.codex`13005552KiB (**12.40GiB**), worktrees5940812KiB (**5.67GiB**); disk available86GiB. Overall15inactive worktrees removed across passes;14source-recovery commits remain reachable (12TheLastMonsoon,2Project Made in India), verified with `git cat-file -e <ref>^{commit}`. Remaining historical feature ports are explicitly open above. No owned test processes/output remain.
