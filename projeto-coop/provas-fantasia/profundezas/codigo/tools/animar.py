# Poses e ações (chaves CONSTANT a 60 fps). O borrão (smear) e o teste de colisão da arma ficam no motor,
# porque a arma é uma malha à parte presa ao osso 'prop' (troca, arremesso e pegada sem clipe por arma).
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler, Quaternion
from bpy_extras.anim_utils import action_get_channelbag_for_slot
from malha import *

def pose_q(arm, bone, rx=0, ry=0, rz=0):
    b = arm.data.bones[bone]
    R = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_quaternion()
    Bq = b.matrix_local.to_quaternion()
    return Bq.inverted() @ R @ Bq

def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    for bn, v in pose.items():
        if bn not in arm.pose.bones:
            continue
        pb = arm.pose.bones[bn]
        if 'r' in v:
            pb.rotation_quaternion = pose_q(arm, bn, *v['r'])
        if 'l' in v:
            b = arm.data.bones[bn]
            pb.location = b.matrix_local.to_3x3().inverted() @ Vector(v['l'])
        if 'ly' in v:  # deslocamento ao longo do próprio osso (braço que estica no contato)
            pb.location = pb.location + Vector((0, v['ly'], 0))
        if 's' in v:
            pb.scale = v['s']

def P_(base, **over):
    d = {k: dict(v) if isinstance(v, dict) else v for k, v in base.items()}
    for k, v in over.items():
        k = k.replace('_L', '.L').replace('_R', '.R').replace('_F', '.F').replace('_B', '.B')
        d[k] = v
    return d

def key_action(arm, name, frames):
    act = bpy.data.actions.new(name)
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    for f, pose in frames:
        apply_pose(arm, pose)
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('scale', frame=f)
    for slot in act.slots:
        cb = action_get_channelbag_for_slot(act, slot)
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'CONSTANT'
    act.use_fake_user = True
    return act

def finish_actions(arm, acts):
    for act in acts:
        tr = arm.animation_data.nla_tracks.new(); tr.name = act.name
        tr.strips.new(act.name, 1, act)
    arm.animation_data.action = None

def bone_mat(arm, bname, frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    return arm.pose.bones[bname].matrix.copy()

