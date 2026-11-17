# Worktree integration ledger

This record tracks work being reconciled from Codex chats into the main TheLastMonsoon checkout. A description here is not a substitute for the source files, nor proof that changes have been tested or pushed. Keep each source worktree until its changes and recoverable working assets have been reviewed and verified in main. Record the exact validation and any remaining conflicts before marking an entry complete.

Updated: 2026-11-17T02:55:43.644707+05:30

| Source | Task or area | Main checkout status | Next action |
| --- | --- | --- | --- |
| `b4b6` | Provision shops: village and city shops, service ledger, gates, and map icons | Integrated into main; populated-world headless fixture passed, 18 new files verified byte-identical and conflict resolutions reviewed. Source worktree removed and its chat archived at user request. Earlier focused native roof review passed; broader art review remains open. | Historical task notes: [provision shop worktree record](../agent/history/2026-11-provision-shops-worktree.md). Review broader appearance in normal play. |
| `8b48` | Story, cinematics and dialogue | Community-message and witness daylight ownership integrated; focused populated-world contact, escort, restore and reward fixture passed. Rebellion and consignment mandatory-stage daylight ownership integrated; both focused headless story fixtures passed. Other cinematic and rebellion changes still conflict with newer main; source worktree retained. | Reconcile remaining story and dialogue-camera changes with current main and validate ordered routes. |
| `8eab` | Historical project work and assets | Not yet reconciled; source worktree retained. Initial inventory contains hundreds of differing or absent files, including old generated test output. | Classify source and authoring assets separately from disposable output, then reconcile changes with main. |
| `a7a8` | Arjun long-idle and related player changes | Idle source reconciled; focused and populated-world/Continue fixtures passed. Derived stance caches rebuilt from current inputs. Worktree removed and chat archived. Same-sole sprint drift still fails; native garment review remains open. | [Historical handoff](../agent/history/2026-10-long-idle-worktree.md); investigate sprint and garment fit in main. |
| `f9b2` | Mangal Pandey story sequence and related changes | Older HEAD is an ancestor of main and all source-only paths exist there, but eight story/test files differ and their exact old blobs are not in reachable Git history. Newer main changes need behavior-by-behavior comparison. Source worktree retained. | Compare each change with newer main and validate the ordered story route. |
| `40e5` | Horse mounting animation | Active worktree, not retired; visual fit and lift remain unfinished. | Complete and validate the animation before reconciling it with main. |
| `4d05` | Crime pursuit and arrest / other prior work | Was active at the previous audit; not yet reconciled or retired. | Recheck chat status and source ownership before integrating. |

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
