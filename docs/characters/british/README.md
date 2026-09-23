# British NPC reference direction — 1857 Suryagarh

These are **first-pass concept references**, not approved historical reconstructions, identities, 3D assets, or runtime NPCs. Each sheet shows front, left profile, and back views of one adult man and one distinct adult woman. “Companion” defines a visual pairing for review; it does not assign a military rank, occupation, or relationship to the woman. The civilian official is a social stratum, not a military rank.

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

## First 3D blockout

The [private and companion Blender source](../../../WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend) contains two editable MPFB bodies and game-engine rigs. [Front](candidates/private_pair_front.png), [side](candidates/private_pair_side.png), and [back](candidates/private_pair_back.png) renders record the current costume study. The [manifest](candidates/private_pair_manifest.json) identifies the source. The first rigid sleeve and trouser tubes were replaced with fitted MPFB clothing meshes; disconnected material islands now receive consistent tunic/trouser colors, and the fabrics have subtle procedural grain. The dress has a curved, gathered skirt and both figures have revised headwear. The fitted base garments are contemporary source meshes used for anatomical fit, so seam and collar cuts remain historically wrong; crossbelts and headwear still need tailoring, and the skirt lacks true pleats and cloth simulation. Treat these as editable studies only. Motion, runtime export, and the other seven pairs remain open.

## Production gate

Approve or revise each identity and unit-specific costume, then make separate turnaround/model sheets with measured proportions, cloth layers, color/material swatches, face closeups, and equipment callouts. No NPC meshes, rigs, action sets, scene placement, or gameplay behavior are claimed by these images. The generated views were visually inspected for full front/profile/back figures and readable rank silhouettes. They are direction review, not a source of exact seam geometry or anatomical measurement. These seven ranks are the current proposed NPC roster, not a claim that every historical Company rank is represented.
