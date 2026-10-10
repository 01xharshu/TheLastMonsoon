extends SceneTree
class ClearanceFixture extends Node3D:
 var clearance_shapes:Array[CollisionShape3D]=[]
class CoachFixture extends Node3D:
 var boarding:ClearanceFixture
class Probe:
 extends "res://world/suryagarh/settlements/household_coach_travel.gd"
 var simulated:=0.0
 var largest_step:=0.0
 func step(delta:float) -> void:
  simulated+=delta;largest_step=maxf(largest_step,delta)
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var near:=Probe.new();var far:=Probe.new()
 var near_view:=Node3D.new();var far_view:=Node3D.new()
 root.add_child(near_view);root.add_child(far_view);far_view.position=Vector3(1000,0,0)
 for probe in [near,far]:
  root.add_child(probe);probe.set_physics_process(false)
  probe.coach=Node3D.new();root.add_child(probe.coach)
  var resident:=Node3D.new();root.add_child(resident);probe.residents.append(resident)
  probe.phase="working";probe.completed_trips=2
 for frame in 360:
  near.advance_budget(1.0/60,near_view)
  far.advance_budget(1.0/60,far_view)
 var errors:Array[String]=[]
 if near.budget_steps!=360 or far.budget_updates!=12:errors.append("near/far cadence mismatch")
 if absf(near.simulated-far.simulated)>.00001:errors.append("distant simulation lost time")
 far_view.position=Vector3(150,0,0)
 var mid_updates:=far.budget_updates
 for frame in 60:far.advance_budget(1.0/60,far_view)
 if far.budget_updates-mid_updates!=10:errors.append("shared middle tier cadence mismatch")
 far_view.position=Vector3(1000,0,0)
 far.residents[0].position=Vector3(1000,0,0)
 far.advance_budget(0,far_view)
 if far.budget_far:errors.append("observer near resident failed to wake household")
 far.advance_budget(5,near_view)
 if far.budget_pending>.100001:errors.append("stall accrued unbounded debt")
 if far.largest_step>.100001:errors.append("remote movement lost bounded collision slices")
 if near.phase!="working" or far.completed_trips!=2:errors.append("budget reset journey state")
 # Physics-only fixtures exercise the production sweep across a thin wall.
 var coach:=CoachFixture.new();root.add_child(coach)
 coach.boarding=ClearanceFixture.new();coach.add_child(coach.boarding)
 var clearance:=CollisionShape3D.new();var vehicle_shape:=BoxShape3D.new();vehicle_shape.size=Vector3.ONE
 clearance.shape=vehicle_shape;coach.boarding.add_child(clearance);coach.boarding.clearance_shapes.append(clearance)
 var filter:=Node3D.new();root.add_child(filter)
 var body_filter:=StaticBody3D.new();body_filter.name="BodyCollider";filter.add_child(body_filter)
 var wall:=StaticBody3D.new();root.add_child(wall);wall.position=Vector3(0,0,5)
 var wall_collision:=CollisionShape3D.new();var wall_shape:=BoxShape3D.new();wall_shape.size=Vector3(10,10,.05)
 wall_collision.shape=wall_shape;wall.add_child(wall_collision)
 near.coach=coach;near.driver=filter;near.residents.clear()
 await physics_frame
 if near._clear(Vector3(0,0,10),Basis.IDENTITY):errors.append("swept clearance skipped thin wall between clear endpoints")
 wall.queue_free();await physics_frame
 if not near._clear(Vector3(0,0,10),Basis.IDENTITY):errors.append("sweep rejected unobstructed travel")
 var report:={"passed":errors.is_empty(),"near_steps":near.budget_steps,"far_updates_before_wake":12,"simulation_seconds":near.simulated,"errors":errors,"scope":"production distance scheduler with instrumented step; full-world route/contact checks remain separate"}
 print("HOUSEHOLD_BUDGET ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
