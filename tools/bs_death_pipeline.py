import argparse
import math
import os
import sys
from typing import Dict, Iterable, List, Optional, Tuple

import bpy
from mathutils import Euler


def log(message: str) -> None:
    print(f"[bs_death_pipeline] {message}")


def parse_args() -> argparse.Namespace:
    argv = []
    if "--" in sys.argv:
        argv = sys.argv[sys.argv.index("--") + 1 :]

    parser = argparse.ArgumentParser(
        description="Import a B&S humanoid rig, author/validate death clip, export FBX for Unity Humanoid."
    )
    parser.add_argument("--input-fbx", default="", help="Input humanoid FBX file path.")
    parser.add_argument("--output-fbx", required=True, help="Output FBX animation path.")
    parser.add_argument(
        "--output-blend",
        default="",
        help="Optional .blend path to save the authored scene for manual polish.",
    )
    parser.add_argument("--clip-name", default="Death_Generic_A", help="Action/clip name.")
    parser.add_argument("--armature-name", default="", help="Optional armature object name.")
    parser.add_argument("--fps", type=int, default=60, help="Scene FPS.")
    parser.add_argument(
        "--duration-sec",
        type=float,
        default=0.8,
        help="Clip duration in seconds (recommended 0.5-1.0).",
    )
    parser.add_argument(
        "--min-duration-sec",
        type=float,
        default=0.5,
        help="Minimum recommended duration in seconds used by validation.",
    )
    parser.add_argument(
        "--max-duration-sec",
        type=float,
        default=1.0,
        help="Maximum recommended duration in seconds used by validation.",
    )
    parser.add_argument("--start-frame", type=int, default=1, help="Clip start frame.")
    parser.add_argument(
        "--root-bone",
        default="",
        help="Optional root/pelvis bone name used for drift locking and validation.",
    )
    parser.add_argument(
        "--drift-threshold",
        type=float,
        default=0.03,
        help="Maximum allowed root XY drift in Blender units.",
    )
    parser.add_argument(
        "--auto-block",
        action="store_true",
        help="Generate a fast baseline 3-pose death block (impact/collapse/limp).",
    )
    parser.add_argument(
        "--force-export",
        action="store_true",
        help="Export even if validations fail.",
    )
    parser.add_argument(
        "--keep-scene",
        action="store_true",
        help="Do not clear existing scene objects before importing FBX.",
    )
    parser.add_argument(
        "--use-current-scene",
        action="store_true",
        help="Use currently opened blend scene instead of importing an FBX.",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablock_collection in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.textures,
        bpy.data.images,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.armatures,
        bpy.data.actions,
    ):
        for datablock in list(datablock_collection):
            if datablock.users == 0:
                datablock_collection.remove(datablock)


def import_fbx(input_fbx: str) -> None:
    if not os.path.isfile(input_fbx):
        raise FileNotFoundError(f"Input FBX not found: {input_fbx}")
    bpy.ops.import_scene.fbx(filepath=input_fbx)
    log(f"Imported FBX: {input_fbx}")


def armature_score(obj: bpy.types.Object) -> int:
    if obj.type != "ARMATURE" or obj.data is None:
        return -1
    return len(obj.data.bones)


def find_armature(preferred_name: str = "") -> bpy.types.Object:
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError("No armature found after import.")

    if preferred_name:
        for arm in armatures:
            if arm.name == preferred_name:
                return arm
        raise RuntimeError(f"Armature '{preferred_name}' not found. Available: {[a.name for a in armatures]}")

    armatures.sort(key=armature_score, reverse=True)
    return armatures[0]


def set_active_object(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def ensure_action(armature_obj: bpy.types.Object, clip_name: str, reset_existing: bool = True) -> bpy.types.Action:
    if armature_obj.animation_data is None:
        armature_obj.animation_data_create()

    action = bpy.data.actions.get(clip_name)
    if action is not None and reset_existing:
        bpy.data.actions.remove(action)
        action = None

    if action is None:
        action = bpy.data.actions.new(name=clip_name)

    armature_obj.animation_data.action = action
    return action


def set_scene_timing(scene: bpy.types.Scene, start_frame: int, end_frame: int, fps: int) -> None:
    scene.frame_start = start_frame
    scene.frame_end = end_frame
    scene.render.fps = fps
    scene.render.fps_base = 1.0
    scene.frame_set(start_frame)


def add_timeline_marker(scene: bpy.types.Scene, name: str, frame: int) -> None:
    marker = scene.timeline_markers.get(name)
    if marker:
        marker.frame = frame
        return
    scene.timeline_markers.new(name=name, frame=frame)


def find_pose_bone(pose_bones: Iterable[bpy.types.PoseBone], names: Iterable[str]) -> Optional[bpy.types.PoseBone]:
    wanted = [n.lower() for n in names]
    indexed = {pb.name.lower(): pb for pb in pose_bones}
    for token in wanted:
        if token in indexed:
            return indexed[token]
    for pb in pose_bones:
        pb_name = pb.name.lower()
        if any(token in pb_name for token in wanted):
            return pb
    return None


def find_limb_bones(
    pose_bones: Iterable[bpy.types.PoseBone], side_tokens: Iterable[str], base_tokens: Iterable[str]
) -> List[bpy.types.PoseBone]:
    matches: List[bpy.types.PoseBone] = []
    side_tokens_l = [s.lower() for s in side_tokens]
    base_tokens_l = [b.lower() for b in base_tokens]
    for pb in pose_bones:
        name = pb.name.lower()
        if any(b in name for b in base_tokens_l) and any(s in name for s in side_tokens_l):
            matches.append(pb)
    return matches


def add_rot_quat(pose_bone: bpy.types.PoseBone, rot_xyz_rad: Tuple[float, float, float]) -> None:
    pose_bone.rotation_mode = "QUATERNION"
    delta = Euler(rot_xyz_rad, "XYZ").to_quaternion()
    pose_bone.rotation_quaternion = (pose_bone.rotation_quaternion @ delta).normalized()


def key_pose(
    armature_obj: bpy.types.Object,
    frame: int,
    root_bone: Optional[bpy.types.PoseBone],
    lock_root_location: bool = True,
) -> None:
    for pb in armature_obj.pose.bones:
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        pb.keyframe_insert(data_path="scale", frame=frame)

    if root_bone and lock_root_location:
        root_bone.keyframe_insert(data_path="location", frame=frame)


def set_root_location_constant(root_bone: bpy.types.PoseBone, frame_values: Dict[int, Tuple[float, float, float]]) -> None:
    for frame, value in frame_values.items():
        bpy.context.scene.frame_set(frame)
        root_bone.location = value
        root_bone.keyframe_insert(data_path="location", frame=frame)


def apply_auto_block(armature_obj: bpy.types.Object, root_bone: Optional[bpy.types.PoseBone], f0: int, f1: int, f2: int, f3: int) -> None:
    pbs = armature_obj.pose.bones
    def pick(*names: str) -> Optional[bpy.types.PoseBone]:
        for n in names:
            pb = pbs.get(n)
            if pb is not None:
                return pb
        return None

    hips = root_bone or pick("Hips", "hips", "Pelvis", "pelvis")
    lower_back = pick("LowerBack", "Spine", "spine")
    spine = pick("Spine", "spine", "Spine1")
    chest = pick("Spine1", "Chest", "chest")
    neck = pick("Neck", "neck", "Neck1")
    head = pick("Head", "head")

    l_shoulder = pick("LeftShoulder", "Shoulder.L", "shoulder.L")
    r_shoulder = pick("RightShoulder", "Shoulder.R", "shoulder.R")
    l_arm = pick("LeftArm", "UpperArm.L", "upper_arm.L")
    r_arm = pick("RightArm", "UpperArm.R", "upper_arm.R")
    l_forearm = pick("LeftForeArm", "ForeArm.L", "forearm.L")
    r_forearm = pick("RightForeArm", "ForeArm.R", "forearm.R")
    l_thigh = pick("LeftUpLeg", "Thigh.L", "thigh.L")
    r_thigh = pick("RightUpLeg", "Thigh.R", "thigh.R")
    l_calf = pick("LeftLeg", "Shin.L", "shin.L")
    r_calf = pick("RightLeg", "Shin.R", "shin.R")
    l_foot = pick("LeftFoot", "Foot.L", "foot.L")
    r_foot = pick("RightFoot", "Foot.R", "foot.R")

    # Fallbacks for non-canonical rigs.
    if l_arm is None:
        candidates = find_limb_bones(pbs, ("l", ".l", "_l", "left"), ("upperarm", "arm"))
        l_arm = candidates[0] if candidates else None
    if r_arm is None:
        candidates = find_limb_bones(pbs, ("r", ".r", "_r", "right"), ("upperarm", "arm"))
        r_arm = candidates[0] if candidates else None
    if l_forearm is None:
        candidates = find_limb_bones(pbs, ("l", ".l", "_l", "left"), ("forearm", "lowerarm"))
        l_forearm = candidates[0] if candidates else None
    if r_forearm is None:
        candidates = find_limb_bones(pbs, ("r", ".r", "_r", "right"), ("forearm", "lowerarm"))
        r_forearm = candidates[0] if candidates else None
    if l_thigh is None:
        candidates = find_limb_bones(pbs, ("l", ".l", "_l", "left"), ("thigh", "upleg"))
        l_thigh = candidates[0] if candidates else None
    if r_thigh is None:
        candidates = find_limb_bones(pbs, ("r", ".r", "_r", "right"), ("thigh", "upleg"))
        r_thigh = candidates[0] if candidates else None
    if l_calf is None:
        candidates = find_limb_bones(pbs, ("l", ".l", "_l", "left"), ("calf", "shin", "lowerleg", "leg"))
        l_calf = candidates[0] if candidates else None
    if r_calf is None:
        candidates = find_limb_bones(pbs, ("r", ".r", "_r", "right"), ("calf", "shin", "lowerleg", "leg"))
        r_calf = candidates[0] if candidates else None

    base_pose = {}
    bpy.context.scene.frame_set(f0)
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        base_pose[pb.name] = (
            pb.rotation_quaternion.copy(),
            pb.location.copy(),
            pb.scale.copy(),
        )

    def reset_pose() -> None:
        for pb in pbs:
            q, loc, scale = base_pose[pb.name]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q.copy()
            pb.location = loc.copy()
            pb.scale = scale.copy()

    bpy.context.scene.frame_set(f0)
    reset_pose()
    key_pose(armature_obj, f0, hips, lock_root_location=True)

    # Impact: quick readable hit reaction.
    bpy.context.scene.frame_set(f1)
    reset_pose()
    if hips:
        add_rot_quat(hips, (math.radians(-14), math.radians(5), math.radians(0)))
    if lower_back:
        add_rot_quat(lower_back, (math.radians(-14), math.radians(0), math.radians(0)))
    if spine:
        add_rot_quat(spine, (math.radians(-16), math.radians(0), math.radians(0)))
    if chest:
        add_rot_quat(chest, (math.radians(-20), math.radians(4), math.radians(0)))
    if neck:
        add_rot_quat(neck, (math.radians(8), math.radians(0), math.radians(0)))
    if head:
        add_rot_quat(head, (math.radians(10), math.radians(0), math.radians(0)))
    for pb, rot in (
        (l_shoulder, (math.radians(-12), 0.0, math.radians(-8))),
        (r_shoulder, (math.radians(-12), 0.0, math.radians(8))),
        (l_arm, (math.radians(-18), 0.0, math.radians(-18))),
        (r_arm, (math.radians(-18), 0.0, math.radians(18))),
        (l_forearm, (math.radians(-28), 0.0, math.radians(-8))),
        (r_forearm, (math.radians(-28), 0.0, math.radians(8))),
        (l_thigh, (math.radians(8), 0.0, math.radians(0))),
        (r_thigh, (math.radians(8), 0.0, math.radians(0))),
        (l_calf, (math.radians(-12), 0.0, math.radians(0))),
        (r_calf, (math.radians(-12), 0.0, math.radians(0))),
    ):
        if pb:
            add_rot_quat(pb, rot)
    key_pose(armature_obj, f1, hips, lock_root_location=True)

    # Collapse: center of mass drops with knees folding.
    bpy.context.scene.frame_set(f2)
    reset_pose()
    if hips:
        add_rot_quat(hips, (math.radians(34), math.radians(0), math.radians(16)))
    if lower_back:
        add_rot_quat(lower_back, (math.radians(30), math.radians(0), math.radians(8)))
    if spine:
        add_rot_quat(spine, (math.radians(30), math.radians(0), math.radians(12)))
    if chest:
        add_rot_quat(chest, (math.radians(22), math.radians(0), math.radians(10)))
    if neck:
        add_rot_quat(neck, (math.radians(20), math.radians(0), math.radians(0)))
    if head:
        add_rot_quat(head, (math.radians(30), math.radians(0), math.radians(0)))
    for pb, rot in (
        (l_arm, (math.radians(8), 0.0, math.radians(-20))),
        (r_arm, (math.radians(6), 0.0, math.radians(20))),
        (l_forearm, (math.radians(-10), 0.0, math.radians(-6))),
        (r_forearm, (math.radians(-12), 0.0, math.radians(6))),
        (l_thigh, (math.radians(32), 0.0, math.radians(8))),
        (r_thigh, (math.radians(32), 0.0, math.radians(-8))),
        (l_calf, (math.radians(-54), 0.0, math.radians(0))),
        (r_calf, (math.radians(-54), 0.0, math.radians(0))),
        (l_foot, (math.radians(10), 0.0, math.radians(0))),
        (r_foot, (math.radians(10), 0.0, math.radians(0))),
    ):
        if pb:
            add_rot_quat(pb, rot)
    key_pose(armature_obj, f2, hips, lock_root_location=True)

    # Limp: asymmetrical low-energy terminal pose before ragdoll handoff.
    bpy.context.scene.frame_set(f3)
    reset_pose()
    if hips:
        add_rot_quat(hips, (math.radians(48), math.radians(0), math.radians(24)))
    if lower_back:
        add_rot_quat(lower_back, (math.radians(24), math.radians(0), math.radians(10)))
    if spine:
        add_rot_quat(spine, (math.radians(24), math.radians(0), math.radians(10)))
    if chest:
        add_rot_quat(chest, (math.radians(18), math.radians(0), math.radians(8)))
    if neck:
        add_rot_quat(neck, (math.radians(8), math.radians(0), math.radians(-8)))
    if head:
        add_rot_quat(head, (math.radians(16), math.radians(0), math.radians(-12)))
    for pb, rot in (
        (l_shoulder, (math.radians(8), 0.0, math.radians(-10))),
        (r_shoulder, (math.radians(4), 0.0, math.radians(8))),
        (l_arm, (math.radians(24), 0.0, math.radians(-22))),
        (r_arm, (math.radians(16), 0.0, math.radians(20))),
        (l_forearm, (math.radians(-12), 0.0, math.radians(-10))),
        (r_forearm, (math.radians(-18), 0.0, math.radians(8))),
        (l_thigh, (math.radians(46), 0.0, math.radians(16))),
        (r_thigh, (math.radians(40), 0.0, math.radians(-10))),
        (l_calf, (math.radians(-70), 0.0, math.radians(0))),
        (r_calf, (math.radians(-62), 0.0, math.radians(0))),
        (l_foot, (math.radians(12), 0.0, math.radians(8))),
        (r_foot, (math.radians(8), 0.0, math.radians(-6))),
    ):
        if pb:
            add_rot_quat(pb, rot)

    if hips:
        # Small vertical drop sells weight without horizontal skating.
        hips.location.z -= 0.08
    key_pose(armature_obj, f3, hips, lock_root_location=True)

    if hips:
        # Freeze root translation to avoid forward skating before ragdoll handoff.
        bpy.context.scene.frame_set(f0)
        base_loc = tuple(hips.location)
        set_root_location_constant(hips, {f0: base_loc, f1: base_loc, f2: base_loc, f3: base_loc})

    log("Applied auto-block keys for impact/collapse/limp.")


def set_action_curve_defaults(action: bpy.types.Action) -> None:
    for fcurve in iter_action_fcurves(action):
        for key in fcurve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"


def iter_action_fcurves(action: bpy.types.Action):
    if hasattr(action, "fcurves"):
        for fcurve in action.fcurves:
            yield fcurve
        return

    # Blender 5 layered action API.
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for channel_bag in getattr(strip, "channelbags", []):
                for fcurve in getattr(channel_bag, "fcurves", []):
                    yield fcurve


def bone_root_candidates() -> Tuple[str, ...]:
    return (
        "root",
        "hips",
        "pelvis",
        "mixamorig:hips",
        "b_root",
        "b_hips",
    )


def resolve_root_bone(armature_obj: bpy.types.Object, explicit_name: str = "") -> Optional[bpy.types.PoseBone]:
    pbs = armature_obj.pose.bones
    if explicit_name:
        pb = pbs.get(explicit_name)
        if pb is None:
            raise RuntimeError(f"Root bone '{explicit_name}' not found.")
        return pb
    return find_pose_bone(pbs, bone_root_candidates())


def sample_root_xy_drift(root_bone: bpy.types.PoseBone, frame_start: int, frame_end: int) -> float:
    positions: List[Tuple[float, float]] = []
    scene = bpy.context.scene
    for frame in range(frame_start, frame_end + 1):
        scene.frame_set(frame)
        positions.append((root_bone.location.x, root_bone.location.y))
    x0, y0 = positions[0]
    max_dist = 0.0
    for x, y in positions[1:]:
        dx = x - x0
        dy = y - y0
        dist = math.sqrt(dx * dx + dy * dy)
        max_dist = max(max_dist, dist)
    return max_dist


def validate_clip(
    action: bpy.types.Action,
    root_bone: Optional[bpy.types.PoseBone],
    frame_start: int,
    frame_end: int,
    fps: int,
    drift_threshold: float,
    min_duration_sec: float,
    max_duration_sec: float,
) -> List[str]:
    issues: List[str] = []
    duration = (frame_end - frame_start) / float(fps)
    if duration < min_duration_sec or duration > max_duration_sec:
        issues.append(
            f"Duration {duration:.3f}s is outside recommended range "
            f"[{min_duration_sec:.3f}, {max_duration_sec:.3f}]."
        )

    curve_count = sum(1 for _ in iter_action_fcurves(action)) if action else 0
    if action is None or curve_count == 0:
        issues.append("Action has no fcurves; no animation data to export.")

    markers = bpy.context.scene.timeline_markers
    for marker_name in ("impact", "collapse", "limp"):
        if markers.get(marker_name) is None:
            issues.append(f"Missing timeline marker: {marker_name}")

    if root_bone is None:
        issues.append("No root/pelvis bone resolved; root drift check skipped.")
    else:
        drift = sample_root_xy_drift(root_bone, frame_start, frame_end)
        log(f"Root XY drift: {drift:.5f}")
        if drift > drift_threshold:
            issues.append(
                f"Root XY drift {drift:.5f} exceeds threshold {drift_threshold:.5f}."
            )

    return issues


def export_fbx(output_fbx: str, armature_obj: bpy.types.Object) -> None:
    output_dir = os.path.dirname(output_fbx)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    set_active_object(armature_obj)
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
        else:
            obj.select_set(False)

    bpy.ops.export_scene.fbx(
        filepath=output_fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
        bake_anim_step=1.0,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        axis_forward="-Z",
        axis_up="Y",
    )
    log(f"Exported FBX: {output_fbx}")


def save_blend(output_blend: str) -> None:
    output_dir = os.path.dirname(output_blend)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_blend)
    log(f"Saved blend: {output_blend}")


def main() -> int:
    args = parse_args()

    output_fbx = os.path.abspath(args.output_fbx)
    output_blend = os.path.abspath(args.output_blend) if args.output_blend else ""

    if args.use_current_scene:
        log("Using current scene from opened blend.")
    else:
        if not args.input_fbx:
            raise RuntimeError("--input-fbx is required unless --use-current-scene is set.")
        input_fbx = os.path.abspath(args.input_fbx)
        if not args.keep_scene:
            clear_scene()
        import_fbx(input_fbx)

    armature_obj = find_armature(args.armature_name)
    log(f"Using armature: {armature_obj.name}")

    set_active_object(armature_obj)
    existing_curve_count = 0
    if args.use_current_scene:
        existing_action = bpy.data.actions.get(args.clip_name)
        if existing_action is not None:
            existing_curve_count = sum(1 for _ in iter_action_fcurves(existing_action))

    action = ensure_action(armature_obj, args.clip_name, reset_existing=not args.use_current_scene)

    frame_start = args.start_frame
    frame_end = int(round(args.start_frame + args.duration_sec * args.fps))
    set_scene_timing(bpy.context.scene, frame_start, frame_end, args.fps)

    f_impact = frame_start + max(2, int(round((frame_end - frame_start) * 0.22)))
    f_collapse = frame_start + max(4, int(round((frame_end - frame_start) * 0.62)))
    f_limp = frame_end
    add_timeline_marker(bpy.context.scene, "impact", f_impact)
    add_timeline_marker(bpy.context.scene, "collapse", f_collapse)
    add_timeline_marker(bpy.context.scene, "limp", f_limp)
    log(f"Timeline markers: impact={f_impact}, collapse={f_collapse}, limp={f_limp}")

    root_bone = resolve_root_bone(armature_obj, args.root_bone)
    if root_bone:
        log(f"Using root bone: {root_bone.name}")

    if args.auto_block:
        apply_auto_block(armature_obj, root_bone, frame_start, f_impact, f_collapse, f_limp)
    else:
        if args.use_current_scene and existing_curve_count > 0:
            log("Keeping existing keyed action in current scene.")
        else:
            # Authoring baseline: provide guaranteed start/end keys without moving root translation.
            bpy.context.scene.frame_set(frame_start)
            key_pose(armature_obj, frame_start, root_bone, lock_root_location=True)
            bpy.context.scene.frame_set(frame_end)
            key_pose(armature_obj, frame_end, root_bone, lock_root_location=True)
            log("Inserted baseline start/end keys. Refine poses manually in Blender before final export.")

    set_action_curve_defaults(action)

    if output_blend:
        save_blend(output_blend)

    issues = validate_clip(
        action=action,
        root_bone=root_bone,
        frame_start=frame_start,
        frame_end=frame_end,
        fps=args.fps,
        drift_threshold=args.drift_threshold,
        min_duration_sec=args.min_duration_sec,
        max_duration_sec=args.max_duration_sec,
    )

    if issues:
        for issue in issues:
            log(f"VALIDATION: {issue}")
        if not args.force_export:
            log("Validation failed. Use --force-export to export anyway.")
            return 2
    else:
        log("Validation passed.")

    export_fbx(output_fbx, armature_obj)
    return 0


if __name__ == "__main__":
    try:
        exit_code = main()
    except Exception as exc:  # pylint: disable=broad-except
        log(f"ERROR: {exc}")
        exit_code = 1
    sys.exit(exit_code)
