extends Node
## Batch ledger advances from the world clock, including while the player is away.
const PHASES=["receiving","steeping","beating","settling","pressing","drying","packing"]
const MINUTES=[30.0,240.0,480.0,60.0,60.0,4320.0,60.0]
var factory:Node3D
var clock:Node
var player:CharacterBody3D
var phase:="receiving"
var phase_minutes:=0.0
var raw_bundles:=24
var finished_crates:=0
var batches:=0
var discovered:=false
var record_read:=false
var workers:Array[Node3D]=[]
var configured:=false
var pending:Dictionary={}
var last_minutes:=0.0
var poll:=0.0

func configure(site:Node3D) -> void:
	factory=site;clock=factory.get_parent().get_node("GameTimeSystem");player=factory.get_parent().get_node_or_null("Player")
	add_to_group("institution_operations")
	set_meta("entity_id","factory.operations")
	last_minutes=clock.total_game_minutes
	var positions:Array[Vector3]=[
		factory.get_node("FactoryArchitecture/SteppedVats").to_global(Vector3(-6,.17,2.6)),
		factory.point(Vector2(-16,1))+Vector3.UP*.035,
		factory.get_node("FactoryArchitecture/PressHouse").to_global(Vector3(1.25,0,0))]
	for i in 3:
		await preload("res://systems/world_startup.gd").checkpoint(self,"Preparing indigo workers…")
		var worker=preload("res://world/suryagarh/settlements/indigo_factory_worker.gd").new()
		worker.name=["VatWorker","LeafCarrier","PressWorker"][i];worker.role=["beater","carrier","press"][i];worker.factory=factory
		worker.set_meta("entity_id","factory.worker."+worker.role);worker.set_meta("combat_faction","indian")
		worker.set_meta("population_expansion_exempt",true)
		worker.set_meta("visual_status","existing MPFB workman candidate; no new garment/art approval")
		worker.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/workman_0%d.glb"%(i+1)))
		factory.add_child(worker);worker.global_position=positions[i]
		worker.path.assign([positions[i],factory.point(Vector2(-5,1))+Vector3.UP*.035])
		worker.rotation.y=-PI*.5 if i==2 else PI
		workers.append(worker)
	configured=true
	if not pending.is_empty():restore_state(pending);pending.clear()
	update_liquor()

func is_open() -> bool:
	return clock!=null and clock.current_hour>=6 and clock.current_hour<18

func _process(delta:float) -> void:
	if not configured or get_tree().paused:return
	poll+=delta
	if poll<.5:return
	poll=0
	var now:float=clock.total_game_minutes
	advance_calendar(last_minutes,now);last_minutes=now
	if not discovered and player!=null and player.global_position.distance_squared_to(factory.point(Vector2.ZERO))<80*80:
		discovered=true

func advance_calendar(start:float,end:float) -> void:
	# Split rest/time jumps at shift boundaries, rather than applying the final hour.
	var cursor:=start
	for _segment in 128:
		if cursor>=end:break
		var day:=floorf(cursor/1440.0)*1440.0
		var minute:=fposmod(cursor,1440.0)
		var staffed:=minute>=360.0 and minute<1080.0
		var boundary:=day+(360.0 if minute<360.0 else 1080.0 if minute<1080.0 else 1800.0)
		var finish:=minf(end,boundary)
		advance(finish-cursor,staffed);cursor=finish
		if phase=="receiving" and raw_bundles<4:break

func advance(minutes:float,staffed_override:Variant=null) -> void:
	# Wet chemistry/drying continues overnight; staffed phases stop outside hours.
	var staffed:bool=is_open() if staffed_override==null else bool(staffed_override)
	if minutes<=0 or (phase not in ["steeping","settling","drying"] and not staffed):return
	phase_minutes+=minutes
	for _iteration in 32:
		var index:=PHASES.find(phase)
		if phase_minutes<MINUTES[index]:break
		if phase=="receiving" and raw_bundles<4:phase_minutes=MINUTES[index];break
		phase_minutes-=MINUTES[index]
		if phase=="receiving":raw_bundles-=4
		if phase=="packing":finished_crates+=1;batches+=1
		phase=PHASES[(index+1)%PHASES.size()]
		if phase not in ["steeping","settling","drying"] and not staffed:phase_minutes=0;break
	update_liquor()

func update_liquor() -> void:
	if factory==null:return
	if factory.drying_cakes!=null:factory.drying_cakes.visible=phase in ["drying","packing"]
	for i in factory.raw_loads.size():factory.raw_loads[i].visible=raw_bundles>i*8
	for i in factory.liquids.size():
		var mat:StandardMaterial3D=factory.liquids[i].material_override
		var role:String=factory.liquids[i].get_meta("vat_role","")
		mat.albedo_color=Color(.27,.34,.12) if role=="Steeper" else (Color(.10,.17,.33) if phase not in ["receiving","steeping"] else Color(.20,.31,.23))

func can_request(id:String) -> bool:
	return configured and player!=null and player.health>0 and factory.stations.has(id) and not player.get_meta("opening_active",false) and preload("res://systems/action_permissions.gd").allowed(player,&"interact")

func request(id:String,actor:CharacterBody3D) -> bool:
	if actor!=player or actor.health<=0 or not factory.stations.has(id):return false
	if actor.global_position.distance_to(factory.stations[id].global_position)>2.6:return false
	if not preload("res://systems/action_permissions.gd").allowed(actor,&"interact") or actor.get_meta("opening_active",false):return false
	discovered=true
	var text:=""
	match id:
		"accounts":
			record_read=true;text="The ledger lists plant deliveries, workers’ wages and outgoing indigo."
		"vats":text="Leaves steep above. Liquor drains below for paddle beating. Green plants become blue dye."
		"press":text="Settled dye is drained and pressed through cloth. This timber press is turned by hand."
		"settle":text="Beaten liquor settles here. Clear water drains; the dye paste is strained through cloth."
		"dry":text="Cakes dry on shaded, ventilated racks before packing. This batch is currently "+phase+"."
		"pack":text="Ready for shipment: %d indigo crates. The farm lane leads toward the village and port."%finished_crates
		"load":text="Fresh plant bundles received: %d. Four bundles are assigned to each small batch."%raw_bundles
		_:return false
	# The existing feed draws single 260px rows; send short rows through its owner.
	var row:=""
	for word:String in text.split(" "):
		if not row.is_empty() and row.length()+word.length()+1>25:
			actor.get_node("InventoryComponent").request_message(row);row=""
		row+= (" " if not row.is_empty() else "")+word
	if not row.is_empty():actor.get_node("InventoryComponent").request_message(row)
	return true

func export_state() -> Dictionary:
	if not configured:return pending.duplicate(true)
	var people:Dictionary={}
	for worker in workers:people[str(worker.get_meta("entity_id"))]=worker.export_state()
	return {"version":1,"phase":phase,"phase_minutes":phase_minutes,"raw_bundles":raw_bundles,"finished_crates":finished_crates,"batches":batches,"discovered":discovered,"record_read":record_read,"workers":people}

func restore_state(data:Dictionary) -> void:
	if not configured:pending=data.duplicate(true);return
	phase=str(data.get("phase","receiving"))
	if phase not in PHASES:phase="receiving"
	phase_minutes=maxf(0,float(data.get("phase_minutes",0)));raw_bundles=maxi(0,int(data.get("raw_bundles",24)))
	finished_crates=maxi(0,int(data.get("finished_crates",0)));batches=maxi(0,int(data.get("batches",0)))
	discovered=bool(data.get("discovered",false));record_read=bool(data.get("record_read",false))
	last_minutes=clock.total_game_minutes
	var people:Dictionary=data.get("workers",{})
	for worker in workers:
		var key:=str(worker.get_meta("entity_id"))
		if people.get(key) is Dictionary:worker.restore_state(people[key])
	update_liquor()
