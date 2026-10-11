extends Node
## Decorative geometry only. Persistent gameplay and collision stay with the world.
var regions: Dictionary={}
var age:=0.0
const APPROACH_MARGIN:=180.0
const LEAVE_MARGIN:=220.0

func register(identity: String, center: Vector3, extent: float, factory: Callable) -> void:
	assert(not regions.has(identity))
	regions[identity]={"center":center,"extent":extent,"factory":factory,"instance":null}

func _process(delta: float) -> void:
	age-=delta
	if age>0:return
	age=.2
	var viewer:=get_viewport().get_camera_3d()
	if viewer==null:return
	update_viewer(viewer.global_position)

func update_viewer(at: Vector3) -> void:
	for region in regions.values():
		var radius:float=region.extent+(LEAVE_MARGIN if is_instance_valid(region.instance) else APPROACH_MARGIN)
		var offset:Vector3=region.center-at;offset.y=0
		if offset.length_squared()<=radius*radius:
			if not is_instance_valid(region.instance):
				region.instance=region.factory.call()
				add_child(region.instance)
		elif is_instance_valid(region.instance):
			region.instance.queue_free()
			region.instance=null

func unload_all() -> void:
	for region in regions.values():
		if is_instance_valid(region.instance):region.instance.queue_free()
		region.instance=null
