import bpy

armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
if not armatures:
    print("NO_ARMATURE")
    raise SystemExit(1)

armatures.sort(key=lambda obj: len(obj.data.bones) if obj.data else 0, reverse=True)
arm = armatures[0]
names = [b.name for b in arm.data.bones]

print(f"ARMATURE={arm.name}")
print(f"BONE_COUNT={len(names)}")
print("FIRST_BONES=" + ",".join(names[:120]))

tokens = ("root", "hips", "pelvis", "mixamorig")
candidates = [n for n in names if any(t in n.lower() for t in tokens)]
print("ROOT_CANDIDATES=" + ",".join(candidates[:30]))
