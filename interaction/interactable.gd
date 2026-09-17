class_name Interactable
extends StaticBody3D


@export var interaction_text: String = "Interact"


func interact(player: CharacterBody3D) -> void:
	print("Interaction triggered.")
