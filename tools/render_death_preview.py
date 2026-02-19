import argparse
import os
import sys
from math import tan
from mathutils import Vector

import bpy


def parse_args():
    argv = []
    if "--" in sys.argv:
        argv = sys.argv[sys.argv.index("--") + 1 :]

    parser = argparse.ArgumentParser(description="Render a framed MP4 preview for a death clip.")
    parser.add_argument(
        "--output-pattern",
        required=True,
        help="Output image pattern path, e.g. .\\renders\\tmp\\frame_####",
    )
    parser.add_argument("--start-frame", type=int, default=-1)
    parser.add_argument("--end-frame", type=int, default=-1)
    parser.add_argument("--fps", type=int, default=60)
    parser.add_argument("--resolution-x", type=int, default=1280)
    parser.add_argument("--resolution-y", type=int, default=720)
    return parser.parse_args(argv)


def find_targets(scene):
    meshes = [o for o in scene.objects if o.type == "MESH" and not o.hide_render]
    armatures = [o for o in scene.objects if o.type == "ARMATURE" and not o.hide_render]
    return meshes, armatures


def world_bounds(objects):
    points = []
    for obj in objects:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))

    if not points:
        return Vector((0.0, 0.0, 0.0)), Vector((1.0, 1.0, 2.0))

    min_v = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    max_v = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return min_v, max_v


def ensure_camera(scene):
    cam = scene.camera
    if cam and cam.type == "CAMERA":
        return cam

    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame_camera_to_bounds(cam, min_v, max_v):
    center = (min_v + max_v) * 0.5
    size = max_v - min_v
    radius = max(size.x, size.y, size.z) * 0.6
    radius = max(radius, 0.02)

    cam.data.type = "PERSP"
    cam.data.lens = 55.0
    cam.data.clip_start = 0.001
    cam.data.clip_end = 1000.0

    fov = cam.data.angle
    dist = (radius / tan(fov * 0.5)) * 2.3

    # Front-ish view with slight elevation.
    view_dir = Vector((0.0, -1.0, 0.35)).normalized()
    cam.location = center + (view_dir * dist)
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


def configure_preview_render(scene, output_pattern, fps, rx, ry, start_frame, end_frame):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = rx
    scene.render.resolution_y = ry
    scene.render.resolution_percentage = 100
    scene.render.fps = fps
    scene.render.fps_base = 1.0

    if start_frame >= 0:
        scene.frame_start = start_frame
    if end_frame >= 0:
        scene.frame_end = end_frame

    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = output_pattern


def main():
    args = parse_args()
    scene = bpy.context.scene

    output_pattern = os.path.abspath(args.output_pattern)
    os.makedirs(os.path.dirname(output_pattern), exist_ok=True)

    meshes, armatures = find_targets(scene)
    targets = meshes if meshes else armatures
    if not targets:
        raise RuntimeError("No mesh/armature objects found for preview framing.")

    min_v, max_v = world_bounds(targets)
    cam = ensure_camera(scene)
    frame_camera_to_bounds(cam, min_v, max_v)

    configure_preview_render(
        scene=scene,
        output_pattern=output_pattern,
        fps=args.fps,
        rx=args.resolution_x,
        ry=args.resolution_y,
        start_frame=args.start_frame,
        end_frame=args.end_frame,
    )

    print(
        f"PREVIEW frame_range={scene.frame_start}-{scene.frame_end} "
        f"camera={cam.name} cam_loc=({cam.location.x:.4f},{cam.location.y:.4f},{cam.location.z:.4f}) "
        f"output_pattern={output_pattern}"
    )
    bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    main()
