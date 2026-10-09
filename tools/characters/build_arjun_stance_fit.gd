extends SceneTree
## Rebuild runtime garment assets from the retained complete MPFB body.
const Fit = preload("res://player/arjun_stance_garment_fit.gd")
func _initialize() -> void: _build.call_deferred()
func _build() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	var records := Fit.prepare_low_waist(actor.get_node("VisualRoot/CharacterVisual").model,true)
	DirAccess.make_dir_recursive_absolute(Fit.CACHE_DIR)
	var names: Array[String] = []
	for record in records:
		var name := str(record.node.name)
		var result := ResourceSaver.save(record.low,Fit.CACHE_DIR+"/"+name.validate_filename()+".res")
		if result != OK:
			push_error("Stance garment asset could not be saved: "+name)
			quit(1)
			return
		names.append(name)
	var file := FileAccess.open(Fit.CACHE_DIR+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fingerprint":Fit.fingerprint(),"inputs":Fit.INPUTS,"garments":names,"construction":"Existing garment vertices fitted and weighted against the complete MPFB body; body retained unchanged."},"\t")+"\n")
	file.close()
	print("STANCE GARMENT ASSETS BUILT: ",names.size()," existing garments; complete body preserved")
	stage.queue_free()
	for i in 4: await process_frame
	quit.call_deferred()
