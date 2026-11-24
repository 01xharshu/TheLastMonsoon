extends RefCounted
## Single field footprint authority for planting and vegetation exclusion.
static func plots() -> Array:
 var list: Array=[]
 for i in 6:
  var z: float=-420+float(i)*165
  list.append(["LongCane%d"%i,"sugarcane",Vector2(-620,z),Vector2(64,144)])
  list.append(["WestKharif%d"%i,["maize","sorghum","sesame"][i%3],Vector2(-535,z),Vector2(66,144)])
 list.append(["InlandMaize","maize",Vector2(-355,-267),Vector2(136,76)])
 list.append(["SouthSorghum","sorghum",Vector2(-360,427),Vector2(130,74)])
 list.append(["VillageSesame","sesame",Vector2(-315,55),Vector2(90,90)])
 return list
static var cached_plots: Array=[]
static func clearance(p: Vector2) -> float:
 var result:=INF
 if cached_plots.is_empty(): cached_plots=plots()
 for plot in cached_plots:
  var d: Vector2=(p-plot[2]).abs()-plot[3]*0.5
  result=minf(result,Vector2(maxf(d.x,0),maxf(d.y,0)).length())
 return result
