"""Export the supplied Blender prop sources as Godot-ready static GLBs."""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "environment/props/new_assets"
OUT.mkdir(parents=True, exist_ok=True)

for name in ("wooden_gun_carriage_v1", "wooden_signboard"):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "WorkingAssets" / f"{name}.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT"} or obj.name == "GUNCARR_GROUND_GUIDE":
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == "FONT":
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.convert(target="MESH")
            obj.select_set(False)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"),
        export_format="GLB",
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"EXPORTED {name}")
