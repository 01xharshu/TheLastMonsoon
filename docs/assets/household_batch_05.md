# Activity sets, part A — 2026-10-01 IST

Two reusable dressing candidates in `objects/household/sets/`, assembled in production order rather than story order. These are saved prefabs, not new placements in occupied homes or civic buildings.

Cooking corner and records desk (test output deleted)

**Cooking corner:** original clay hearth base, side supports and back, iron griddle and handle, shared hollow water pot, tied grain sack and basket. Hearth opening faces forward. No lit fire, fuel consumption, cooking reward or prompt is implied. Named CookApproach, CookingSurface, GriddleGrip and PotApproach references support the later contact pass. Hearth parts and existing storage props have colliders; griddle and visual-only pot need action-specific collision at integration.

**Records desk:** original 1.35 × 0.72 m timber table with a 0.7875 m top surface, four legs and back brace. Shared open folio, folded letter, brass lamp and stool. Documents and lamp sit on the table surface. Named StandingApproach and ReadingTarget plus nested document grips and stool references. Table parts and stool have colliders; lamp is the visual scene and does not switch light or flame in this set.

## Final animation checklist

- Cooking, if enabled: approach and crouch/sit with planted feet; stow weapons; retrieve ingredients, manipulate dough/utensils, grasp griddle handle, turn/remove bread, collect/store output. Add required utensil and ingredient variants before this action is authored. Synchronize heat, food/reward transfer and cancellation. Fire tending needs its own fuel/ignition action.
- Pot filling: retrieve/open pouch, credible source-specific water transfer, close/reattach. Pot approach and mouth must fit the accepted hero; this set does not add water-source gameplay.
- Records: standing or seated approach, read; lift/unfold/refold/store letter only when collecting is specified. Page turn requires deformable page geometry. Stool sit/stand needs palm/sole contact and clearance under the desk.
- Lamp: wick-level lighting/extinguishing if enabled; ignition source and hand contact unresolved. Sack/basket stay decorative unless handling is explicitly added.

Builder `tools/assets/build_activity_sets.gd`; reviewer `tools/assets/review_activity_sets.gd`. Packed source instances retain their own child ownership to avoid duplicated imported meshes. Headless/native Metal checks: prefab loading, bounds/floor baseline, approach markers, no root gameplay script, ray hits on hearth support and tabletop. Evidence `activity_sets_validation_{headless,metal}.json`; overview and individual `activity_sets_{cooking_corner,records_desk}.png`. Native renders inspected as assembly candidates. Whole-set player routes, reach/seat contact, material ageing, period/art approval and final placement remain open. Studio support rays do not establish those approvals.

Remaining batch 3 work: bedding/rest arrangement, market/craft station and armoury supply set. Reuse existing charpai/rest code; do not replace it with a decorative bed that loses its behavior. Character animations remain last.
