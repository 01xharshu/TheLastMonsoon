# Wealthy households and their NPCs

Updated 2026-10-01. [Visual review page](wealthy_households.html). Implemented world candidates; final appearance and motion/contact approval remain open.

| Household | Location (world x, y, z) | Residents | Staff |
| --- | --- | --- | --- |
| Landowner | −321, 7.2, 344 | Indian landowner in existing courtyard estate | Cook, water bearer, coachman |
| Wealthy merchant | −413, 7.2, 282 | Indian merchant in furnished veranda house | Cook, water bearer, coachman |
| British | −455, 8.5, −184 | Existing British official man and woman in estate bungalow | Cook, water bearer, coachman |

Each home has a kitchen, servant quarters and coach shelter. The landowner uses the existing estate rather than a second mansion. Twelve garden beds remain; beds obstructing the merchant site were moved to the village edge.

## Clothing distinction

The merchant has a dark indigo upper garment, cream dhoti, burgundy shoulder drape with woven gold border, and brown leather footwear. The landowner uses ivory upper garments with the cream, burgundy and gold palette. Servants retain the ordinary village clothing. The shoulder drape copies nearby garment skin weights; footwear follows the foot bones. The merchant now has a broader jaw and thin dark moustache; the landowner has a narrower jaw, stronger nose and greying moustache. Both retain the donor rig and much of its likeness. New scalp-sized cloth bands and crowns replace the intersecting head wraps. The soles are flattened, and a filtered woven-cloth shader adds restrained fabric grain. Final likeness, garment construction and historical costume review remain open.

- [Merchant preview](captures/merchant_household_resident.png), [face close-up](captures/merchant_household_face.png)
- [Landowner preview](captures/landowner_household_resident.png), [face close-up](captures/landowner_household_face.png)
- [Merchant home](captures/merchant_household_home.png)
- [British home](captures/british_household_home.png)
- [Occupied coach](captures/household_occupied_coach.png)

## Movement and household work

Thirteen actors have separate active AnimationTrees: four residents and nine staff. Male and female movement profiles remain independent. Cooks use a looping arm work pose. Water bearers carry rounded, rimmed vessels clear of their torsos; both arms solve to side contact targets, with a supporting finger pose. Coachmen lean forward on the driving box and solve both arms to the actual carriage rein targets, with curled fingers. Their intersecting donor lower panels are hidden while seated. Residents now walk out, climb aboard, sit, visit furnished offices, work at their desks and return through their home entrances. See [household journeys](household_daily_journeys.md). The existing public carts remain available separately.

The three routes are bounded driveway demonstrations: landowner courtyard through the gate, merchant court toward the village lane, and British estate west avenue. Boarding and exit use separate walk, step, cabin, sit and stand stages. These are coordinated demonstration routines rather than clock-based daily schedules or full town journeys. The British woman's seated dress uses a temporary seated silhouette to avoid the standing skirt extending through the cabin.

## Checks and limits

[Validation report](wealthy_households_validation.json) records population, separate trees, the two new entrance capsule sweeps and completed round trips with collision queries. These checks establish scene structure and route clearance, not visual approval. Rendered captures were reviewed separately. [Contact regression](household_contacts_validation.json) separately samples bone-derived palm targets on changing coach headings and live water-bearer poses. On 2026-10-01, 570 contact samples passed with a maximum 1.95 mm error; the occupied driveway run peaked at 1.49 mm and completed all three routes without blocked frames. These are bone-derived palm points, not a measurement of skin or fingertip contact. Duplicate placeholder coachman arms are hidden by their component labels, even when Godot renames a duplicate node. Seated clothing, fine finger placement, continuous garment motion and grounded sole appearance still need refinement. Houses are construction candidates with simple furnishing and materials.

Period coach references and their dating are recorded in [horse cart candidates](horse_cart_candidates.md). The new buildings and wealthy wardrobes have not passed a final 1857 architectural or costume review.

## Implementation and editable sources

- [Households module](../../world/suryagarh/settlements/wealthy_households.gd)
- [Coach travel](../../world/suryagarh/settlements/household_coach_travel.gd)
- [Household actor](../../characters/npcs/households/household_npc_actor.gd)
- [Contact test](../../tools/world/validate_household_contacts.gd)
- [Resident builder](../../tools/characters/build_household_residents.py)
- Editable sources: `WorkingAssets/NPCs/households/{merchant,landowner}/`; runtime skins: `characters/npcs/households/`.
- Reproduce checks with `tools/world/validate_wealthy_households.gd`; Metal captures with `tools/world/capture_wealthy_households.gd`.
