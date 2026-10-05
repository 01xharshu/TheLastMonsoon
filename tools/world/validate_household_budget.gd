extends SceneTree
class Probe:
 extends "res://world/suryagarh/settlements/household_coach_travel.gd"
 var simulated:=0.0
 func step(delta:float) -> void:simulated+=delta
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var near:=Probe.new();var far:=Probe.new()
 for probe in [near,far]:
  root.add_child(probe);probe.set_physics_process(false)
  probe.coach=Node3D.new();root.add_child(probe.coach)
  var resident:=Node3D.new();root.add_child(resident);probe.residents.append(resident)
  probe.phase="working";probe.completed_trips=2
 for frame in 360:
  near.advance_budget(1.0/60,Vector3.ZERO)
  far.advance_budget(1.0/60,Vector3(1000,0,0))
 var errors:Array[String]=[]
 if near.budget_steps!=360 or far.budget_steps!=60:errors.append("near/far cadence mismatch")
 if absf(near.simulated-far.simulated)>.00001:errors.append("distant simulation lost time")
 far.advance_budget(0,Vector3(165,0,0))
 if not far.budget_far:errors.append("hysteresis woke early")
 far.residents[0].position=Vector3(1000,0,0)
 far.advance_budget(0,Vector3(1000,0,0))
 if far.budget_far:errors.append("observer near resident failed to wake household")
 far.advance_budget(5,Vector3.ZERO)
 if far.budget_pending>.100001:errors.append("stall accrued unbounded debt")
 if near.phase!="working" or far.completed_trips!=2:errors.append("budget reset journey state")
 var report:={"passed":errors.is_empty(),"near_steps":near.budget_steps,"far_steps_before_wake":60,"simulation_seconds":near.simulated,"errors":errors,"scope":"production distance scheduler with instrumented step; full-world route/contact checks remain separate"}
 FileAccess.open("res://docs/world/household_budget_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("HOUSEHOLD_BUDGET ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
