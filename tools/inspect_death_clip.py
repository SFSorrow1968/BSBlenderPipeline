import bpy

scene = bpy.context.scene
armatures = [o for o in scene.objects if o.type == "ARMATURE"]
if not armatures:
    print("NO_ARMATURE")
    raise SystemExit(1)

armatures.sort(key=lambda o: len(o.data.bones) if o.data else 0, reverse=True)
arm = armatures[0]
print(f"ARMATURE={arm.name}")

if arm.animation_data is None or arm.animation_data.action is None:
    print("NO_ACTIVE_ACTION")
    raise SystemExit(0)

action = arm.animation_data.action
print(f"ACTION={action.name}")
print(f"ACTION_RANGE={tuple(action.frame_range)}")
print(f"SCENE_RANGE={scene.frame_start}-{scene.frame_end}")
print(f"FPS={scene.render.fps}/{scene.render.fps_base}")
print("MARKERS=" + ",".join(f"{m.name}:{m.frame}" for m in scene.timeline_markers))

bones = ["Hips", "Spine", "Head", "LeftUpLeg", "RightUpLeg"]
for frame in (1, 12, 31, 49):
    scene.frame_set(frame)
    values = []
    for name in bones:
        pb = arm.pose.bones.get(name)
        if pb is None:
            continue
        values.append(
            f"{name}=({pb.rotation_euler.x:.3f},{pb.rotation_euler.y:.3f},{pb.rotation_euler.z:.3f})"
        )
    print(f"F{frame} " + " ".join(values))
