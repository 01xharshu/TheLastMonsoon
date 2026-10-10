extends RefCounted
## Cheap counters outside measured frames. GPU counters cover this engine process;
## they are neither attributable project residency nor additive to Apple RSS.
static func allocation(info: RenderingServer.RenderingInfo) -> Variant:
	var bytes := RenderingServer.get_rendering_info(info)
	# This Metal build can return a negative texture counter. Do not reinterpret
	# it as unsigned bytes or silently turn an invalid counter into a budget.
	return bytes if bytes >= 0 else null

static func capture() -> Dictionary:
	var native := RenderingServer.get_rendering_device() != null
	return {
		"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"renderer_allocation_bytes":allocation(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) if native else null,
		"renderer_texture_bytes":allocation(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) if native else null,
		"renderer_buffer_bytes":allocation(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) if native else null,
		"pipeline_mesh":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH) if native else null,
		"pipeline_surface":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE) if native else null,
		"pipeline_draw":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW) if native else null,
		"pipeline_background_specialization":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION) if native else null,
	}
