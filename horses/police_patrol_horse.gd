extends "res://horses/stable_horse.gd"
## Autonomous patrol mount uses the live horse rig, collision, hoof contacts and sound.
var officer: Node3D
var goal := Vector3.ZERO
var commanded_speed := 0.0
var animation_elapsed := 0.0
var blocked_age := 0.0
func _ready() -> void:
	super._ready()
	remove_from_group("mountable_vehicles")
	remove_from_group("horses")
	add_to_group("police_mounts")
func _physics_process(delta: float) -> void:
	if vitality.dead:
		_death_step(delta)
		return
	var toward := goal-global_position;toward.y=0
	if toward.length()>.6 and commanded_speed>0:
		rotation.y=rotate_toward(rotation.y,atan2(-toward.x,-toward.z),delta*1.5)
	var alignment := maxf(0.0,(-global_basis.z).dot(toward.normalized()))
	var speed := commanded_speed*alignment if toward.length()>.6 else 0.0
	pace=move_toward(pace,speed,delta*4.0)
	velocity.x=-global_basis.z.x*pace
	velocity.z=-global_basis.z.z*pace
	velocity.y-=float(ProjectSettings.get_setting("physics/3d/default_gravity"))*delta
	var before:=global_position
	move_and_slide()
	blocked_age=blocked_age+delta if speed>.5 and global_position.distance_to(before)<.005 else 0.0
	animation_elapsed+=delta
	var essential:bool=is_instance_valid(officer) and officer.get_meta("police_engaged",false)
	if animation_elapsed<preload("res://systems/simulation_budget.gd").interval(self,get_viewport().get_camera_3d(),essential):return
	delta=animation_elapsed;animation_elapsed=0.0
	_update_rigged_animation()
	rigged_anim.advance(delta)
	tack_root.transform=_animated_frame_delta("Torso")
	_update_hoof_contacts(delta)

func _rein_anchors(side: String) -> Array[Vector3]:
	var anchors := super._rein_anchors(side)
	if is_instance_valid(officer) and officer.patrol_mount==self and not officer.get_meta("riding_reins_released",false):
		anchors[1]=officer.palm_world(side)
	return anchors
