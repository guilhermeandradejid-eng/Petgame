"""Pose review sheet: a few frames of every clip, side by side, rendered in Cycles."""
import os
import tempfile

import bpy
from PIL import Image

import preview


def render(rig, clips, out_path, per_clip=6, size=240, yaw=-35, dist=5.2, target_z=1.0, height=1.6):
    preview.studio(cam_yaw=yaw, dist=dist, height=height, target_z=target_z, size=(size, size), samples=10)
    tmp = tempfile.mkdtemp()
    rows = []
    for c in clips:
        frames = [round(i * c.length / (per_clip - 1)) for i in range(per_clip)]
        row = []
        for f in frames:
            rig.set_pose(c.pose_at(f))
            p = os.path.join(tmp, "%s_%d.png" % (c.name, f))
            preview.shot(p)
            row.append(p)
        rows.append((c.name, row))
    W = per_clip * size
    sheet = Image.new("RGB", (W + 120, len(rows) * size), (240, 244, 248))
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    for r, (name, row) in enumerate(rows):
        d.text((8, r * size + size // 2), name, fill=(40, 30, 60))
        for i, p in enumerate(row):
            sheet.paste(Image.open(p).convert("RGB"), (120 + i * size, r * size))
    sheet.save(out_path)
    print("sheet", out_path)
