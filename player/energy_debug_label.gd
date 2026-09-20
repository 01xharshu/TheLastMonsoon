extends Label


@onready var survival: SurvivalComponent = (
	$"../../../SurvivalComponent"
)


func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	survival.energy_changed.connect(
		_on_energy_changed
	)


	_on_energy_changed(
		survival.energy,
		survival.max_energy
	)


func _on_energy_changed(
	current_energy: float,
	maximum_energy: float
) -> void:

	text = (
		"ENERGY: "
		+ str(
			roundi(
				current_energy
			)
		)
		+ " / "
		+ str(
			roundi(
				maximum_energy
			)
		)
	)
