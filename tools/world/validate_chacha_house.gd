extends SceneTree
class FixtureWorld:
	extends Node3D
	var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:failures.append(label);push_error(label)
func run() -> void:
	var world:=FixtureWorld.new();root.add_child(world)
	var time=load("res://world/suryagarh/systems/game_time_system.gd").new();time.name="GameTimeSystem";world.add_child(time)
	var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
	var house=load("res://world/suryagarh/settlements/chacha_house.gd").new();world.add_child(house)
	await process_frame
	await physics_frame
	check(house.position==Vector3(-425,7.2,214),"surveyed placement")
	var uncle: Node3D=house.get_node("Chacha")
	for dependency in ["ChachaAdvice","EntranceDoor"]:
		var sibling: Node=house.get_node(dependency)
		sibling.name="Pending"+dependency
		uncle._process(1.0/60.0)
		check(uncle.state=="waiting" and uncle.route.is_empty(),"startup waits for "+dependency)
		sibling.name=dependency
	uncle.set_process(false);player.set_physics_process(false)
	player.global_position=house.to_global(Vector3(0,1.1,11))
	for frame in 450:
		uncle._process(1.0/60.0);await physics_frame
	check(uncle.position.z>6 and absf(uncle.position.y)<.01,"uncle reaches courtyard floor")
	player.global_position=house.to_global(Vector3(0,1.1,8))
	for frame in 30:uncle._process(1.0/60.0)
	check(uncle.state=="talking" and uncle.advice_blend>.9,"uncle speaks with animation-tree gesture")
	var conversation: Node=house.get_node("ChachaAdvice")
	check(conversation.line==0 and "brother Dev" in conversation.subtitle.text,"meeting begins with news of Dev")
	conversation._process(float(conversation.LINES[0].seconds))
	check(conversation.current_speaker=="Arjun" and "Still no word" in conversation.subtitle.text,"Arjun answers before weapon advice")
	for frame in 30:uncle._process(1.0/60.0)
	check(uncle.advice_blend<.01,"Chacha listens during Arjun reply")
	conversation._process(float(conversation.LINES[1].seconds))
	check(conversation.current_speaker=="Chacha" and "careful" in conversation.subtitle.text,"concern precedes warning")
	conversation._process(float(conversation.LINES[2].seconds))
	check("bare hands" in conversation.subtitle.text,"armed-men warning follows Dev exchange")
	conversation._process(float(conversation.LINES[3].seconds))
	check("inner room" in conversation.subtitle.text,"weapons offered after warning")
	conversation._process(float(conversation.LINES[4].seconds))
	check("smoke pouches" in conversation.subtitle.text,"escape and repeat stock instructions follow")
	conversation._process(float(conversation.LINES[5].seconds))
	check(not conversation.speaking and not conversation.subtitle.visible,"meeting ends cleanly")
	for frame in 600:
		uncle._process(1.0/60.0);await physics_frame
	check(uncle.state=="settled" and absf(uncle.position.y-.2)<.01,"uncle returns to indoor floor")
	player.set_physics_process(true)
	var kit: Node=player.get_node_or_null("ChachaKit");check(kit!=null,"player kit integrated")
	for id in ["talwar","utility_knife","spear","smoke_bomb"]:
		var rack: Node3D=house.get_node(id.capitalize()+"Rack")
		player.global_position=rack.global_position+Vector3(0,0,1)
		rack.interact(player);rack.interact(player)
		check(player.inventory.has_item(id),id+" collected")
		check(int(player.inventory.items[id])==(3 if id=="smoke_bomb" else 1),id+" duplicate-free repeat")
		check(is_instance_valid(rack),id+" remains available")
	kit.equip("spear");check(kit.active and kit.spear.visible,"spear equipped")
	kit.equip("talwar");check(not kit.active and not kit.spear.visible,"spear removed on switching")
	check(player.get_node("VisualRoot/CharacterVisual").equipment.selected==0,"sword selected")
	kit.equip("utility_knife");check(player.get_node("VisualRoot/CharacterVisual").equipment.selected==4,"knife selected")
	var smoke=load("res://combat/escape_smoke.gd").new();world.add_child(smoke);smoke.global_position=house.global_position+Vector3(0,1,0)
	check(load("res://combat/escape_smoke.gd").obscures(self,smoke.global_position-Vector3(5,0,0),smoke.global_position+Vector3(5,0,0)),"smoke blocks sight")
	check(not load("res://combat/escape_smoke.gd").obscures(self,smoke.global_position+Vector3(5,0,0),smoke.global_position+Vector3(8,0,0)),"outside smoke remains visible")
	smoke.age=10;check(not load("res://combat/escape_smoke.gd").obscures(self,smoke.global_position-Vector3(5,0,0),smoke.global_position+Vector3(5,0,0)),"expired smoke restores sight")
	player.global_position=house.to_global(Vector3(0,1.1,0));player.velocity=Vector3.ZERO
	kit.equip("spear")
	var dummy=load("res://tools/weapons/damage_dummy.gd").new();world.add_child(dummy)
	var hitbox:=CollisionShape3D.new();var target_box:=BoxShape3D.new();target_box.size=Vector3(1.5,1.8,.3);hitbox.shape=target_box;dummy.add_child(hitbox)
	var camera: Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
	player.get_node("CameraPivot").rotation.y=0;player.get_node("CameraPivot").rotation.x=0
	dummy.global_position=player.global_position+Vector3(0,0,-1.05)
	await physics_frame
	check(kit.strike(),"spear thrust starts")
	for i in 35:await physics_frame
	check(dummy.damage_received==28,"visible spear delivers one hit")
	dummy.queue_free();kit.cooldown=0
	check(kit.throw_smoke(),"smoke use starts")
	check(int(player.inventory.items.get("smoke_bomb",0))==2,"smoke consumes one pouch")
	var wheel: Control=player.get_node("UI").find_child("WeaponWheel",true,false)
	if wheel != null:
		wheel.open();wheel.selected=6;wheel.close(true)
		check(kit.active,"wheel selects spear")
		wheel.open();wheel.selected=8;wheel.close(true)
		check(not kit.active,"wheel stows spear")
	kit.equip("spear")
	var manager: Node=root.get_node("SaveManager")
	var temporary:=OS.get_environment("TLM_CHACHA_SAVE_DIR")
	if not temporary.is_empty():
		manager.save_root=temporary
		house.set_meta("advice_given",true)
		check(manager.save_game(world,1),"isolated save")
		player.inventory.items.clear();kit.active=false
		manager.pending_slot=1;manager.apply_pending(world)
		check(kit.active and player.inventory.has_item("spear"),"save restores selected spear")
		check(player.inventory.has_item("talwar") and player.inventory.has_item("utility_knife"),"save restores family blades")
		check(int(player.inventory.items.get("smoke_bomb",0))==2,"save restores smoke count")
		check(house.get_meta("advice_given",false),"save restores advice")
	# Continuous capsule movement uses physics, without waypoint teleports.
	player.set_physics_process(false);player.hide();player.global_position=Vector3.ZERO
	var walker:=CharacterBody3D.new();world.add_child(walker)
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.8;collision.shape=capsule;walker.add_child(collision)
	walker.floor_max_angle=deg_to_rad(45);walker.floor_snap_length=.25
	walker.global_position=house.to_global(Vector3(5,1.15,3.4))
	await physics_frame
	for i in 500:
		walker.velocity=Vector3(0,walker.velocity.y-9.8/60,-1.7);walker.move_and_slide();await physics_frame
		if walker.position.z<house.position.z-4:break
	print("STAIR END ",house.to_local(walker.global_position))
	for j in walker.get_slide_collision_count():print("BLOCK ",walker.get_slide_collision(j).get_collider().get_path()," normal ",walker.get_slide_collision(j).get_normal())
	check(walker.position.y>house.position.y+4 and walker.position.z<house.position.z-4,"continuous stairs reach roof")
	for i in 500:
		walker.velocity=Vector3(0,walker.velocity.y-9.8/60,1.7);walker.move_and_slide();await physics_frame
		if walker.position.z>house.position.z+3.4:break
	print("DESCENT END ",house.to_local(walker.global_position))
	check(walker.position.z>house.position.z+3.4 and walker.position.y<house.position.y+1.3,"roof stairs return indoors")
	print("CHACHA HOUSE: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)

func finish(status: int) -> void:
	quit(status)
