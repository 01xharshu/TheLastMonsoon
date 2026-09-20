extends Label


@onready var game_time: GameTimeSystem = (
	$"../../../../GameTimeSystem"
)


func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	if game_time == null:

		text = "GAME TIME\nNOT FOUND"

		push_error(
			"GameTimeDebugLabel could not find "
			+ "GameTimeSystem."
		)

		return


	game_time.time_changed.connect(
		_on_time_changed
	)


	_refresh_display()


func _on_time_changed(
	_day: int,
	_hour: int,
	_minute: int
) -> void:

	_refresh_display()


func _refresh_display() -> void:

	if game_time == null:
		return


	text = (
		game_time.get_day_text()
		+ "\n"
		+ game_time.get_formatted_time()
	)
