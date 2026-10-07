# River landing and stair support — 2026-09-27

## Repairs

The previous river landing was a straight height interpolation that sank through the bank. Its rendered deck appeared as separated visible sections. The revised timber deck follows the highest terrain sample across its width, with 80 mm clearance and a maximum 25% grade. Sixty-three sloped segments form the walking surface; visible board joints are 12 mm wide while their collisions overlap by 25 mm. The water end remains at 0.45 m, preserving the prior boat-side height.

Twenty piles embed at least 0.35 m into the sampled bank/river bed, meeting ten crossbeams beneath the deck. This is a supported prototype jetty, not a sourced masonry ghat reconstruction.

Government House had bare handrail bars and isolated treads. Its two flights now have visible timber stringers, end posts and balusters. Town Hall and Police use the same assembly, including supported rail ends. Guards use one physics body per side, with shapes matching the visible posts/rail; no large invisible wall was added. The stair walking ramps remain under the treads. The additional collision shapes have not been profiled on an 8 GB device.

## Verification

`tools/world/validate_period_access.gd`:

- Metal rendered review: landing (historical test output unavailable), Government House stair support (historical test output unavailable), both inspected.
- All 567 deck samples clear the bank; all 20 piles reach it or the river bed.
- Government House has 196 visible rail supports; four side rays hit matching guard collision.
- Actual player walks from the bank to the jetty end without jump or a fall between segments. Headless result: validation JSON (test output deleted).

`tools/world/validate_player_world_stairs.tscn` also passes all eight real-player up/down routes after the guard change. See [traversal scope](player_stair_traversal.md). This does not approve boot planting or Arjun's rejected appearance.

## Historical evidence and remaining limits

- [British Library P1008](https://searcharchives.bl.uk/catalog/032-003265760) catalogs Thomas Daniell's *Old Fort Ghat*, Calcutta, 1787. Ghats therefore predate 1857; it does not establish this timber landing's form or location.
- [British Library Add Or 4702](https://searcharchives.bl.uk/catalog/040-003278537) catalogs Sita Ram's 1814–1815 staircase inside the Patna opium godown. The digital image is currently listed unavailable. The record establishes a Company industrial staircase, not our timber rail construction.
- [Aga Khan Museum curator's account](https://ithraeyat.ithra.com/editions/the-street/listening-to-the-sounds-of-a-street) identifies a Delhi palace painting from around 1820–1830 with a double staircase and roof balustrade. This supports those architectural types in India before 1857, not an exact plain timber interior rail.

The supports repair physical plausibility. Exact timber joinery, rail profile, building/site fit and the jetty's period precedent remain unapproved. Do not use a current photograph of an old building as proof that its present fittings existed in 1857. Next: find dated form-specific references, then refine the materials and joinery; retain a clear walking route.
