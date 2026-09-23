extends Node
## Reputation is earned by completed world actions, never by opening the dossier.
signal fame_changed(points: int, reason: String)

var points := 0
var witnessed_deeds := 0

func award_flag_cut() -> void:
	_award(1, "British flag cut")

func award_help() -> void:
	_award(4, "Person helped")

func _award(amount: int, reason: String) -> void:
	points += amount
	fame_changed.emit(points, reason)

func mark_witnessed() -> void:
	witnessed_deeds += 1

func recognition_markers() -> Array[String]:
	var markers: Array[String] = []
	if points >= 1: markers.append("Stories travel")
	if points >= 8: markers.append("Face remembered")
	if witnessed_deeds > 0: markers.append("Deed witnessed")
	return markers
