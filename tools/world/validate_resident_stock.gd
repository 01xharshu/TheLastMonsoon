extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var operations:Node=load("res://world/suryagarh/settlements/cantonment_operations.gd").new()
 var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();root.add_child(clock);clock.clock_paused=true
 operations.clock=clock;operations.physical_stock_delivery=true
 var care:=CharacterBody3D.new();root.add_child(care);operations.horse=care
 operations.stock={"ration":0,"fodder":0,"dressings":0};operations.stock_day=clock.current_day
 operations._time_changed(clock.current_day+1,8,0)
 check(operations.stock.dressings==0 and operations.stock.ration==0,"day change cannot refill delivered stock")
 check(operations.receive_consignment("hospital",0,0) and operations.stock.dressings==3,"physical hospital parcel credits dressings")
 check(not operations.receive_consignment("hospital",0,0) and operations.stock.dressings==3,"duplicate receipt rejected")
 check(operations.receive_consignment("depot",0,0) and operations.stock.ration==4 and operations.stock.fodder==5,"depot parcels credit actual service stock")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(operations.export_state()))
 operations.stock.dressings=0;operations.delivery_receipts.clear();operations.restore_state(saved)
 check(operations.stock.dressings==3 and not operations.receive_consignment("hospital",0,0),"saved stock and idempotent receipt restored")
 operations.stock.dressings=16;operations.receive_consignment("hospital",1,0)
 check(operations.stock.dressings==16,"bounded inventory capacity")
 print("RESIDENT_STOCK_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=6 failures=",failures)
 operations.free();clock.queue_free();care.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
