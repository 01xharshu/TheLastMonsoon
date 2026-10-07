# British NPC reference direction — 1857 Suryagarh

The reference sheets are **first-pass concepts**, not approved historical reconstructions or identities. Runtime candidate models now exist; see the [base and motion analysis](model_analysis_2026-09-27.md) or [HTML review](model_analysis_2026-09-27.html). Each sheet shows front, left profile, and back views of one adult man and one distinct adult woman. “Companion” defines a visual pairing for review; it does not assign a military rank, occupation, or relationship to the woman. The civilian official is a social stratum, not a military rank.

| NPC concept | Multiview sheet | Readable design cue | Review issue before modeling |
| --- | --- | --- | --- |
| Infantry private and working-class woman | [private](references/private_and_companion_multiview.png) | Plain red tunic and crossbelts; pale printed cotton dress and bonnet | Verify unit-specific belts, cap, tunic cut and period footwear. |
| Infantry corporal and working-class woman | [corporal](references/corporal_and_companion_multiview.png) | Two sleeve chevrons; ochre striped dress, shawl and bonnet | Verify chevrons and accoutrements for chosen Company unit. |
| Infantry sergeant and working-class woman | [sergeant](references/sergeant_and_companion_multiview.png) | Red tunic with sleeve chevrons; blue-grey dress, shawl and bonnet | Generated chevrons appear over-specified; verify number, color and placement for chosen unit. |
| Infantry lieutenant and gentry woman | [lieutenant](references/lieutenant_and_companion_multiview.png) | Restrained officer trim and sword; pale blue fitted dress | Verify junior officer insignia and sword pattern. |
| Infantry captain and gentry woman | [captain](references/captain_and_companion_multiview.png) | More ornamented red officer tunic, sash and sword; cream and sage fitted dress | Fix exact regiment, officer insignia, sword pattern and cap before construction. |
| Infantry major and gentry woman | [major](references/major_and_companion_multiview.png) | Field officer sash and sword; dark green dress | Verify field officer dress details for chosen regiment. |
| Infantry colonel and gentry woman | [colonel](references/colonel_and_companion_multiview.png) | Senior officer epaulettes and sash; burgundy formal dress | Verify whether ornate epaulettes fit the selected duty dress and context. |
| Senior Company civil official and formal-dress woman | [official](references/official_and_companion_multiview.png) | Linen coat, waistcoat and held top hat; lavender full-skirt dress | Define exact civil post and function in story; avoid treating civil authority as an army rank. |

## Historical anchors and limits

- The [National Army Museum's East India Company army overview](https://www.nam.ac.uk/explore/armies-east-india-company) supports Company forces and the 1857 setting; it does not establish any one uniform in these sheets.
- The [National Army Museum's 1857 red flannel tunic](https://www.nam.ac.uk/explore/tunic-mutiny) is a period material/color anchor. Its wearer and unit should not be copied blindly into fictional Suryagarh.
- The [National Army Museum collection records](https://collection.nam.ac.uk/inventory/objects/results.php?associatedName=&campaign=&event=&flag=1&keyword=&page=142&placeNotes=&productionNotes=&shortDescription=&unit=army) list a Bengal Staff Corps tunic with lieutenant-colonel badges dated 1855 and British Army uniform drawings dated 1857; use actual unit/object records for production insignia.
- The [Met's nineteenth-century silhouette study](https://www.metmuseum.org/pt/essays/nineteenth-century-silhouette-and-support) dates the expansion of crinoline skirts to about 1856. These sheets infer practical and formal women’s wear from that broader silhouette; no sheet is evidence of a particular woman in 1857 India.
- Khaki must not be applied as a universal 1857 British uniform: the [National Army Museum notes](https://collection.nam.ac.uk/detail.php?acc=1964-02-4-7) that some regiments dyed white summer uniforms khaki during the rebellion, with wider Indian adoption much later.

## Editable MakeHuman / MPFB blockouts

All eight pairs now have Blender 5.2 / MPFB source files under `WorkingAssets/NPCs/british/<rank>_pair/`, plus SHA manifests and front, side, and back renders under `candidates/`. The source builders are `tools/characters/build_british_private_pair.py` and `tools/characters/build_british_roster_pair.py`; `tools/characters/render_british_pair.py` makes the views. Each pair has separate adult male and female MPFB bodies and 53-bone game-engine rigs. These remain unapproved candidates. Sixteen independent skinned GLBs are placed in the world with personal idle/walk animation players and separately controlled preview patrols. Runtime and placement checks pass; representative rendered phases were inspected. Full-cycle contact, all costumes and realism remain open.

The [private source](../../../WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend) and its front (test output deleted), side (test output deleted), back (test output deleted) renders are the first costume study. Source revisions narrowed both headpieces, placed tunic buttons against fitted cloth, smoothed the crossbelt guides, and added a waistband to the gathered skirt. A later pass narrowed the skirt opening from 0.215 m to 0.17 m radius while preserving its 0.48 m hem radius; fresh front, side, and back Blender renders show a closer bodice-to-skirt silhouette. The waist pleats still look regular and stiff, the back straps read as narrow edge-on strips, and fitted donor garments retain modern seams/collar cuts. Face detail, exact 1857 headwear/equipment, skirt motion, and body/cloth intersections in pose remain unapproved. The other seven pair renders show similar blockout limits, and their distinct rank colors/details do not prove historical accuracy.

## Production gate

Approve or revise each identity and unit-specific costume, then make separate turnaround/model sheets with measured proportions, cloth layers, color/material swatches, face closeups, and equipment callouts. Reference images alone establish none of the runtime checks; the linked analysis records meshes, rigs, placement and base motion evidence separately. The generated views were visually inspected for full front/profile/back figures and readable rank silhouettes. They are direction review, not a source of exact seam geometry or anatomical measurement. These seven ranks are the current proposed NPC roster, not a claim that every historical Company rank is represented.

## Independent AnimationTree playback

All sixteen actors now blend their personal idle/walk clips through an individual AnimationTree. See [tree implementation and rendered evidence](animation_tree.md). Start/stop blend, actual skeleton playback and independence checks PASS.
