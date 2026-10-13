"""Build the game assets for Bolo B and the owl: meshes, rigs, animations, glTF, eye texture.

    /opt/bpyenv/bin/python build_b.py [--sheet]
Writes ../../godot/assets/bolo_b.glb, owl.glb, eye_bolo.png, eye_owl.png and hang measurements
(godot/assets/bolo_b.json) used by the controller.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
SHEET = "--sheet" in sys.argv
sys.argv = [sys.argv[0], "--", "/tmp"]  # hero.py reads its own arguments after "--"

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import game_b  # noqa: E402
import anims_b  # noqa: E402
import owl_game  # noqa: E402
import anim  # noqa: E402
from vinyl import reset  # noqa: E402

ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "assets"))
DOCS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "v2"))


def eye_texture(path, iris, ring, pupil=0.3, iris_r=0.62, size=256):
    """Radial iris texture: pupil, iris with fibres and a lighter inner ring, dark limbal ring, sclera."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    sclera = np.array([244, 239, 230], float)
    img = np.ones((size, size, 3)) * sclera
    iris = np.array(iris, float)
    ring = np.array(ring, float)
    fib = 0.85 + 0.15 * np.sin(ang * 38) * np.sin(ang * 11 + r * 9)
    t = np.clip((r - pupil) / (iris_r - pupil), 0, 1)[..., None]
    light = np.array([235, 170, 90], float)
    irisc = (iris * (1 - t) * 0.7 + light * (1 - t) * 0.3 + iris * t) * fib[..., None]
    rim = np.clip((r - iris_r * 0.82) / (iris_r * 0.18), 0, 1)[..., None]
    irisc = irisc * (1 - rim) + ring * rim
    m_iris = r < iris_r
    img[m_iris] = irisc[m_iris]
    img[r < pupil] = (8, 5, 4)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(path)


def export(path, arm):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for ch in arm.children:
        ch.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_animations=True,
        export_animation_mode="ACTIONS", export_force_sampling=True, export_skins=True,
        export_def_bones=False, export_yup=True, export_apply=False, export_attributes=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=True, export_anim_single_armature=True,
    )


def world(arm, bone):
    pb = arm.pose.bones[bone]
    return arm.matrix_world @ ((pb.head + pb.tail) * 0.5)


def main():
    os.makedirs(ASSETS, exist_ok=True)
    eye_texture(os.path.join(ASSETS, "eye_bolo.png"), (122, 61, 18), (30, 13, 5))
    eye_texture(os.path.join(ASSETS, "eye_owl.png"), (242, 181, 28), (90, 58, 8), pupil=0.32, iris_r=0.74)

    reset()
    import hero  # material registry must be fresh after the reset
    hero.scene = bpy.context.scene
    game_b.M.clear()
    arm = game_b.build_game(None)
    rig = anim.Rig(arm)
    # measure the hanging grip on the actual rig
    rig.set_pose(anims_b.HANG)
    bpy.context.view_layer.update()
    hands = (world(arm, "hand.L") + world(arm, "hand.R")) * 0.5
    head = bpy.data.objects["Body"].evaluated_get(bpy.context.evaluated_depsgraph_get())
    front = min((head.matrix_world @ v.co).y for v in head.data.vertices if (head.matrix_world @ v.co).z > 0.7)
    meas = {"hang_hand_z": round(hands.z, 4), "hang_hand_y": round(hands.y, 4), "hang_front_y": round(front, 4),
            "height": 1.22, "climb_forward": 0.55}
    anims_b.HANG_HANDS = (0.0, hands.y, hands.z)
    clips = [fn() for fn in anims_b.ALL if fn is not anims_b.ledge_climb] + [anims_b.ledge_climb(hands.z)]
    for c in clips:
        rig.bake(c)
    arm.animation_data.action = None
    rig.set_pose({})
    export(os.path.join(ASSETS, "bolo_b.glb"), arm)
    with open(os.path.join(ASSETS, "bolo_b.json"), "w") as f:
        json.dump(meas, f, indent=1)
    print("bolo_b exported", meas)
    if SHEET:
        sheet(rig, clips, os.path.join(DOCS, "bolo_b_poses.png"), dist=3.2, target_z=0.6, height=1.1)

    reset()
    game_b.M.clear()
    oarm = owl_game.build(game_b.material)
    orig = anim.Rig(oarm)
    oclips = [fn() for fn in owl_game.ALL]
    for c in oclips:
        orig.bake(c)
    oarm.animation_data.action = None
    orig.set_pose({})
    export(os.path.join(ASSETS, "owl.glb"), oarm)
    print("owl exported")
    if SHEET:
        sheet(orig, oclips, os.path.join(DOCS, "owl_poses.png"), dist=1.0, target_z=0.05, height=0.25)


def sheet(rig, clips, path, dist, target_z, height):
    """Fast review: no fur, vertex colours shown directly."""
    for m in bpy.data.materials:
        if m.name == "fur":
            nt = m.node_tree
            b = nt.nodes["Principled BSDF"]
            a = nt.nodes.new("ShaderNodeVertexColor")
            a.layer_name = "Col"
            nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
            b.inputs["Roughness"].default_value = 0.8
    sys.path.insert(0, os.path.dirname(HERE))
    import sheet as S
    S.render(rig, clips, path, dist=dist, target_z=target_z, height=height)


if __name__ == "__main__":
    main()
