extends Node
## Capture every fixed simulation frame, including frames skipped by a hidden window.
var frame:=0
var elapsed:=0.0
var min_delta:=INF
var max_delta:=0.0
const OUT:="/tmp/tlm_staff_latch_frames"
func _ready() -> void:
	process_priority=10000
	DirAccess.make_dir_recursive_absolute(OUT)
func _process(delta: float) -> void:
	if frame>=1400:return
	elapsed+=delta;min_delta=minf(min_delta,delta);max_delta=maxf(max_delta,delta)
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_png(OUT+"/%06d.png"%frame)
	frame+=1
func _exit_tree() -> void:
	var file:=FileAccess.open(OUT+"/timing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":frame,"simulation_seconds":elapsed,"delta_min":min_delta,"delta_max":max_delta,"fps":30,"pixels":[1280,720]},"\t"))
