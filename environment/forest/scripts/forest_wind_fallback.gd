extends Node
## Standalone-project fallback. TheLastMonsoon keeps its existing WindSystem.
var elapsed := 0.0
func _process(delta: float) -> void:
	elapsed += delta
	var gust := 1.3 + 0.5 * sin(elapsed * 0.31)
	RenderingServer.global_shader_parameter_set("world_wind", Vector3(gust, elapsed, gust * 0.4))
