class_name ForestSpecies
extends Resource
## Replaceable Blender asset plus placement/collision policy. All dimensions in metres.
@export_enum("hero", "canopy", "canopy_broad", "small_tree", "dead_tree", "fallen_log", "fern", "shrub", "broadleaf", "tall_grass", "short_grass", "floor", "rock", "debris", "shelf_fungus") var layer: String = "canopy"
@export var near_scene: PackedScene
@export var medium_scene: PackedScene
@export var far_scene: PackedScene
@export_range(0.0, 3.0, 0.01) var density_multiplier: float = 1.0
@export var scale_range := Vector2(0.8, 1.25)
@export_range(0.0, 10.0, 0.1) var minimum_separation: float = 0.0
@export_range(0.0, 1.0, 0.01) var max_slope: float = 0.4
@export var height_range := Vector2(-100.0, 300.0)
@export_range(0.0, 8.0, 0.1) var extra_path_clearance: float = 0.0
@export_range(0.0, 3.0, 0.05) var root_radius: float = 0.0
@export var collision_radius: float = 0.0
@export var collision_height: float = 0.0
@export var ground_offset: float = 0.0
@export var align_to_ground: bool = false
@export var receives_attachments: bool = false
