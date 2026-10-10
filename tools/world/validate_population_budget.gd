extends SceneTree
## Logical route/tier/save parity without allocating human rigs or writing output.
const Budget = preload("res://systems/simulation_budget.gd")
const Population = preload("res://world/suryagarh/city_route_population.gd")
class CowProbe extends "res://animals/cow_motion.gd":
 var steps := 0
 var total := 0.0
 func tick(delta: float) -> void:
  steps+=1;total+=delta
var failed := false
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
 if not ok:failed=true;push_error(label)
func run() -> void:
 var viewer:=Node3D.new();var subject:=Node3D.new()
 root.add_child(viewer);root.add_child(subject)
 for spec in [[0.0,0.0],[80.0,0.0],[81.0,.1],[200.0,.1],[201.0,.5]]:
  subject.position.x=spec[0]
  check(is_equal_approx(Budget.interval(subject,viewer),spec[1]),"Distance tier boundary changed")
 check(Budget.interval(subject,viewer,true)==0,"Essential behavior was throttled")
 var cow:=CowProbe.new();cow.cow=subject;cow.viewer=viewer
 for frame in 120:cow._physics_process(1.0/60.0)
 check(cow.steps<=4 and cow.total>1.5,"Remote cattle cadence did not retain elapsed behavior time")
 subject.position.x=0
 var before:=cow.steps
 cow._physics_process(1.0/60.0)
 check(cow.steps==before+1,"Approaching cattle did not restore full update immediately")
 cow.free()
 var population:=Population.new()
 var points:Array[Vector2]=[Vector2.ZERO,Vector2(10,0)]
 var record:Dictionary={"kind":"person","route":"test","index":0,"count":1,"points":points,"phase":{"point":Vector2.ZERO,"goal":1},"direction":1,"wait":0.0}
 population.pending.append(record)
 for step in 20:population.advance_remote(.5)
 check(is_equal_approx(record.phase.point.x,7.8),"Remote destination progress lost elapsed time")
 var state:=population.export_route_state()
 population.advance_remote(1)
 population.restore_route_state(state)
 check(is_equal_approx(record.phase.point.x,7.8),"Logical save roundtrip changed position")
 check(population.export_route_state()==state,"Logical save roundtrip changed route state")
 population.advance_remote(3)
 check(record.direction==-1 and record.wait==6.0,"Remote arrival lost endpoint pause")
 population.advance_remote(3)
 check(record.wait==3.0,"Remote pause failed to advance")
 # Restore incapacitation in a logical record: never move a dead resident.
 var dead:Dictionary={"test:0":{"point":[5.0,0.0],"goal":1,"direction":1,"wait":0.0,"dead":true,"health":0.0}}
 population.restore_route_state(dead)
 population.advance_remote(10)
 check(record.phase.point==Vector2(5,0),"Dead remote resident moved")
 check(population.pedestrians.is_empty(),"Logical simulation allocated physical residents")
 population.free();subject.queue_free();viewer.queue_free()
 print("POPULATION BUDGET ","FAIL" if failed else "PASS"," | tier boundaries, essential bypass, logical progress/arrival, save roundtrip, incapacitation; no rigs allocated")
 await root.get_node("SaveManager").quit_game(1 if failed else 0)
