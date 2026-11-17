extends SceneTree
# Read-only landscape survey. No terrain, save data, or captures are written.
func _initialize() -> void:
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
 var rows:Array=[]
 for z in range(-720,601,24):
  for sign_ in [-1,1]:
   var width:float=layout.river_width(z)
   var edge:float=layout.river_x(z)+sign_*width
   var previous:float=layout.height(edge,z)
   for offset in range(0,61,3):
    var x:float=edge+sign_*offset
    var h:float=layout.height(x,z)
    if h>=.0 and previous<.0:
     var heights:Array=[]
     for distance in [0.0,3.0,6.0,9.0,12.0,15.0]:heights.append(layout.height(x+sign_*distance,z))
     rows.append({"z":z,"side":sign_,"x":x,"heights":heights,"rise_12m":heights[4]-heights[0]})
     break
    previous=h
 rows.sort_custom(func(a,b):return absf(a.rise_12m)<absf(b.rise_12m))
 print("LOW_BANK_SURVEY ",JSON.stringify(rows.slice(0,20)))
 quit()
