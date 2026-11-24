# The Last Monsoon — Story version one

Updated: 2026-09-30 IST (station betrayal revised from owner clarification). Source: owner's story brief in the current Codex chat.
Status: **V1 STORY DRAFT RECORDED**. This document is the narrative planning source for subsequent work, not evidence that quests or systems are implemented. It extends the existing “Find Dev” premise. Later revisions should explicitly identify changes to this baseline.

## Premise

Arjun is an ordinary young man living with his family in a village. His elder brother, Dev, serves as a sepoy in the British-controlled police establishment. Dev leaves on an urgent assignment with a large police contingent. Months pass without his return or a reliable message.

Worried, Arjun goes to the station seeking answers. Officials obstruct and disrespect him, mock him by calling Dev a traitor, and beat Arjun when he refuses to submit. He leaves physically hurt, humiliated and furious. This assault and the slander against his brother are a direct trigger for his decision to train, defy the authorities and fight back. His search begins as a family matter, then exposes a conspiracy and draws him into a wider struggle against colonial oppression. The accusation that Dev is a traitor is the officials' claim, not the narrator's judgment.

The existing project places the fictional region around 1856–1859 and names Arjun's village Bhairavpur, with Suryagarh as a town. These are current project anchors, not newly specified details from this brief; the exact opening date and mission geography remain to be settled.

## The truth behind Dev's disappearance

Dev discovered a secret plan involving powerful people within the colonial establishment. He was moving toward involvement with a revolutionary group and could have passed that information to Indian resistance members. To prevent disclosure, those responsible captured him and confined him in an underground jail under torturous conditions.

This is the author's underlying truth. Arjun does not know it at the start. Reveal it through people, clues and missions as his search progresses. The secret plan, responsible leaders, evidence trail, prison location and eventual rescue or other outcome are deliberately unresolved. Dev's captivity is fixed in this draft; his final fate is not.

## Arjun's journey

1. **Home and absence.** Establish the brothers, their family, village life, Dev's departure and the months without news. The opening's playable duration and use of flashbacks remain open.
2. **Humiliation and assault at the station.** Officials insult Arjun, mock Dev as a traitor and beat Arjun when he refuses to submit. His injuries, humiliation and anger push him toward training and becoming a rogue.
3. **The search widens.** Contacts and clues lead toward higher officials. He sees the coercion affecting ordinary people and begins resisting it.
4. **Trust and training.** He meets trustworthy people, mentors and local revolutionaries. Their help, and what he learns, make him more capable over time.
5. **A family search becomes resistance.** Arjun joins the struggle while continuing to seek his brother. He breaks rules that protect the perpetrators and becomes a wanted man.
6. **The conspiracy and underground prison.** The search eventually uncovers why Dev was taken and where he is held. The final operation, ending and wider consequences await a later story revision.

This is a planning sequence, not a locked chapter list or authored quest script.

## Leela — childhood friend, river reunion and future companion

Owner addition: 2026-09-30. Leela is the daughter of a friend of Arjun's father. Arjun and Leela were friends as children, but became separated. The cause of that separation remains open for the owner to develop.

During a later escape, Arjun unexpectedly collides with Leela near the river. Leela recognizes him, bringing their childhood connection into his present struggle. The exact mission, pursuers, river location and recognition dialogue remain to be written; this is a future encounter, not placement in the opening village.

Leela has her own reason for resistance: her father was hanged because of the cruelty and actions of a particular British person. She fights against that person and the oppressive forces involved. The responsible person's identity, accusation, circumstances of the hanging and what Leela knows remain deliberately unresolved. Do not invent these details as settled canon.

Leela later joins Arjun's party/company. The reunion establishes her entry into the story; the exact recruitment moment and conditions remain open and need not occur immediately at the river. Preserve her independent motivation while connecting their struggles. Unlike the bounded historical visitors, Leela is intended to become an ongoing companion.

Existing character notes describe a later love-interest direction. This addition establishes their shared childhood and resistance partnership; it does not yet specify romance pacing or outcomes. Future scenes should develop that relationship rather than assuming instant romance on reunion.

Implementation requirements: reunion mission and recognition dialogue, her father's story/clue state, later recruitment, persistent party membership and companion behaviour appropriate to authored missions. Combat, following, assistance and other party capabilities require separate design; joining the party alone does not establish all of them. Leela's current visual study is unapproved and has no gameplay actor or main-world placement.

## World and tone

Show colonial power through concrete encounters: heavy tax demands, coerced or bonded labour, field work, intimidation, and guards using whips to punish or extract obedience. The owner's spoken “hunter” is interpreted here as a whip; exact prop terminology and period form need research.

Oppression should affect livelihoods, family decisions and access to justice. Some wealthy landholders and local elites benefit from or assist the power structure. Individual characters should have identifiable motives and allegiances; wealth or nationality alone should not determine every character's behaviour.

Villagers have work, relationships and agency beyond being victims. Field workers, traders, informants, helpers and resistance members make community life visible. The game depicts a fictional local situation within colonial India; these scenes are narrative targets, not a verified claim that every Indian experienced the same treatment.

Arjun is **not a superhero**. Training, fatigue, injury, numbers, terrain and available help matter. He sometimes has to flee. Courage includes protecting someone, escaping a losing fight and surviving to continue the search.

## Community trust and resistance assistance

Resistance exists in separate regional groups, often roughly 10–20 people, sometimes smaller or larger. Those are narrative group sizes, not a requirement to spawn that many combat actors simultaneously.

The owner requests a trust/respect value that grows when Arjun protects local people. Example: he encounters three or four colonial enforcers beating a civilian, intervenes and saves the person; local trust increases. Lethal intervention is possible in the brief. Exact rewards, nonlethal alternatives and penalties are still design decisions.

When Arjun is fighting and alerted police bring reinforcements, nearby revolutionaries who witness the situation can join the fight to protect him. Support depends on local presence and awareness; helpers should not appear from nowhere.

Proposed implementation rules, pending tuning:
- Keep local community trust separate from police suspicion and pursuit.
- Award trust for a resolved rescue, rather than granting points repeatedly for the same encounter.
- Evaluate helper allegiance, awareness, distance, willingness and ability before assistance.
- Track civilian safety and encounter outcome so indiscriminate violence is not automatically treated as protection.
- Decide later whether reputation spreads between regions and whether assistance consumes resources or exposes allies.

## Disguise, witnesses and suspicion

Later in progression, Arjun can take clothing from a defeated policeman or colonial NPC and disguise himself in that role. Acquiring an outfit does not automatically erase his identity or pursuit.

The central requirement is **witness memory**: an enemy who sees Arjun change clothes recognizes him despite the disguise. An enemy who witnesses his fighting can become suspicious or raise an alert. Enemy markers should communicate suspicion and recognition; exact appearance and timing remain open.

Proposed state model for later implementation:

| State | Meaning | Intended response |
| --- | --- | --- |
| Unaware | No identifying evidence about Arjun | A plausible disguise can permit ordinary movement, subject to later access rules |
| Suspicious | Behaviour or incomplete evidence raises doubt | Watch or investigate; present a readable suspicion marker |
| Recognized | Witness saw the change or has identifying evidence | Outfit does not fool this witness; raise an alert or pursue |
| Searching | Pursuers lost direct sight | Search the last known area; clothing changes do not delete witness memory |

A witness seeing a clothing change must cause immediate recognition, not merely a small suspicion increase. How reports spread, how long recognition lasts, what clears a search, and whether uniforms permit restricted access are unresolved. Avoid giving every enemy instant global knowledge without an observation or communication rule.

## Escape, hiding and the working landscape

Arjun can escape into forests, conceal himself in tall grass or sugarcane fields, and later climb trees to hide. Fields also contain Indian NPCs doing agricultural work; they are inhabited spaces, not only stealth arenas.

Hiding should depend on enemy sight and search behaviour. Entering vegetation or climbing a tree should not automatically cancel recognition when an enemy watched him enter. Concealment, breaking sight, last known position and search resolution need separate rules. Tree climbing must support a usable hiding location, rather than granting invisibility merely because Arjun is elevated.

These are future requirements. Existing climbing, cover, stamina and NPC prototypes need individual inspection before any claim that they satisfy this story.

## Arrest, city detention and release — owner addition, 2026-09-30

If British authorities or police catch Arjun fighting or breaking the law and arrest him, show an arrest animation with his hands restrained, then fade into a city jail/lockup. Being detected does not itself mean custody is instantaneous; capture/arrest conditions still need design.

This ordinary city detention facility is **separate from Dev's secret underground prison**. The city jail should be somewhat larger and may be inside the expanded thana or directly associated with it. The exact building arrangement is open. The thana's public/administrative areas may be more elaborate, while the lockup should read as austere and functional, without fancy furnishings. Resolve cell proportions, bars, doors, guard access, circulation and period materials through research and player-scale review when building it. The existing above-ground DistrictJail is a foundation to assess, not an approved fit for this requirement.

The requested sequence is:

1. Authorities capture Arjun; play the restraint/arrest animation.
2. Fade out, then reveal Arjun inside the ordinary city lockup.
3. Communicate that days pass and advance the game clock by the selected detention duration. Exact duration and presentation are open.
4. Show a guard approaching and opening the cell gate.
5. Show Arjun leaving custody and coming out of the thana/jail; restore normal player control at a safe exterior position.

For this initial gameplay direction, release follows the detention period. This is a fictional gameplay treatment, not a verified historical legal procedure. Crime eligibility, sentence lengths, treatment of severe offences, equipment handling, survival changes, and how release affects wanted state or individual witness recognition remain open. Do not silently assume release clears all recognition or removes inventory.

Future implementation needs a custody state/transition controller, compatible restraint/guard animations, fades, lockup placement, a working gate, time advancement, release staging and save/load support through each phase. Keep player input, camera and collision coordinated during transitions, and prevent interrupted saves/reloads from duplicating sentencing or leaving Arjun trapped. These are integration requirements proposed for implementation, not additional settled narrative outcomes.

Historical accuracy remains a requirement: research restraints appropriate to the chosen year/service/location before choosing a final handcuff model or pose, and research local thana/lockup design and custody practices. No specific restraint, building form or legal procedure is historically approved by this addition.

## Building scale and watchtowers — owner addition, 2026-09-30

Keep the current overall map extent. Enlarge/rework houses and other buildings within it as needed for the planned interiors, city detention, circulation and climbing. This is a design requirement, not a blanket scale multiplier: review each footprint, doorway, room, stair, roof, wall hold and landing at player scale while preserving roads, neighbouring clearances and terrain contact. Provide meaningful climbing routes and safe traversal geometry where intended.

Add operational watchtowers with period-appropriate construction, access, observation positions and climbing opportunities. A ruined watchtower carcass already exists in the embedded fort blockout; it is not a working guard/lookout system. Tower number, sites and exact regional form remain open.

Historical evidence supports watchtowers in Indian forts before this setting: the Ministry of Tourism describes [Gobindgarh Fort](https://www.incredibleindia.gov.in/en/punjab/amritsar/gobindgarh-fort), including its historical watchtowers, and [Vattakottai Fort](https://www.incredibleindia.gov.in/en/tamil-nadu/kanniyakumari/vattakottai-fort), an eighteenth-century fort with watchtowers. These support the building type, not a claim that a particular British thana used the same design. Research the local form before final authoring; do not copy a modern tourist renovation as an 1857 reconstruction.

## Historical encounters and weapon progression — owner addition, 2026-09-30

Arjun begins without knowing how to use guns, pistols or cannons. Existing prototype weapon functionality must eventually be gated by story training; acquiring a weapon and knowing how to use it are separate states. The owner wants a lesson to open a sequence in which Arjun learns where weapons are kept and then infiltrates/loots a store. Avoid an unexplained inability to enter: communicate the missing knowledge, objective or physical obstacle. Exact gate mechanics remain to be designed.

**Mangal Pandey:** Arjun meets him during an early, fictional encounter. Pandey teaches an appropriate basic weapon lesson and tells him where/how to obtain weapons, unlocking the acquisition mission and the skill actually taught. This does not automatically grant mastery of pistols and artillery: their training scope remains open. Pandey is a serving sepoy at this time, not a former sepoy. Later, news of his execution reaches Arjun, who mourns someone who helped him.

The [National Army Museum](https://www.nam.ac.uk/explore/why-did-indian-mutiny-happen) places Pandey, of the 34th Bengal Native Infantry, at Barrackpore on 29 March 1857. [Government of India publication New India Samachar](https://newindiasamachar.pib.gov.in/WriteReadData/flipbook/2023/Jul/2nd/english/files/basic-html/page52.html) records execution on 8 April 1857. Stage the free teaching encounter before the 29 March incident; the execution date alone is not an available teaching window. Exact encounter date/location and a credible connection from fictional North/Central India to Barrackpore remain unresolved. Do not relocate him to Suryagarh as a historical fact. Keep the map fixed: an early narrated/off-map episode or a separately researched staging choice can be considered later, not silently adopted now.

**Tatya Tope:** During a later escape, Arjun runs through sugarcane and reaches a camp where Tope is resting with his own soldiers. The camp offers temporary refuge and a brief meeting. This is the owner's fictional scene; the location/date must fit his researched movements. Tope and his force remain independent of Arjun's party. The [National Army Museum collection](https://collection.nam.ac.uk/detail.php?acc=1963-10-247-1) supports his role as a rebellion leader; a [Government of India release](https://www.pib.gov.in/newsite/PrintRelease.aspx?lang=2&reg=48&relid=138945) records execution at Shivpuri on 18 April 1859. Any living encounter must precede his capture, not merely execution.

**Rani Lakshmibai:** A later brief meeting may offer help, advice or a lesson; its exact content and setting remain open. Arjun subsequently hears that she died in battle in June 1858. The [UP government account](https://www.nri.up.gov.in/article/en/jhansi2) gives 18 June, while the [Ministry of Culture Dictionary of Martyrs](https://www.culture.gov.in/files/inline-documents/Martyrs_Vol_2_Part_II_06_03_2019_4.pdf) gives 17 June. Keep month/year fixed and reconcile the exact day before dating dialogue or scheduling the encounter. The two dates should not be silently presented as one uncontested fact.

These historical figures appear in bounded story encounters, possibly reached through introductions from local revolutionaries. They do not join Arjun's company or become his recurring combat helpers. Regional fictional resistance members still provide the nearby assistance described earlier. Encounters should be gated by chronology and place, even if their exact trigger is variable; unrestricted random spawning would violate this requirement.

Their recorded campaigns, deaths and outcomes remain intact. Arjun's interaction is explicitly fictional and does not make him responsible for their historical achievements. News of events can arrive after a believable delay, through a messenger, contact or another researched channel. Progress the story across years using chapter/time transitions; the existing daily clock is not yet a historical calendar. Reaching a date must not accidentally skip required quests or resurrect unavailable characters after loading a save.

The brothers, conspiracy and local quest line remain fictional. Additional historical figures are not selected by this revision; evaluate future candidates against year, region, movements and a bounded helping role. Resolve Dev's actual service organization, rank, clothing and timeline through research; his current red-coat model does not settle those questions.

## Planning order proposed from this brief

1. Resolve the opening year, Dev's service and the secret plan; write a short opening quest outline from village to station and first reliable lead.
2. Build one representative civilian rescue encounter with trust gain, police response and nearby ally assistance.
3. Establish witness recognition and pursuit/search, then add a disguise encounter that tests an unseen change against a witnessed change.
4. Connect escape routes through woodland and sugarcane, field-worker routines and later tree hiding.
5. Expand regional resistance groups, training and researched historical encounters; develop the prison operation and ending once the central secret is chosen.

This order is a proposal for future tasks, not authorization to implement all systems now. For each prototype, validate gameplay outcomes and player readability in the actual world as well as structural checks.

## Draft task ledger

- Updated: 2026-09-30 16:02 IST; identity: current Codex story-v1 chat.
- Objective/scope: preserve the owner's initial story and translate it into future design requirements; documentation only.
- Completed: recorded premise, Dev's captivity, Arjun's progression, oppression encounters, community aid, disguise witnesses, escape, historical boundaries and proposed planning order.
- Files: `docs/story/story_v1.md`, `docs/README.md`, `docs/characters/npcs/arjun_brother.md`, `CODEX_HANDOFF.md`.
- Status: COMPLETE for the requested documentation draft.
- Verification: `python3 tools/check_agent_docs.py` PASS (index links resolve; handoff within limits); `git diff --check` PASS. Read/reconciled the existing premise and Dev note; reviewed coverage against the owner brief. Documentation checks do not establish runtime implementation or historical accuracy.
- Blockers: none for drafting. Secret plan, precise service/date, historical cast and ending remain open decisions for later work.
- Next: when story development resumes, settle the secret plan and Dev's service/date, then write the village-to-station opening quest outline.

## Arrest requirement update ledger

- Updated: 2026-09-30 IST; current Codex chat. Scope: record the owner's arrest/detention/release addition; documentation only.
- Status: COMPLETE for recording the requirement. Completed: recorded sequence, distinct city/Dev prison identities, austere lockup direction, historical research needs and integration needs.
- Files: `docs/story/story_v1.md`, `docs/story/world_story_audit.md`, `CODEX_HANDOFF.md`.
- Evidence: owner brief; existing audit's above-ground jail and missing police behaviour. No fresh gameplay or historical verification required for recording the requirement.
- Blockers: none for documentation; building arrangement, custody rules and researched design remain open for implementation.
- Verification: `python3 tools/check_agent_docs.py` and `git diff --check` PASS.
- Next: resolve custody rules and research the local lockup/restraint design before gameplay implementation.

## Historical encounters/building requirement ledger

- Updated: 2026-09-30 16:29 IST; current chat. Scope: record fixed-map building enlargement/climbing, watchtowers, historical cameos and training/acquisition progression.
- Status: COMPLETE for documentation and initial historical checks; no gameplay or building changes.
- Files: `docs/story/story_v1.md`, `docs/story/world_story_audit.md`, `CODEX_HANDOFF.md`.
- Evidence: linked government/museum sources above; inspected fort watchtower geometry and existing inventory-only weapon gate.
- Open decisions: Pandey encounter geography/date, specific training scope, other encounter windows, exact Lakshmibai death day, building/tower layouts. No claimed historical approval of fictional meetings.
- Verification: `python3 tools/check_agent_docs.py` and `git diff --check` PASS.
- Next: solve early Pandey staging and dated story progression, then plan training gates and per-building/tower route audit within the existing map.

## Leela story update ledger

- Updated: 2026-09-30 16:43 IST; current chat. Scope: record childhood friendship, separation, river reunion, father's execution motive and future party membership.
- Status: COMPLETE for documentation; no character or gameplay implementation.
- Files: `docs/story/story_v1.md`, `docs/story/world_story_audit.md`, `docs/characters/npcs/leela.md`, `CODEX_HANDOFF.md`.
- Completed: linked character notes to the new story role; added missing reunion/recruitment systems to the audit. Separation, responsible British person and joining point remain open.
- Verification: `python3 tools/check_agent_docs.py` and `git diff --check` PASS.
- Next: write the river encounter and recruitment outline when the owner develops those details; retain the unapproved study in isolation.
