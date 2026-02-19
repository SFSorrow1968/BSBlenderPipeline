import bpy
from mathutils import Vector

scene = bpy.context.scene

print(f"SCENE={scene.name}")
print(f"FRAME={scene.frame_start}-{scene.frame_end}")
print(f"FPS={scene.render.fps}/{scene.render.fps_base}")
print(f"RES={scene.render.resolution_x}x{scene.render.resolution_y}")
print(f"ENGINE={scene.render.engine}")
print(f"CAMERA={scene.camera.name if scene.camera else 'None'}")


def object_world_center(obj):
    if obj.type == "MESH" and obj.data and len(obj.data.vertices) > 0:
        verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
        center = Vector((0.0, 0.0, 0.0))
        for v in verts:
            center += v
        return center / len(verts)
    return obj.matrix_world.translation


for obj in scene.objects:
    if obj.type in {"ARMATURE", "MESH", "CAMERA", "LIGHT"}:
        center = object_world_center(obj)
        print(
            f"OBJ={obj.name} TYPE={obj.type} "
            f"hide_render={obj.hide_render} hide_view={obj.hide_viewport} "
            f"loc=({obj.location.x:.3f},{obj.location.y:.3f},{obj.location.z:.3f}) "
            f"center=({center.x:.3f},{center.y:.3f},{center.z:.3f}) "
            f"scale=({obj.scale.x:.3f},{obj.scale.y:.3f},{obj.scale.z:.3f})"
        )
