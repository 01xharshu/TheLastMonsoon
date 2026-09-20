extends Label


@onready var survival: SurvivalComponent = (
	$"../../../SurvivalComponent"
)


func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	survival.hydration_changed.connect(
		_on_hydration_changed
	)


	_on_hydration_changed(
		survival.hydration,
		survival.max_hydration
	)


func _on_hydration_changed(
	current_hydration: float,
	maximum_hydration: float
) -> void:

	text = (
		"HYDRATION: "
		+ str(
			roundi(
				current_hydration
			)
		)
		+ " / "
		+ str(
			roundi(
				maximum_hydration
			)
		)
	)
