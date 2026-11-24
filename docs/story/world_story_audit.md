# Story V1 — current-world implementation audit

Updated: 2026-09-30 16:12 IST. Task: current Codex story/world audit chat.
Status: **COMPLETE for the requested inventory and story correction**. The current integrated game has a runtime blocker described below.

Scope: compare the complete main-world route, player systems, NPC placement/behaviour and available story assets against [Story V1](story_v1.md). No new gameplay was implemented. The station incident now explicitly includes officials mocking Dev as a traitor, insulting Arjun and beating him after his refusal; humiliation, injuries and anger drive his training and defiance.

## Reading the statuses

- **World foundation:** instantiated in the main-world route; not automatically final art, motion or gameplay approval.
- **Partial system:** code or a usable building block exists, but the story behaviour is incomplete or currently blocked.
- **Asset only:** authoring/preview content exists without the required main-world role.
- **Missing:** no implementation of the requested behaviour found in the inspected runtime scripts/scenes. This is an inventory conclusion, not a claim that no related word exists anywhere in design history.

## World, cast and story progression

| Story requirement | Current state | What exists | What remains | Evidence |
| --- | --- | --- | --- | --- |
| Village home setting | World foundation | Bhairavpur: eight houses, well, seats, two produce stalls, two kitchen gardens and period props | Arjun's designated family home, family interactions and opening sequence; normal player-route/art review | `settlement_builder.gd`; fresh inventory JSON |
| Arjun as playable protagonist | Partial system / runtime blocked | Player controller, model, movement, survival, equipment and animation code in main world | Fix visual script parse error; complete character, motion and contact acceptance | `player/player.tscn`, `player/arjun_visual.gd`; fresh load diagnostics |
| Dev as elder brother | Asset only | Editable MPFB body, static exports and isolated rigged idle study | Main-world/quest placement, dialogue, relationship scenes and service behaviour; clothing and motion approval | `docs/characters/npcs/arjun_brother.md`; no Dev-named node in fresh world; source references checked |
| Leela's river reunion | Asset only / encounter missing | Reference sheets and editable static model study; visual review failed | Childhood connection, recognition dialogue and later river collision during escape; actor and mission integration | `docs/characters/npcs/leela.md`; owner addition 2026-09-30 |
| Leela's independent resistance and future recruitment | Missing gameplay | New story premise: father hanged through a particular British person's cruelty | Develop circumstances/culprit, her quest, recruitment timing, companion behaviour and persistent party membership | Story V1; no gameplay actor or placement in existing character notes |
| Remaining family and brother relationship | Missing story content | Village structures can host it | Family cast, interaction, emotional establishment and family response to disappearance | Main-world/settlement source and runtime inventory |
| Dev's departure with urgent police contingent | Missing | Colonial and thana character candidates | Assignment scene, contingent movement, Dev participation and departure event | Runtime route/NPC source |
| Months without news | Missing story progression | Day/time system exists | Narrative elapsed-time sequence, missing-person state and investigation objective | `game_time_system.gd`; no quest framework found |
| Police station | World foundation | DistrictPolice/PoliceThana, public hall, record-room area, stairs and three placed staff | Story interaction and final environment/character review | `civic_building.gd`, `thana_staff.gd`; fresh count: 3 |
| Insult, traitor accusation and beating | Missing | Station and staff locations available | Authored dialogue, refusal trigger, assault/choreography, injury/aftermath and rogue-turn progression | Thana staff have no dialogue/combat; revised story document |
| Search for Dev and clue chain | Missing | Premise documented | Objective tracking, dialogue choices, clues, journal and mission dependencies | Runtime source inventory; `SaveManager.WORLD` directly enters exploration world |
| Training and mentors | Missing | Arjun already has weapon/action code | Mentor cast, lessons, earned abilities and progression gates | Player equipment/controller; no training or mentor system found |
| Secret plan and higher conspirators | Missing / author decision open | Town hall, compound and Government House provide locations; officer/official models exist | Define the secret and individuals; author evidence and discovery missions | Settlement and British roster source; Story V1 open decisions |
| Underground imprisonment of Dev | Missing story location | Above-ground DistrictJail with partitions and bars | Underground prison, entrance/routes, captive Dev, guards, captivity and discovery/rescue logic | `settlement_builder.gd:364`; fresh DistrictJail root |
| Ending / Dev's final fate | Unspecified / missing | Captivity is now fixed in story | Resolve outcome and implement final mission/consequences | Story V1 |
| Historical figure encounters | Missing / requested cast now named | Period notes; owner now requests Mangal Pandey, Tatya Tope and Rani Lakshmibai | Dated fictional lessons/refuge/meetings, independent historical lives, later news and grief; resolve geography | Story V1 research addition; no corresponding runtime cast/quest found |

## Oppression, community and combat

| Story requirement | Current state | What exists | What remains | Evidence |
| --- | --- | --- | --- | --- |
| Colonial presence and upper officials | World foundation | 16 independently placed British character candidates: eight men/rank-or-post roles and eight women; compound, Government House, flags, cannon | Faction behaviour, authority roles, conversations and final art; women are preview residents, not automatically combat enemies | `british_npc_roster.gd`; fresh count: 16 |
| Indian residents | World foundation + asset studies | Farmer/woman pair in main world; 3 thana staff; separate fruit-seller/weaving-assistant studies | Living routines, navigation, reactions, interactions and cloth/foot-contact repairs; seller/weaver studies are not live placements | Main scene; `other_indian_npcs.md` |
| Fields and farming workers | Partial environment | Agricultural terrain designation and village kitchen gardens; farmer model exists | Field work, tools/task animations, schedules and populated agriculture | `landscape_layout.gd:197`; peasant scene has model instances without work script |
| Tax collection, bondage/coerced labour, wealthy collaborators | Missing behaviour | Administrative buildings and official characters can support scenes | Tax demands, labour scenes, named landholders/collaborators and consequences | Runtime script/scene inspection |
| Whip assault on civilian | Missing | Generic colonial NPC models and player weapons | Whip asset/action, aggressor/victim behaviour, event trigger and resolution | No runtime whip/assault encounter found |
| Player weapons and attacks | Partial system / runtime blocked | Talwar, knife, bow, Enfield, Adams revolver and double gun; attack/aim/ammunition/reload code and pickups | Working NPC damage/death/combat targets, integrated fighting, balance and motion/contact approval | `arjun_equipment.gd`, combat scripts; NPC damage scan empty |
| Enemy combat and reinforcement | Missing | Colonial actors move through timed preview walk/idle/turn cycles and have collision | Perception, attacks, pursuit, navigation, alarms and reinforcement response | `british_npc_actor.gd`; no non-player `take_damage` receiver found in instantiated world |
| Civilian rescue encounters | Missing | Help-award function exists | Victim rescue state, intervention/outcome detection and one-time trust award | `award_help()` has no runtime caller |
| Trust / respect progression | Partial system | Fame points; flag cutting awards +1; `award_help()` would award +4; dossier shows fame | Rescue wiring, regional/community trust, meaningful NPC response and persistence | `fame_component.gd`, `talwar_slash.gd`, `identity_scroll.gd` |
| Regional revolutionary groups | Missing | No live resistance group found | Members, faction allegiance, leaders, locations and group state | Main-world roots and runtime code inventory |
| Revolutionaries help Arjun in a fight | Missing | No allied combat behaviour | Nearby witness detection, trust eligibility, joining fight and ally survival/outcome handling | NPC actors and runtime searches |
| Arjun remains vulnerable | Partial system | Sprint stamina/exhaustion, food, hydration, energy, warmth, finite ammunition; player health and fall damage | Enemy damage pressure, defeat/death/recovery, injury effects and earned combat progression | `survival_component.gd`, `player_controller.gd`; health setter alone is not a complete defeat system |

## Disguise, pursuit and escape

| Story requirement | Current state | What exists | What remains | Evidence |
| --- | --- | --- | --- | --- |
| Obtain and wear enemy uniform | Missing | Static NPC outfits and Arjun weapon equipment | Outfit loot, fitting/animation-compatible clothing swap and disguise identity | Runtime player/inventory/NPC inspection |
| Witness changing clothes → immediate recognition | Missing | A generic `witnessed_deeds` counter exists | Actual observers, line of sight, witnessed change, per-witness identity memory and recognition | `mark_witnessed()` has no runtime caller |
| Suspicion and enemy markers | Missing gameplay | Dossier displays text such as “Face remembered” at fame thresholds | Enemy-specific suspicion, investigation, markers and transitions | `identity_scroll.gd`, `fame_component.gd`; display text does not drive AI |
| Arrest and restraints | Missing | Police/staff candidates and player animation framework | Capture conditions, arrest state, hand-restraint animation and researched period restraint asset | Owner addition 2026-09-30; no custody implementation found in prior runtime audit |
| Ordinary city jail / thana lockup | Partial building foundation | Above-ground DistrictJail with bars/partitions and a separate thana | Larger austere city detention space, chosen thana relationship, cell gate and guard circulation; separate from Dev's underground prison | Existing settlement builder; new owner design requirement |
| Fade into detention and days passing | Missing | Game clock exists | Fade/custody transition, cell placement, elapsed-day presentation and sentence clock advancement | No detention transition in audited route |
| Guard opens gate and Arjun leaves | Missing | Staff models and general building/gate foundations | Guard approach/open animation, working cell gate, release exit and control restoration | No release sequence in audited route |
| Custody save/load and consequences | Missing | General save manager exists | Custody phase/time persistence and safe resume; decide inventory, survival and pursuit/recognition effects | Custody absent from current save payload |
| Wanted pursuit, alarm and search | Missing | Timed NPC movement previews | Last known position, alert sharing, chasing, searching and escape resolution | British actor source has clock-based cycles, not pursuit |
| Forest escape | World foundation | Baked wooded terrain, trees, shrine and forage grove | Enemy sight/search interaction and validated escape routes | Landscape bake/main scene; separate `WorldForestPatch` runtime node absent |
| Tall grass / sugarcane concealment | Partial scenery / missing stealth | Decorative grass and agricultural area exist | Sugarcane field asset/placement, concealment volumes and enemy visibility rules | `bake_landscape.gd`; no sugarcane/concealment implementation found |
| Climb trees and remain hidden | Missing | Tree scenery and general climbing component | Tree-specific holds/branches, perch, descent and sight/search behaviour | `climb_component.gd` targets walls/ledge geometry; no tree-hiding state |
| Prone / cover | Partial system / runtime blocked | Prone/crawl and nearby-solid cover, collider/camera/pose changes | Enemy sight/cover effectiveness and normal-speed contact/player review | `stealth_stance.gd`; fresh cascading skeleton errors |
| Walls and ledges | Partial traversal / runtime blocked | Physical ledge checks, timed ascent/mantle and compound wall holds | Repair current visual parse error and complete full-world grip/motion review | `climb_component.gd`, settlement wall metadata |

## New requirements checked against current foundations — 2026-09-30

| Owner requirement | Current foundation | Still missing |
| --- | --- | --- |
| Preserve map extent; enlarge/rework all houses/buildings appropriately | Existing landscape, settlement footprints, civic interiors, wall/ledge climbing | Per-building player-scale audit and targeted enlargement, climbing access/holds/landings, neighbour/road clearance review; no blanket scaling applied |
| Operational watchtowers | Embedded fort has `WatchtowerPier` / `WatchtowerBase` ruined geometry (`ruined_fort.gd:245`) | Working towers, guards, access/climbing, perception and alert response; regional historical design |
| Arjun starts firearm/artillery-untrained | Weapon ownership checked by `arjun_equipment.gd`; firing/looting code already exists | Learned-skill gates independent of ownership, beginner state and training persistence |
| Pandey lesson unlocks weapon acquisition | Weapon stores/pickups and combat components | Pandey actor/dialogue, teaching mission, skill unlock and store lead/acquisition sequence; pre-29-March-1857 staging |
| Cannon operation learned separately as applicable | Static courtyard cannon prop | Operable artillery, training and controls; Pandey lesson is not assumed to teach all weapons |
| Tatya Tope camp refuge after sugarcane escape | Woods/agricultural area; no sugarcane/pursuit system | Tope and independent soldiers/camp, refuge encounter, dated location and escape prerequisites |
| Lakshmibai brief encounter | No actor or mission found | Character, dated meeting/help and historically bounded availability |
| News of historical deaths and Arjun's grief | Daily clock only | Story calendar/chapter years, news events, dialogue/reactions and persistent one-time triggers |
| Historical figures stay independent | No party framework currently implements these roles | Bounded encounter roles; no companion recruitment; preserve documented outcomes |

The historical checks and unresolved chronology/geography are linked in [Story V1](story_v1.md). This is an incremental source/design audit, not another runtime or visual pass. The previously recorded `mantle_shift` blocker remains unverified since that probe.

## Supporting locations and systems already available

The main-world probe also confirms a timber bridge, river boat, village horse/stable, review carts, river fish, charpai, forage grove, day/night lighting, map/player UI, loot/weapon stores and save/menu wiring. These support exploration and survival. They do not yet produce the story's investigation, uprising, rescue or escape loops.

The ruined fort **is now instantiated in the main Suryagarh scene** through `fort_world_piece.tscn` (`embedded_in_world = true`). Its older focused note says it is not placed; the current scene and fresh runtime inventory supersede that placement claim. It remains a blockout with no resistance/quest role.

Forest generator/config resources are declared in the main scene, but no `WorldForestPatch` node is instantiated there. Baked trees/wooded terrain are available; the separate patch validator's assumed runtime node is absent. Do not equate the unused declaration with integration.

Save/load currently serializes position, clock, inventory, survival values, selected weapon/rounds, pickups, chests, forage and waypoint. It **does not serialize fame, witness memory, quests, trust, disguise or pursuit**, and player health is also absent from the saved payload. Those story systems need persistence when implemented.

## Fresh verification and limits

- Godot 4.7.2 headless editor import completed with exit 0; no script/import error lines found in that import log. Import does not establish runtime health.
- Fresh main-world probe instantiated 22,644 nodes, eight village houses, 16 British candidate actors and three thana staff. It found no non-player `take_damage()` receiver. No Dev-named node was present, consistent with source placement inspection; the name scan alone is not proof of absence.
- **Runtime FAILED:** `player/arjun_visual.gd:360` references undeclared `mantle_shift`. The visual script fails to load, producing subsequent `equipment` and `skeleton` access errors in the player/HUD/combat/stance route. The process exited 0 after inventory output, but this is not a passing gameplay test. Exit also reported ObjectDB/resource leaks.
- Durable [evidence JSON](world_story_audit_evidence.json) includes the probe source, inventory, commands and unique errors. Raw logs: `/tmp/tlm_story_audit_import_20260930.log`, `/tmp/tlm_story_world_probe_20260930.log`. Re-run the embedded probe source by saving it to `/tmp/tlm_story_world_probe_20260930.gd`, then use its recorded command.
- This audit inspected source, placements, focused documents and a bounded headless world load. It did not perform a new rendered walkthrough, normal-speed combat/contact review or historical verification. Older document PASS/visual claims are not fresh acceptance.
- Documentation gate: `python3 tools/check_agent_docs.py` PASS (52-line handoff within limit; all index links resolve). `git diff --check` PASS.

## Recommended build order

1. Fix the current `mantle_shift` runtime blocker and rerun the integrated world, equipment, stance and climbing routes.
2. Implement a minimal quest/dialogue/save framework and the opening: family/Dev setup, disappearance, station humiliation/assault, aftermath and first lead.
3. Add arrest/city detention/release to the law-response system: restraints, fade, days passing, guard-opened gate and exit; research the larger austere lockup separately from Dev's underground prison.
4. Build one full civilian rescue loop: hostile aggressors, civilian outcome, trust reward, nearby revolutionary assistance and reinforcement.
5. Add perception, pursuit/search and witness identity; then clothing acquisition/disguise and witnessed-change markers.
6. Connect forests/fields, sugarcane concealment, agricultural routines and tree hiding to that AI.
7. Expand mentors, regional groups, the conspiracy, underground prison and researched historical encounters.

## Task ledger

- Objective: requested current-game inventory against the clarified story. Status: COMPLETE for audit/documentation; runtime failure remains open.
- Completed: corrected station beat; inspected main-world route, supporting systems and candidates; performed import and bounded runtime inventory; reconciled fort and forest placement discrepancies; listed available foundations and missing behaviours.
- Files changed: `docs/story/story_v1.md`, this report, `docs/story/world_story_audit_evidence.json`, `docs/README.md`, `CODEX_HANDOFF.md`. No gameplay code changed. An import-generated untracked UID was removed; prior edits preserved.
- Blocker for gameplay acceptance: visual-script parse error above. No blocker to delivering the inventory.
- Next: fix `player/arjun_visual.gd:360` within a gameplay task, then rerun the recorded world probe and targeted equipment/climb/stance checks before starting the opening mission.

## Owner addition — arrest/detention/release

Added 2026-09-30: the list now includes an arrest animation with restrained hands, fade into a larger ordinary city jail/possible thana lockup, days passing, a guard opening the cell gate and Arjun leaving custody. This is a new requirement recorded after the runtime audit; no gameplay was implemented or newly tested. See the detailed sequence and unresolved custody/period decisions in [Story V1](story_v1.md#arrest-city-detention-and-release--owner-addition-2026-09-30).

## Owner addition — Leela

Recorded 2026-09-30: childhood friend through their fathers, separation for an undecided reason, chance river reunion while Arjun escapes, Leela recognizing him, her independent fight after her father's hanging and later party membership. These are future story/gameplay requirements; the existing character study remains unapproved and isolated. No new runtime verification or character placement was performed for this documentation addition.
