extends RefCounted
## A road's physical support plane supplies local garment floor samples.
## The journey refreshes it from its existing terrain ray; no extra per-hem noise sampling.
var point:=Vector3.ZERO
var normal:=Vector3.UP

func set_support(support:Dictionary) -> void:
 if support.is_empty():return
 point=support.position
 normal=support.get("normal",Vector3.UP)
 if normal.y<.6:normal=Vector3.UP

func height(x:float,z:float) -> float:
 return point.y-(normal.x*(x-point.x)+normal.z*(z-point.z))/normal.y
