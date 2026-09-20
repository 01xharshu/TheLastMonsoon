extends Interactable


# =========================================================
# SETTINGS
# =========================================================

@export_category("Oil Lamp")


@export var starts_lit: bool = true


# =========================================================
# REFERENCES
# =========================================================

@onready var lamp_light: OmniLight3D = (
	$LampLight
)


# =========================================================
# STATE
# =========================================================

var is_lit: bool = false


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	is_lit = starts_lit


	_apply_lamp_state()


# =========================================================
# INTERACTION
# =========================================================

func interact(
	_player: CharacterBody3D
) -> void:

	is_lit = not is_lit


	_apply_lamp_state()


# =========================================================
# APPLY STATE
# =========================================================

func _apply_lamp_state() -> void:

	if lamp_light == null:

		push_error(
			"OilLamp could not find LampLight."
		)

		return


	lamp_light.visible = (
		is_lit
	)


	if is_lit:

		interaction_text = (
			"Extinguish Lamp"
		)


		print(
			"The oil lamp is burning."
		)


	else:

		interaction_text = (
			"Light Lamp"
		)


		print(
			"The oil lamp has been extinguished."
		)
