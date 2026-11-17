extends SceneTree
const Motion = preload("res://characters/npcs/adult_secondary_motion.gd")
var issues: Array[String] = []
var checks := 0
func _initialize() -> void:run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:issues.append(label);push_error(label)
func response(hz: float, support: float) -> Dictionary:
	var motion:=Motion.new();motion.clothing_support=support
	var state:=Motion.ElasticState.new();var peak:=0.0
	for frame in int(hz*4):
		var at:=float(frame)/hz
		var acceleration:=Vector3(.6*sin(at*TAU),2.8*sin(at*TAU*2.2),.4*cos(at*TAU*1.4)) if at<2.0 else Vector3.ZERO
		state.advance(1.0/hz,acceleration*(.60-.35*support),motion.frequency_hz(),.62+.25*support,motion.limit_m())
		peak=maxf(peak,state.offset.length())
	return {"peak":peak,"residual":state.offset.length(),"limit":motion.limit_m()}
func run() -> void:
	var rest:=Motion.ElasticState.new()
	for frame in 240:rest.advance(1.0/60.0,Vector3.ZERO,3.5,.8,.006)
	check(rest.offset==Vector3.ZERO,"no invented motion at rest")
	var results: Array[Dictionary]=[]
	for hz in [30.0,60.0,120.0]:
		var result:=response(hz,.72);results.append(result)
		check(result.peak>.0001 and result.peak<=result.limit+.000001,"bounded inertial response "+str(hz))
		check(result.residual<.00005,"settles after input stops "+str(hz))
	check(absf(results[0].peak-results[2].peak)<.0005,"30/120Hz response agreement")
	check(response(60,.95).peak<response(60,.20).peak,"clothing support restrains response")
	rest.offset=Vector3.ONE*.002;rest.velocity=Vector3.ONE
	rest.advance(.5,Vector3.ONE*20,3.5,.8,.006)
	check(rest.offset==Vector3.ZERO and rest.velocity==Vector3.ZERO,"remote/load gap resets cosmetic transient")
	var child:=Node3D.new();root.add_child(child);var skeleton:=Skeleton3D.new();child.add_child(skeleton)
	var guarded:=Motion.new();guarded.configure(child,skeleton)
	check(guarded.entries.is_empty(),"unmarked or age-ambiguous character is excluded")
	child.free()
	print("ADULT_SECONDARY_MOTION ",JSON.stringify({"passed":issues.is_empty(),"checks":checks,"issues":issues,"cadences":results}))
	quit(0 if issues.is_empty() else 1)
