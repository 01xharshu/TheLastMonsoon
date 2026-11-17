extends RefCounted
## Pairwise crossing reservation, using route intent before bounds touch.
static func must_yield(at: Vector2, forward: Vector2, other_at: Vector2, other_forward: Vector2, own_id: int, other_id: int, other_controlled := false) -> bool:
 var cross:=forward.cross(other_forward)
 if absf(cross)<.25:return false # Following/opposing traffic uses lane clearance.
 var separation:=other_at-at
 var own_distance:=separation.cross(other_forward)/cross
 var other_distance:=separation.cross(forward)/cross
 # Keep priority until the cart and its team have cleared the intersection.
 if own_distance< -7 or other_distance< -7 or own_distance>22 or other_distance>22:return false
 if absf(own_distance-other_distance)>12:return false
 if other_controlled:return true
 # A vehicle already crossing must clear before a new arrival enters.
 var own_committed:=own_distance<7
 var other_committed:=other_distance<7
 if own_committed!=other_committed:return other_committed
 # Stable identity breaks equal arrivals, so both cannot yield to each other.
 return own_id>other_id
