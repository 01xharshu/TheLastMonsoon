extends Label


@onready var survival: SurvivalComponent = (
	$"../../../SurvivalComponent"
)


func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	survival.stamina_changed.connect(
		_on_stamina_changed
	)


	survival.exhaustion_changed.connect(
		_on_exhaustion_changed
	)


	_refresh_display()


func _on_stamina_changed(
	_current_stamina: float,
	_maximum_stamina: float
) -> void:

	_refresh_display()


func _on_exhaustion_changed(
	_exhausted: bool
) -> void:

	_refresh_display()


func _refresh_display() -> void:

	var status_text := ""


	if survival.is_exhausted:

		status_text = " [EXHAUSTED]"


	text = (
		"STAMINA: "
		+ str(
			roundi(
				survival.stamina
			)
		)
		+ " / "
		+ str(
			roundi(
				survival.max_stamina
			)
		)
		+ status_text
	)
