# Worktree integration ledger

This record tracks work being reconciled from Codex chats into the main TheLastMonsoon checkout. A description here is not a substitute for the source files, nor proof that changes have been tested or pushed. Keep each source worktree until its changes and recoverable working assets have been reviewed and verified in main. Record the exact validation and any remaining conflicts before marking an entry complete.

Updated: 2026-11-17T02:55:43.644707+05:30

| Source | Task or area | Main checkout status | Next action |
| --- | --- | --- | --- |
| `b4b6` | Provision shops: village and city shops, service ledger, gates, and map icons | Integrated into main; populated-world headless fixture passed, 18 new files verified byte-identical and conflict resolutions reviewed. Source worktree removed and its chat archived at user request. Earlier focused native roof review passed; broader art review remains open. | Historical task notes: [provision shop worktree record](../agent/history/2026-11-provision-shops-worktree.md). Review broader appearance in normal play. |
| `8b48` | Story, cinematics and dialogue | Community-message and witness daylight ownership integrated; focused populated-world contact, escort, restore and reward fixture passed. Rebellion and consignment mandatory-stage daylight ownership integrated; both focused headless story fixtures passed. The cinematic coach terrain-support guard and bounded follower detours are integrated. The rescue starts on the authored fort approach road, and populated travel checks pass for coach movement and rider synchronization. The full populated rebellion fixture passed after the rescue change on November 22, including all 11 fort-to-hideout waypoints and subsequent mission stages. | Broken masonry adapted to the current terrace flanks; focused collision and full populated route checks passed after installation. Version-2 breach follow saves now restart at the current route entrance; current saves keep their waypoint. Terrain-sampled shoulder meshes integrated and passed focused support checks. Coursed stone facing is integrated on the entrance piers and passage walls. The old curtain-wall remnants are adapted to the current route flanks; focused obstruction and center-clearance checks passed. Rebellion cinematics suppress ambient errand layers and restore their previous visibility, verified by the focused fixture. Opening DevStory also suppresses errand layers during cinematics; its focused fixture passed. Recovery dialogue uses the occlusion-aware Chacha camera; focused opening-story validation passed. The alternate ground-level alignment still needs a disposition before retirement. |
| `8eab` | Historical project work and assets | Not yet reconciled; source worktree retained. Initial inventory contains hundreds of differing or absent files, including old generated test output. | Classify source and authoring assets separately from disposable output, then reconcile changes with main. |
| `a7a8` | Arjun long-idle and related player changes | Idle source reconciled; focused and populated-world/Continue fixtures passed. Derived stance caches rebuilt from current inputs. Worktree removed and chat archived. Same-sole sprint drift still fails; native garment review remains open. | [Historical handoff](../agent/history/2026-10-long-idle-worktree.md); investigate sprint and garment fit in main. |
| `f9b2` | Mangal Pandey story sequence and related changes | Older HEAD is an ancestor of main and all source-only paths exist there, but eight story/test files differ and their exact old blobs are not in reachable Git history. Newer main changes need behavior-by-behavior comparison. Source worktree retained. | Compare each change with newer main and validate the ordered story route. |
| `40e5` | Horse mounting animation | Mirrored mount source and fixtures integrated into main. Native and headless transition fixtures, populated-world stable and morning tutorial pass. Fresh transition fixture passed on November 23; source checkout removed. Exact non-ignored source retained in local Git ref `refs/codex/archive/40e5`. | Review continuous lift and clothing fit at normal speed in main. |
| `4d05` | Crime pursuit and arrest | Main already contains the expanded response. All 52 focused perception checks passed on November 21, 2026. Worktree removed and chat archived. | [Historical handoff](../agent/history/2026-10-crime-pursuit-worktree.md). |

Completed chat summaries are recorded in [completed chat records](../agent/history/completed_chat_records.md).

Chat archival, Git integration, and worktree removal are separate actions. Archiving a chat does not merge its files; ignoring a file does not remove it from existing Git history. Do not mark a worktree safe to remove solely because it appears in this ledger.

## File inventory at last audit

Snapshot 2026-11-17T03:07:52.855443+05:30. Counts compare current working files by content, not semantic equivalence; they include tracked and untracked paths and may change while chats run. A missing file can be an intentional retirement or disposable output, not an instruction to restore it. Deleted paths are counted separately.

| Worktree | Identical | Different | Only in source | Deleted in source | Largest path groups |
| --- | ---: | ---: | ---: | ---: | --- |
| `8b48` | 0 | 17 | 2 | 0 | story: 10, tools: 5, docs: 3, (root): 1 |
| `8eab` | 0 | 174 | 568 | 0 | docs: 256, world: 247, tools: 107, characters: 76, WorkingAssets: 26 |
| `a7a8` | 0 | 23 | 16 | 0 | player: 18, tools: 9, characters: 8, docs: 3, (root): 1 |
| `b4b6` | 20 | 7 | 0 | 0 | assets: 8, world: 6, player: 5, ui: 3, docs: 2 |
| `f9b2` | 17 | 30 | 0 | 0 | story: 16, tools: 7, player: 6, world: 5, assets: 4 |

The current horse fixture incorporates the older worktree’s tack anchor checks. The horse now faces away from the family hitching rail at spawn. The populated-world headless fixture passed boarding through dismount and hoof-sound checks. The remaining changes in the old worktree still require review.

## November 23 batch comparison

All four worktree HEADs are ancestors of main. This pass compares their tracked and non-ignored local changes with the current main working files.

| Worktree | Equal or already carried | Conflicting or divergent | Missing before this pass | Clean three-way candidates |
| --- | ---: | ---: | ---: | ---: |
| 40e5 | 13 | 6 | 0 | 0 |
| 8b48 | 7 | 12 | 0 | 0 |
| 8eab | 2 | 169 | 568 | 3 |
| f9b2 | 21 | 26 | 0 | 0 |

Copied 24 editable Blender, texture and manifest files from 8eab, verified byte-for-byte and eligible for Git. The remaining 544 missing paths include old runtime source, tests, generated output and two archived fit records. The mechanically clean rifle and save changes use old police, well and city APIs. The prop documentation refers to historical placements and old capture paths. Those three edits remain pending review. A text conflict count includes histories, report files and binaries and does not imply the same number of missing behaviors.

### 8b48 scene decisions, 23 November

The current descending passage is the supported approach. It covers the old ground-level candidate's purpose with a buried foundation, terrain shoulders, dressed stone, an entrance threshold and working collision. Version-2 saves already migrate to the current approach. The old roof and threshold geometry is specific to the alternate route and should not be layered over the current passage. The training clock in main is scoped to lessons that have actually started, preserving ordinary time before training.

The celebration now follows the recorded speaker through the existing camera, retains Mangal's seated hand contact, and restores original face meshes when switching speakers or clearing the scene. Focused consignment voice, reward and skip checks passed. Native facial appearance remains unverified. The older briefing face animation is a separate outstanding comparison.

**8b48 retired on 23 November.** The remaining briefing face cue uses the actual recording and restores original face meshes across finish, restore and teardown. Final focused rebellion validation passed. The older alternate entrance and its exact camera assertions are superseded by the verified main route, saved checkpoint migration and current camera tests. The checkout was removed without a new archive or recovery ref.

**f9b2 retired on 23 November.** Current main retains the consignment and original story integration, later mounted presentation, route and save handling, and byte-identical portrait, icon and owner history. The focused consignment fixture passed on current main before removal. The obsolete checkout was deleted without a snapshot or new ref.

### 8eab crop authoring recovery

Main now holds the procedural crop mesh, wind shader, field layout and explicit-output baker. All three GDScript entry points passed Godot headless compile checks. The old baked scene was generated against older terrain. The recovered baker requires native rendering and a new absolute output path. A fresh bake against current terrain and native route/visibility review are required before registering it. The old well traversal needs an open, supported shaft because the current village well uses a solid cylinder. The existing water drawing routine remains active.

The recovered crop recipe baked all 15 plots against current terrain under native Metal on 23 November. The disposable scene was 4,524,797 bytes. Exit was clean and temporary output was removed. This verifies the authoring path. In-world crop placement and populated performance still require validation.

The workplace garment studies were consolidated into main as unregistered fit candidates. Four skinned character exports, linked textures and import settings, pose bank and build tools now sit alongside their editable Blender masters. All moved files matched the old checkout, GLB structures and image dependencies checked out, the pose driver compiled, and the working-file size/LFS check passed. Removed 37 byte-identical untracked duplicates from 8eab. Native regular-speed clothing/contact and activation remain unverified.

The older saddle-specific police uniform study now lives in main with its retained Blender masters, original reference, four skinned exports, texture inputs, shaders and rebuild recipe. Thirty-eight files matched the source checkout byte for byte and were removed from the old untracked directory. GLB structure and image dependencies, Python syntax, the Godot uniform finishing script, and Git size/LFS checks passed. The study remains inactive pending native riding and cloth review.

The earlier story draft and world audit from 1ce9 are retained under docs/story as historical source. Current character notes and story implementation take precedence. The generated world inventory report and already retired review captures were excluded.
