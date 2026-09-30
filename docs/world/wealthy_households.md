# Wealthy households and their NPCs

Updated 2026-09-30. [Visual review page](wealthy_households.html). Implemented world candidates; final appearance and motion/contact approval remain open.

| Household | Location (world x, y, z) | Residents | Staff |
| --- | --- | --- | --- |
| Landowner | −321, 7.2, 344 | Indian landowner in existing courtyard estate | Cook, water bearer, coachman |
| Wealthy merchant | −413, 7.2, 282 | Indian merchant in furnished veranda house | Cook, water bearer, coachman |
| British | −455, 8.5, −184 | Existing British official man and woman in estate bungalow | Cook, water bearer, coachman |

Each home has a kitchen, servant quarters and coach shelter. The landowner uses the existing estate rather than a second mansion. Twelve garden beds remain; beds obstructing the merchant site were moved to the village edge.

## Clothing distinction

The merchant has a dark indigo upper garment, cream dhoti, burgundy shoulder drape with woven gold border, and brown leather footwear. The landowner uses ivory upper garments with the cream, burgundy and gold palette. Servants retain the ordinary village clothing. The shoulder drape copies nearby garment skin weights; footwear follows the foot bones. These are editable derivatives of the existing farmer rig, so faces and overall proportions still share the donor. A distinct face, finer cloth, garment construction and historical costume review remain to be done.

- [Merchant preview](captures/merchant_household_resident.png)
- [Landowner preview](captures/landowner_household_resident.png)
- [Merchant home](captures/merchant_household_home.png)
- [British home](captures/british_household_home.png)
- [Occupied coach](captures/household_occupied_coach.png)

## Movement and household work

Thirteen actors have separate active AnimationTrees: four residents and nine staff. Male and female movement profiles remain independent. Cooks use a looping arm work pose; water bearers carry a pot near their hands. Coachmen use a seated pose on the driving box. Residents leave their home positions for short occupied coach journeys and return to their original positions. The existing public carts remain available separately.

The three routes are bounded driveway demonstrations: landowner courtyard through the gate, merchant court toward the village lane, and British estate west avenue. Boarding is instantaneous. These are not full town journeys or household schedules. The British woman's seated dress uses a temporary seated silhouette to avoid the standing skirt extending through the cabin.

## Checks and limits

[Validation report](wealthy_households_validation.json) records population, separate trees, the two new entrance capsule sweeps and completed round trips with collision queries. These checks establish scene structure and route clearance, not visual approval. Rendered captures were reviewed separately. Hand-to-pot and hand-to-rein contact, seated clothing, soles, the donor head wrap and continuous movement still need refinement. Houses are construction candidates with simple furnishing and materials.

Period coach references and their dating are recorded in [horse cart candidates](horse_cart_candidates.md). The new buildings and wealthy wardrobes have not passed a final 1857 architectural or costume review.

## Implementation and editable sources

- [Households module](../../world/suryagarh/settlements/wealthy_households.gd)
- [Coach travel](../../world/suryagarh/settlements/household_coach_travel.gd)
- [Household actor](../../characters/npcs/households/household_npc_actor.gd)
- [Resident builder](../../tools/characters/build_household_residents.py)
- Editable sources: `WorkingAssets/NPCs/households/{merchant,landowner}/`; runtime skins: `characters/npcs/households/`.
- Reproduce checks with `tools/world/validate_wealthy_households.gd`; Metal captures with `tools/world/capture_wealthy_households.gd`.
