import bpy


def describe_scene(scene):
    cameras = [obj.name for obj in scene.objects if obj.type == "CAMERA"]
    armatures = [obj.name for obj in scene.objects if obj.type == "ARMATURE"]
    actions = [action.name for action in bpy.data.actions]

    print(f"scene={scene.name}")
    print(f"frame_range={scene.frame_start}-{scene.frame_end}")
    print(f"fps={scene.render.fps}/{scene.render.fps_base}")
    print(f"object_count={len(scene.objects)}")
    print(f"camera_count={len(cameras)}")
    if cameras:
        print(f"cameras={','.join(cameras)}")
    print(f"armature_count={len(armatures)}")
    if armatures:
        print(f"armatures={','.join(armatures)}")
    print(f"action_count={len(actions)}")
    if actions:
        print(f"actions={','.join(actions)}")


active_scene = bpy.context.scene
print(f"active_scene={active_scene.name}")
describe_scene(active_scene)
