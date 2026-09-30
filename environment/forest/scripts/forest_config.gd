class_name ForestConfig
extends Resource

@export var seed: int = 1857
@export_range(0.0, 2.0, 0.01) var overall_density: float = 1.0
@export_range(6.0, 30.0, 1.0) var chunk_size: float = 12.0
@export_range(0.001, 0.2, 0.001) var biome_noise_scale: float = 0.035
@export_range(0.0, 1.0, 0.01) var biome_threshold: float = 0.15
@export_range(0.0, 1.0, 0.01) var max_slope: float = 0.4
@export_range(-100.0, 300.0, 0.1) var min_height: float = 0.0
@export_range(-100.0, 300.0, 0.1) var max_height: float = 20.0
@export_range(0.0, 2.0, 0.01) var hero_density: float = 0.35
@export_range(0.0, 2.0, 0.01) var canopy_density: float = 0.8
@export_range(0.0, 2.0, 0.01) var small_tree_density: float = 0.4
@export_range(0.0, 2.0, 0.01) var dead_tree_density: float = 0.12
@export_range(0.0, 2.0, 0.01) var fallen_log_density: float = 0.2
@export_range(0.0, 2.0, 0.01) var shrub_density: float = 0.8
@export_range(0.0, 2.0, 0.01) var broadleaf_density: float = 0.7
@export_range(0.0, 2.0, 0.01) var tall_grass_density: float = 0.8
@export_range(0.0, 2.0, 0.01) var short_grass_density: float = 1.0
@export_range(0.0, 2.0, 0.01) var floor_density: float = 0.8
@export_range(0.0, 2.0, 0.01) var rock_density: float = 0.3
@export_range(0.0, 2.0, 0.01) var debris_density: float = 0.3
@export_range(0.0, 1.0, 0.01) var shelf_fungus_probability: float = 0.28
@export_range(0.5, 10.0, 0.1) var path_exclusion_radius: float = 3.0
@export_range(0.0, 3.0, 0.1) var path_feather: float = 2.0
@export_range(0.0, 8.0, 0.1) var tree_path_clearance: float = 2.5
@export_range(0.0, 2.0, 0.1) var minimum_tree_separation: float = 3.5
@export var tree_scale_range: Vector2 = Vector2(0.8, 1.35)
@export var plant_scale_range: Vector2 = Vector2(0.75, 1.35)
@export_range(0.0, 2.0, 0.05) var wind_strength: float = 0.25
@export var near_distance: float = 24.0
@export var medium_distance: float = 48.0
@export var far_distance: float = 80.0
@export var enable_collisions: bool = true
