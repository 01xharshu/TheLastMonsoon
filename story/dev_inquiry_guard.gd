extends "res://characters/npcs/thana/thana_officer.gd"
## Existing complete MPFB private; shared Enfield carry, no additional firing AI.
var rifle: Node3D
func _ready() -> void:
	super._ready()
	rifle=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
	rifle.name="GuardEnfield";add_child(rifle)
func _process(delta: float) -> void:
	super._process(delta)
	if rifle==null or _skeleton==null:return
	if get_meta("dead",false) or get_meta("knocked_out",false):return
	rifle.show()
	if duty_state in ["restraint","escort","fight"]:
		var back_basis:=global_basis*Basis(Vector3(-.25,.968,0).normalized(),Vector3.FORWARD,Vector3(-.25,.968,0).normalized().cross(Vector3.FORWARD))
		rifle.global_transform=Transform3D(back_basis.scaled(Vector3.ONE*.85),to_global(Vector3(.16,.8,-.23)))
		return
	var barrel: Vector3=(global_basis.z*.32+Vector3.UP*.947).normalized()
	var side:=barrel.cross(Vector3.UP).normalized()
	var basis:=Basis(barrel,side.cross(barrel).normalized(),side)
	var contact:=to_global(Vector3(-.22,.98,.16))
	rifle.global_transform=Transform3D(basis.scaled(Vector3.ONE*.85),contact-basis*(Vector3(-.09,-.045,0)*.85))
	# The custody controller owns the hands during restraint and escort.
	solve_hand_contact("r",contact);set_grip("r",.35)
	solve_hand_contact("l",rifle.to_global(Vector3(.20,-.032,0)));set_grip("l",.35)
