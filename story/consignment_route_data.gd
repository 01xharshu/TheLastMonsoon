extends RefCounted
const Uplands=preload("res://world/suryagarh/port_village_uplands.gd")
const VERSION=3
# Retained for migrating waypoint indices in existing mission saves.
const LEGACY_WAYPOINTS=[Vector2(-194,620),Vector2(-240,570),Vector2(-430,520),Vector2(-640,440),Vector2(-720,250),Vector2(-680,40),Vector2(-590,-150),Vector2(-485,-280),Vector2(-520,-400),Vector2(-680,-530),Vector2(-780,-620),Vector2(-650,-730),Vector2(-380,-750),Vector2(-120,-710),Vector2(160,-650),Vector2(420,-630),Vector2(660,-600),Vector2(770,-490),Vector2(750,-310),Vector2(660,-130),Vector2(580,-180),Vector2(610,-230),Vector2(600,-280),Vector2(555,-285)]
# Reuse the surveyed port departure, winding hill road and existing bridge.
# Leave at its final hill junction before the short village-only spur.
const PUBLIC_WAYPOINTS=[Vector2(-212,620),Vector2(-208,560),Vector2(-214,500)]+[Uplands.MAIN[0],Uplands.MAIN[1],Uplands.MAIN[2],Uplands.MAIN[3],Uplands.MAIN[4],Uplands.MAIN[5],Uplands.MAIN[6],Uplands.MAIN[7],Uplands.MAIN[8],Uplands.MAIN[9],Uplands.MAIN[10],Uplands.MAIN[11],Uplands.MAIN[12],Uplands.MAIN[13],Uplands.MAIN[14],Uplands.MAIN[15],Uplands.MAIN[16],Uplands.MAIN[17]]
const HOLDING_ANCHOR=Vector2(1000,-500)
const HOLDING_LOOP=[HOLDING_ANCHOR,Vector2(1040,-420),Vector2(1020,-300),Vector2(900,-240),Vector2(790,-300),Vector2(760,-420),Vector2(800,-540),Vector2(900,-580),HOLDING_ANCHOR]
const WAYPOINTS=PUBLIC_WAYPOINTS+[Vector2(-500,312),Vector2(-640,300),Vector2(-1030,300),Vector2(-1070,30),Vector2(-1020,-250),Vector2(-1040,-540),Vector2(-1040,-900),Vector2(-900,-1060),Vector2(-580,-1080),Vector2(-260,-1040),Vector2(80,-1010),Vector2(380,-1030),Vector2(740,-1060),Vector2(1010,-960),Vector2(1080,-730)]+HOLDING_LOOP+[Vector2(950,-450),Vector2(780,-310),Vector2(660,-130),Vector2(580,-180),Vector2(610,-230),Vector2(600,-280),Vector2(555,-285)]
