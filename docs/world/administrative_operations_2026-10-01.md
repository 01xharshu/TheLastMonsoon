# Administrative offices: operations and review

Main-world Collectorate, District Treasury and British Courthouse, 2026-10-01. No building names, room labels or posted notices are introduced. Service descriptions appear only in the contextual HUD.

## Implemented gameplay

Three entrance pairs now use the existing physical hinged-door system: timber boards and iron pulls move with colliders, swept actor protection, player latch action, night lock and inside egress. Office entrances lock at 20:00 and reopen at 06:00. Treasury rear partition now has a closed physical paired strongroom door and header; public-side access is denied, with inside egress retained. Strongroom lock cannot be bypassed merely by waiting for dawn. This is staff-only access; key acquisition, picking and a robbery mission are not authored.

Three Indian clerk candidates and a British presiding officer candidate use independent existing rigs. Clerks stand beside desks without occupying chair or tabletop geometry. The clerk interactions are nearby contextual prompts. Living staff are required. Source models are `characters/npcs/households/merchant.glb` and `characters/npcs/british/official_man.glb`; these are reused candidates, not new approved office costumes or named identities.

The Collectorate issues a petition receipt once. Court registration requires and consumes that receipt, replacing it with a court registration. Treasury accepts one fictional two-rupee recorded revenue payment and issues a revenue receipt. Insufficient funds and missing petition receipt do not complete a transaction. Repeat interactions explain that the transaction is already recorded and do not duplicate documents or money. All three services operate from 09:00 to 17:00. Documents use the shared inventory collection feed and are saved along with service completion. Existing door open/closed persistence is retained. Old saves with no office state start with unused services.

These hours, one-time transactions and two-rupee amount are authored prototype rules, not documented historical tariffs or procedures. This is paperwork registration, not an adjudicated hearing or land-revenue simulation. Clerk writing, seated judge acting, queues, guard patrols and arrest/theft responses remain a separate presentation/gameplay pass.

## Verification and evidence

`tools/world/validate_administrative_operations.gd` validates transactions, repeat protection, JSON state, actual SaveManager save/load in an isolated validation save directory, closed hours, physical closed-door collision, completed door swings and denied treasury access. Native camera review uses `tools/world/review_administrative_camera.gd`: actual player movement input, original player camera, continuous entrance-to-interior routes, pivot-to-camera rays and camera-volume overlap probes. Checks and rendering have separate results; the camera report is `administrative_camera_review.json` when generated.

## Historical and art review

Contemporary primary reference: [Hansard, Administration of Justice in India—Petitions, 26 June 1857](https://api.parliament.uk/historic-hansard/lords/1857/jun/26/administration-of-justice-in-india). The debate distinguishes Company's courts from Queen's courts and discusses revenue collectors, magistrates and judges. It establishes contemporary institutional terminology, not this fictional office plan, service chain, tariff, staff costume or opening hours. The speakers' colonial opinions are not adopted as neutral history.

Owner review remains open for roof forms, veranda proportions, lime/timber weathering, shutters and hinges, treasury security construction, desk/chair/folio proportions, clerk and officer costumes, and whether the building identities read clearly without signs. Province-specific 1857 architectural and costume sources are still needed before exact historical approval. Do not mark final art/historical acceptance from passing code tests. Target 8 GB hardware and broader approach/terrace routes are also open.

## Continuation — 2026-10-05

PASS: three clerk services are selected through the regular player interaction search. Conversation targets now sit on the public side, above floor level, rather than behind staff collision at their feet. Missing court paperwork, insufficient treasury money, unavailable staff, duplicate requests, office hours and actual isolated SaveManager save/load pass. The existing player latch action releases and fully opens all three office doors; the check waits for completion with a bounded timeout. Report: [operations validation](administrative_operations_validation.json).

Latest native Forward+/Metal camera run: six continuous entry/exit legs across the three offices, including gradual camera turns, actual regular movement input and 183 sampled rendered frames. Zero blocked pivot-to-camera segments and zero camera-volume overlaps. [Camera report](administrative_camera_review.json) and [25-second walkthrough](captures/administrative_player_walkthrough.mp4). Encoded timing follows physics frames; transition placement between buildings is scripted. Current endpoint captures replace superseded views. Inspected route frames show clear doorways and central aisles; these do not approve clothing, performance or all possible camera positions. Render review uses half-resolution 3D rendering, rather than a target-hardware performance claim.

Reproduce with `python3 tools/characters/audit_administrative_staff.py`, then Blender background `--python tools/characters/audit_administrative_staff_sources.py`. Runtime and editable staff sources are checked without changing the existing identities or exports: [body audit](administrative_staff_body_audit.json). Each runtime body has 14,517 skinned exported vertices; each editable body evaluates to 13,380 body vertices after helper exclusion. Exported vertex counts include splits at surface attributes. Clothing body masks are disabled and separate opaque skinned foundation garments remain. Human bodies are reused MPFB assets; no primitive humans are introduced. Costume, seated/writing actions and owner historical/art approval remain open.
