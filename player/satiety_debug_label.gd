extends Label


@onready var survival: SurvivalComponent = (
	$"../../../SurvivalComponent"
)


func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	survival.satiety_changed.connect(
		_on_satiety_changed
	)


	_on_satiety_changed(
		survival.satiety,
		survival.max_satiety
	)


func _on_satiety_changed(
	current_satiety: float,
	maximum_satiety: float
) -> void:

	text = (
		"SATIETY: "
		+ str(
			roundi(
				current_satiety
			)
		)
		+ " / "
		+ str(
			roundi(
				maximum_satiety
			)
		)
	)
