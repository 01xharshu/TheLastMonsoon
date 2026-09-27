# Historical fit for the 1857 world

Suryagarh is fictional. Before adding an object to a playable scene, record evidence for its **form, date, use in India, and role at this location**. A broad date range alone does not establish local availability. Record any inference made for the fictional setting, then verify scale, mounting, collisions, and appearance in the rendered scene.

## Current weapon store

The Company armoury holds five prototype pickups: Enfield, talwar, double gun, bow, and Adams pistol. Arjun starts unarmed and must enter the store to take each item. The rack and this collection of held/private arms are fictional design inferences, not a reconstruction of documented Company issue.

The [2026-09-27 Forward+/Metal rack capture](captures/23_company_weapon_rack.png) was inspected after refitting all five objects to two shelves. Bounds checks confirm a 15 mm support allowance and containment within the rack; a standing room-side physics ray reaches each pickup. Detailed changes and limitations: [weapon store](weapon_store.md).

| Item | Period evidence | Game decision |
| --- | --- | --- |
| Pattern 1853 Enfield | [Royal Armouries](https://royalarmouries.org/schools/learning-resources/the-british-empire) identifies the 1856 third model and states it was given to East India Company sepoys in 1857. [National Army Museum](https://www.nam.ac.uk/explore/why-did-indian-mutiny-happen) documents Pattern 1853 cartridges in 1857. | Plausible in a Company store in a fictional north Indian district in 1857. Exact local supply and model markings still need research. |
| Talwar | [National Army Museum](https://collection.nam.ac.uk/detail.php?acc=1951-09-11--1) catalogs a talwar associated with Prince Mirza Mughal around 1857. [The Met](https://www.metmuseum.org/art/collection/search/31136) dates an Indian talwar to the 18th–19th century. | Period and region plausible. Its presence in this particular Company store is a gameplay inference; a locally held or confiscated sword should be signaled through room dressing or story. |
| Bow | William Rice's [1857 account of Rajpootana hunting in 1850–1854](https://archive.org/details/dli.ministry.23914), printed p. 26, describes local bows and arrows. [The Met](https://www.metmuseum.org/art/collection/search/30295) catalogs an Indian bow dated 18th–19th century. | Bows existed locally in the period. Neither reference approves the prototype's exact straight wooden form, quiver, or its presence in Company stores. Keep those details provisional. |
| Double gun | Rice, same source, preface p. vi describes double guns/rifles; printed p. 115 describes damp gun caps. Both relevant pages were visually inspected in the 1857 scan. | Supports cap-fired sporting arms in India before 1857. Exact model and calibre are not established; this is held/private sporting equipment, not claimed regulation issue. |
| Adams pistol | [National Army Museum](https://collection.nam.ac.uk/detail.php?acc=1993-02-351-1) documents an Adams used at Jhansi in 1858 and explains the Beaumont improvement ordered in 1855. | Establishes use in the rebellion, but the specimen is later than the game's 1857 date and is not proof of this exact 1851 model's local supply. Exact variant and ownership remain open. |

## River and stair review

[The British Museum's 1833–1834 Prinsep collection](https://www.britishmuseum.org/collection/object/P_1871-0812-2526-2535) includes Raj Ghat at Benares. This establishes ghats before 1857, not the design of Suryagarh's timber boat landing. That landing is currently a jetty, not a sourced reconstruction of a masonry ghat. The plain timber stair handrails remain provisional: a modern photograph of an old building cannot establish when its present rail was installed. The [2026-09-27 support and landing repair](period_access.md) adds grounded piles, stair stringers and rail posts, with physical/visual evidence and dated architectural references; it does not grant exact historical approval.

## Asset acceptance rule

1. Date the specific form, not merely the broad object category.
2. Establish use or availability in India at the game date, then explain why it appears at this location.
3. Check model form, materials, scale, mounting, collision, and appearance in the rendered scene. A structural pass alone is insufficient.
4. Leave unsupported details out until sourced. This applies to proposed ghats, stair rails, vehicles, and street fittings.

The existing masonry, riverbank works, stair rails, civic interiors, and transport have **not** received a complete period audit under this rule. Their presence in the prototype is not historical approval.

## Civic halls and period sidearms — 2026-09-24

The fictional Suryagarh town hall and district police office are full-size, two-storey test buildings. Their entrances, halls, record rooms, armoury display, stairs, and upper galleries occupy the same world as Arjun. [Kolkata Municipal Corporation's history](https://www.kmcgov.in/KMCPortal/jsp/KMCAboutKolkataHome.jsp) records a colonial Town Hall, collector-led civic administration, and an early police force before 1857. This supports the *type* of institution, not the exact Suryagarh architecture. Plastered masonry, shade verandas, shutters, timber beams, and administrative furniture are plausible design choices still needing location-specific research and owner review. A shallow clay-tile roof, eaves and parapet now set a provisional silhouette; drainage and exact construction still need location-specific evidence before historical sign-off.

The small sidearm is an original visual interpretation of an 1851 Deane–Adams percussion revolver. The [National Army Museum specimen](https://collection.nam.ac.uk/detail.php?acc=1963-12-251-271) documents its five chambers and early-1850s manufacture; museum photos were used as visual reference only and were not copied into the game. This establishes date and broad British use, but not issue to this fictional police office. The plain utility knife is a generic tool silhouette, not a named regulation pattern. The pickup uses `pistol` and `utility_knife` inventory IDs. Paper cartridges and lead projectiles replace the historically unsuitable “steel bullets” description; exact charge and loading simulation are intentionally not claimed.

The civic plaster and wood maps in `assets/architecture/materials/` are [Poly Haven CC0 assets](https://polyhaven.com/license), which permits use in a sold game. Exact downloaded URLs, SHA-256 hashes and map names are recorded in `docs/world/civic_materials.json`. The buildings, sidearm meshes, knife mesh and prototype weapon sound files were authored for this repository, with reproducible Blender/audio scripts under `tools/weapons/`. The current village horse is a separate original procedural asset; its provenance and limitations are in `docs/world/horse_stable.md`. A [CC0 animated horse source](https://quaternius.com/packs/ultimateanimatedanimals.html) was checked as a reusable option but was not imported, because its stylised proportions do not match the current visual direction.

Runtime test evidence: `tools/world/validate_civic_interiors.gd` moved the real player capsule through both entries and up/down both staircases, then captured `docs/world/captures/realism_*`. `tools/weapons/validate_rifle.gd` checks rifle and revolver chamber counts, ammunition consumption, sound activation, impact marks, and a near-muzzle cover hit. The civic traversal check also confirms the upper-floor knife pickup, hand draw, and a reachable short-range strike. These are gameplay prototype checks; they do not approve Arjun's rejected appearance or all historical furnishings.
