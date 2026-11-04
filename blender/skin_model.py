# Starfall Vanguard: put a generated one-piece character model (for example from TRELLIS.2, made from a concept image in
# a neutral A-pose) on a skeleton that matches the trooper rig, so the game can pose it without cutting it into pieces.
#   1. Import the GLB, bake every transform into the mesh, turn it to face +z in game coordinates, scale it to trooper
#      height with feet on the floor, and centre it on its shins.
#   2. Optionally thin it to about --faces N faces.
#   3. Weight every vertex to its nearest bones of the rig (both sides), blending over BLEND metres near each joint,
#      judged on the A-pose: arm bones are swung out by --arm degrees about the shoulder.
#   4. Straighten the arms to the rig's rest pose through those same weights, so the shoulders bend instead of tearing.
#   5. Export one skinned mesh on an armature whose bones sit on the rig's joints, named after them ("thigh_l", ...).
# trooper.gd then drives each bone from the matching joint node every frame.
# Run: python3 skin_model.py -- in.glb out.glb [--yaw DEG] [--arm DEG] [--height M] [--faces N]
#   --yaw DEG  turns the model about the up axis, counter-clockwise seen from above, before fitting; a model that
#              faces +x (turned +90 from the game's forward) needs --yaw -90. Check the facing in a test render.
#   --arm DEG  how far the model's arms hang out from straight down (its A-pose), measured at the shoulder.
#   --height M the model's full height, horns and crests included. The default is the Drakeguard kit's own full
#              height, so a model drawn to the same proportions lands on the rig's joints.
#   --faces N  thin the model to about N faces (collapse decimation) before skinning; 0 keeps every face.
#   Side and depth are set from the shins (15 to 35 per cent of the height), placed where the kit's own shins sit
#   (0.031 m forward of the rig's centre). Horns and a backpack do not move the body. A dense full-length cape or a
#   weapon held below the knee can still shift it, so check the result in a test render.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import bpy, sys, math
import numpy as np
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index('--') + 1:]
SRC, DST = argv[0], argv[1]
def opt(name, default):
    return float(argv[argv.index(name) + 1]) if name in argv else default
YAW, ARM, HEIGHT, FACES = opt('--yaw', 0.0), opt('--arm', 20.0), opt('--height', 2.0736), int(opt('--faces', 0))
BLEND = .05                        # metres over which a vertex near a joint shares its weight between two bones
SHIN_Z = .031                      # depth of the kit's shin band centre in game coordinates (measured, Drakeguard kit)

def G(x, y, z): return Vector((x, -z, y))          # game (x right, y up, z forward) to Blender
# right-hand joints in game coordinates (same as trooper.gd); the left side mirrors x
J = {'pelvis': (0, .98, 0), 'torso': (0, 1.05, 0), 'head': (0, 1.82, .02), 'thigh': (.13, .95, 0), 'shin': (.13, .51, 0),
     'boot': (.13, .09, 0), 'upperarm': (.31, 1.6, 0), 'forearm': (.31, 1.3, 0), 'hand': (.31, 1.03, 0)}
# bones as segments from joint to joint, rest pose (arms straight down); end points of the extremities are estimates
SEG = {'pelvis': ((0, .85, 0), (0, 1.08, 0)), 'torso': ((0, 1.08, 0), (0, 1.72, 0)), 'head': ((0, 1.74, 0), (0, 2.05, .02)),
       'thigh': ((.13, .95, 0), (.13, .51, 0)), 'shin': ((.13, .51, 0), (.13, .12, 0)), 'boot': ((.13, .12, 0), (.13, 0, .12)),
       'upperarm': ((.31, 1.6, 0), (.31, 1.3, 0)), 'forearm': ((.31, 1.3, 0), (.31, 1.04, 0)), 'hand': ((.31, 1.04, 0), (.31, .9, 0))}
PARENT = {'pelvis': None, 'torso': 'pelvis', 'head': 'torso', 'upperarm': 'torso', 'forearm': 'upperarm', 'hand': 'forearm',
          'thigh': 'pelvis', 'shin': 'thigh', 'boot': 'shin'}
LIMBS = ('thigh', 'shin', 'boot', 'upperarm', 'forearm', 'hand'); ARMS = ('upperarm', 'forearm', 'hand')

def bones():
    """every bone of both sides: name, joint name, side (1 right, -1 left, 0 midline)"""
    out = []
    for j in J:
        if j in LIMBS: out += [(j + '_r', j, 1), (j + '_l', j, -1)]
        else: out.append((j, j, 0))
    return out

def seg_dist(P, a, b):
    """distance from each point in P (n x 3, game coordinates) to the segment a-b"""
    a, b = np.asarray(a, float), np.asarray(b, float); ab = b - a
    t = np.clip((P - a) @ ab / max(ab @ ab, 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

def swing(q, side, ang):
    """point q (game) on a straight-down arm of this side, swung out by ang about that shoulder (about game z)"""
    sh = np.array((.31 * side, 1.6, 0.0)); d = np.asarray(q, float) - sh
    c, s = math.cos(ang), math.sin(ang)
    return sh + np.array((d[0] * c - d[1] * s * side, d[0] * s * side + d[1] * c, d[2]))

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.context.view_layer.update()
    for o in meshes:                        # bake every transform, including parent nodes, into the mesh
        if o.data.users > 1: o.data = o.data.copy()
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = Matrix.Identity(4); o.data.transform(mw)
        if mw.to_3x3().determinant() < 0: o.data.flip_normals()     # a mirroring transform turns the faces inside out
    for o in [o for o in bpy.context.scene.objects if o.type != 'MESH']: bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1: bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active; body.name = 'body'; me = body.data
    # face +z (game forward), feet on the floor, centred on the shins, at trooper height
    me.transform(Matrix.Rotation(math.radians(YAW), 4, 'Z'))
    co = np.array([v.co for v in me.vertices]); lo, hi = co.min(0), co.max(0)
    s = HEIGHT / max(hi[2] - lo[2], 1e-6)
    band = co[(co[:, 2] >= lo[2] + .15 * (hi[2] - lo[2])) & (co[:, 2] <= lo[2] + .35 * (hi[2] - lo[2]))]
    if len(band) == 0: band = co
    centre = Vector(((band[:, 0].min() + band[:, 0].max()) / 2, (band[:, 1].min() + band[:, 1].max()) / 2, lo[2]))
    me.transform(Matrix.Translation(G(0, 0, SHIN_Z)) @ Matrix.Scale(s, 4) @ Matrix.Translation(-centre))
    if FACES > 0 and len(me.polygons) > FACES:
        m = body.modifiers.new('thin', 'DECIMATE'); m.decimate_type = 'COLLAPSE'; m.ratio = FACES / len(me.polygons)
        m.use_collapse_triangulate = True; bpy.ops.object.modifier_apply(modifier=m.name)
    # weights, judged on the A-pose
    co = np.array([v.co for v in me.vertices]); P = np.stack([co[:, 0], co[:, 2], -co[:, 1]], 1)   # game coordinates
    side = np.where(P[:, 0] >= 0, 1, -1); a = math.radians(ARM)
    B = bones(); D = np.full((len(P), len(B)), np.inf)
    for k, (bn, j, sd) in enumerate(B):
        b0, b1 = SEG[j]
        if sd: b0 = (b0[0] * sd, b0[1], b0[2]); b1 = (b1[0] * sd, b1[1], b1[2])
        if j in ARMS: b0, b1 = swing(b0, sd, a), swing(b1, sd, a)
        d = seg_dist(P, b0, b1)
        if sd: d[side != sd] = np.inf       # a limb bone only takes vertices on its own side of the body
        D[:, k] = d
    W = np.clip(1.0 - (D - D.min(1, keepdims=True)) / BLEND, 0.0, 1.0)
    keep = np.argsort(-W, 1)[:, 4:]; np.put_along_axis(W, keep, 0.0, 1)   # at most four bones per vertex
    W /= W.sum(1, keepdims=True)
    # straighten the arms through the same weights (linear blend of each bone's swing back to the rest pose)
    R = np.zeros_like(P)
    for k, (bn, j, sd) in enumerate(B):
        w = W[:, k]
        if not w.any(): continue
        if j in ARMS:
            sh = np.array((.31 * sd, 1.6, 0.0)); c, s_ = math.cos(-a), math.sin(-a); d = P - sh
            q = sh + np.stack([d[:, 0] * c - d[:, 1] * s_ * sd, d[:, 0] * s_ * sd + d[:, 1] * c, d[:, 2]], 1)
        else: q = P
        R += w[:, None] * q
    me.vertices.foreach_set('co', np.stack([R[:, 0], -R[:, 2], R[:, 1]], 1).ravel())
    me.update()
    # armature on the rig's joints, rest pose
    arm = bpy.data.armatures.new('rig'); ao = bpy.data.objects.new('rig', arm); bpy.context.scene.collection.objects.link(ao)
    bpy.ops.object.select_all(action='DESELECT'); ao.select_set(True); bpy.context.view_layer.objects.active = ao
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for bn, j, sd in B:
        x, y, z = J[j]; e = arm.edit_bones.new(bn); e.head = G(x * (sd or 1), y, z); e.tail = e.head + Vector((0, 0, .08))
        eb[bn] = e
    for bn, j, sd in B:
        p = PARENT[j]
        if p: eb[bn].parent = eb[p + ('_r' if sd > 0 else '_l') if p in LIMBS else p]
    bpy.ops.object.mode_set(mode='OBJECT')
    for k, (bn, j, sd) in enumerate(B):
        vg = body.vertex_groups.new(name=bn); idx = np.nonzero(W[:, k])[0]
        for i in idx: vg.add([int(i)], float(W[i, k]), 'REPLACE')
    body.parent = ao; mod = body.modifiers.new('rig', 'ARMATURE'); mod.object = ao
    print('SKIN faces', len(me.polygons), 'verts', len(me.vertices), 'bones', len(B),
          'blended verts', int((np.count_nonzero(W, 1) > 1).sum()))
    bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_apply=False, export_skins=True,
        export_materials='EXPORT', export_normals=True, export_texcoords=True, export_animations=False)
    print('SKIN exported', DST)

main()
