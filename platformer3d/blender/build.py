"""Build Bolo (and Pip): model, rig, animations, glTF export.

    /opt/bpyenv/bin/python build.py [--sheet]
Writes ../godot/assets/bolo.glb (and pip.glb). --sheet also renders a pose review sheet.
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from vinyl import reset  # noqa: E402
import anim  # noqa: E402

ASSETS = os.path.normpath(os.path.join(HERE, "..", "godot", "assets"))


def export(path, arm):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for ch in arm.children:
        ch.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_frame_step=1, export_skins=True, export_def_bones=False, export_yup=True,
        export_apply=False, export_materials="EXPORT", export_anim_single_armature=True,
    )


def build_character(module, anims_module, name):
    reset()
    arm = module.build()
    rig = anim.Rig(arm)
    clips = [fn() for fn in anims_module.ALL]
    for c in clips:
        rig.bake(c)
    arm.animation_data.action = None
    rig.set_pose({})
    export(os.path.join(ASSETS, name + ".glb"), arm)
    return arm, rig, clips


if __name__ == "__main__":
    import bolo
    import bolo_anims
    arm, rig, clips = build_character(bolo, bolo_anims, "bolo")
    print("exported bolo with", [c.name for c in clips])
    if "--sheet" in sys.argv:
        import sheet
        sheet.render(rig, clips, os.path.join(HERE, "..", "docs", "bolo_poses.png"))
    import pip
    import pip_anims
    parm, prig, pclips = build_character(pip, pip_anims, "pip")
    print("exported pip with", [c.name for c in pclips])
    if "--sheet" in sys.argv:
        import sheet
        sheet.render(prig, pclips, os.path.join(HERE, "..", "docs", "pip_poses.png"), dist=2.2, target_z=0.0, height=0.5)
