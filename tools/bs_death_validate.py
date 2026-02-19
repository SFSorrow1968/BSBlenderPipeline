import argparse
import sys
from typing import List, Optional, Tuple

import bpy


def log(message: str) -> None:
    print(f"[bs_death_validate] {message}")


def parse_args() -> argparse.Namespace:
    argv = []
    if "--" in sys.argv:
        argv = sys.argv[sys.argv.index("--") + 1 :]

    parser = argparse.ArgumentParser(description="Validate current death clip in opened blend file.")
    parser.add_argument("--action", default="", help="Action name to validate. Defaults to active action.")
    parser.add_argument("--fps", type=int, default=60)
    parser.add_argument("--start-frame", type=int, default=1)
    parser.add_argument("--end-frame", type=int, default=49)
    parser.add_argument("--min-duration-sec", type=float, default=0.5)
    parser.add_argument("--max-duration-sec", type=float, default=1.0)
    parser.add_argument("--drift-threshold", type=float, default=0.03)
    parser.add_argument("--root-bone", default="", help="Root/pelvis bone.")
    return parser.parse_args(argv)


def find_armature() -> bpy.types.Object:
    arms = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not arms:
        raise RuntimeError("No armature found in scene.")
    arms.sort(key=lambda a: len(a.data.bones) if a.data else 0, reverse=True)
    return arms[0]


def find_root_bone(armature: bpy.types.Object, explicit_name: str) -> Optional[bpy.types.PoseBone]:
    pbs = armature.pose.bones
    if explicit_name:
        return pbs.get(explicit_name)
    for token in ("root", "hips", "pelvis", "mixamorig:hips"):
        for pb in pbs:
            if token in pb.name.lower():
                return pb
    return None


def sample_root_xy_drift(root_bone: bpy.types.PoseBone, frame_start: int, frame_end: int) -> float:
    scene = bpy.context.scene
    scene.frame_set(frame_start)
    x0 = root_bone.location.x
    y0 = root_bone.location.y
    max_dist = 0.0
    for frame in range(frame_start + 1, frame_end + 1):
        scene.frame_set(frame)
        dx = root_bone.location.x - x0
        dy = root_bone.location.y - y0
        dist = (dx * dx + dy * dy) ** 0.5
        max_dist = max(max_dist, dist)
    return max_dist


def validate_markers(expected: Tuple[str, ...]) -> List[str]:
    issues: List[str] = []
    markers = bpy.context.scene.timeline_markers
    for name in expected:
        if markers.get(name) is None:
            issues.append(f"Missing marker '{name}'")
    return issues


def iter_action_fcurves(action: bpy.types.Action):
    if hasattr(action, "fcurves"):
        for fcurve in action.fcurves:
            yield fcurve
        return
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for channel_bag in getattr(strip, "channelbags", []):
                for fcurve in getattr(channel_bag, "fcurves", []):
                    yield fcurve


def main() -> int:
    args = parse_args()
    scene = bpy.context.scene
    arm = find_armature()
    action = None
    if args.action:
        action = bpy.data.actions.get(args.action)
        if action is None:
            raise RuntimeError(f"Action '{args.action}' not found.")
    elif arm.animation_data:
        action = arm.animation_data.action

    issues: List[str] = []
    duration = (args.end_frame - args.start_frame) / float(args.fps)
    if duration < args.min_duration_sec or duration > args.max_duration_sec:
        issues.append(
            f"Duration {duration:.3f}s outside recommended "
            f"[{args.min_duration_sec:.3f}, {args.max_duration_sec:.3f}]."
        )

    if action is None:
        issues.append("No active action found.")
    elif sum(1 for _ in iter_action_fcurves(action)) == 0:
        issues.append("Action has no fcurves.")

    issues.extend(validate_markers(("impact", "collapse", "limp")))

    root = find_root_bone(arm, args.root_bone)
    if root is None:
        issues.append("No root bone for drift check.")
    else:
        drift = sample_root_xy_drift(root, args.start_frame, args.end_frame)
        log(f"Root XY drift: {drift:.5f}")
        if drift > args.drift_threshold:
            issues.append(
                f"Root XY drift {drift:.5f} exceeds threshold {args.drift_threshold:.5f}."
            )

    scene.frame_set(args.start_frame)
    if issues:
        for issue in issues:
            log(f"ISSUE: {issue}")
        return 2

    log("Validation passed.")
    return 0


if __name__ == "__main__":
    try:
        code = main()
    except Exception as exc:  # pylint: disable=broad-except
        log(f"ERROR: {exc}")
        code = 1
    sys.exit(code)
