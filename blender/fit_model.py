# Starfall Vanguard: fit a generated one-piece character model (for example from TRELLIS.2 or Hunyuan3D, made from a
# concept image in a neutral A-pose) onto the game's trooper rig.
#   1. Import the GLB, turn it to face +z in game coordinates, scale it to trooper height, feet on the floor.
#   2. Cut it at the joints: every face goes to the nearest bone of the rig (pelvis, torso, head, right thigh, shin,
#      boot, upper arm, forearm, hand). Arms modelled in an A-pose are swung down to the rig's rest pose first.
#   3. Keep the right-hand limbs (the game mirrors them for the left) and export each piece as a kit group named
#      "<joint>__hd", textures included, so trooper.gd can load it like any other kit part.
# Run: python3 fit_model.py -- in.glb out.glb [--yaw DEG] [--arm DEG] [--height M]
#   --yaw DEG  turns the model about the up axis, counter-clockwise seen from above, before fitting; a model that
#              faces +x (turned +90 from the game's forward) needs --yaw -90. Check the facing in a test render.
#   --arm DEG  how far the model's arms hang out from straight down (its A-pose), measured at the shoulder.
#   --height M the model's full height, horns and crests included. The default is the Drakeguard kit's own full
#              height, so a model drawn to the same proportions lands on the rig's joints.
#   Depth and side are centred on the shins, so a backpack, cape or horns cannot push the body off the rig.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index('--') + 1:]
SRC, DST = argv[0], argv[1]
def opt(name, default):
    return float(argv[argv.index(name) + 1]) if name in argv else default
YAW, ARM, HEIGHT = opt('--yaw', 0.0), opt('--arm', 20.0), opt('--height', 2.0736)

def G(x, y, z): return Vector((x, -z, y))          # game (x right, y up, z forward) to Blender
def g(v): return Vector((v.x, v.z, -v.y))           # Blender to game

# the rig's joints in game coordinates (same as trooper2.py); limbs are the right-hand side
J = {'pelvis': (0, .98, 0), 'torso': (0, 1.05, 0), 'head': (0, 1.82, .02), 'thigh': (.13, .95, 0), 'shin': (.13, .51, 0),
     'boot': (.13, .09, 0), 'upperarm': (.31, 1.6, 0), 'forearm': (.31, 1.3, 0), 'hand': (.31, 1.03, 0)}
# bones as segments from joint to joint (rest pose: arms hang straight down); end points of the extremities are estimates
BONES = {'pelvis': ((0, .85, 0), (0, 1.08, 0)), 'torso': ((0, 1.08, 0), (0, 1.72, 0)), 'head': ((0, 1.74, 0), (0, 2.05, .02)),
         'thigh': ((.13, .95, 0), (.13, .51, 0)), 'shin': ((.13, .51, 0), (.13, .12, 0)), 'boot': ((.13, .12, 0), (.13, 0, .12)),
         'upperarm': ((.31, 1.6, 0), (.31, 1.3, 0)), 'forearm': ((.31, 1.3, 0), (.31, 1.04, 0)), 'hand': ((.31, 1.04, 0), (.31, .9, 0))}

LIMBS = ('thigh', 'shin', 'boot', 'upperarm', 'forearm', 'hand')

def seg_dist(p, a, b):
    a, b = Vector(a), Vector(b); ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    # bake every transform, including those of parent nodes, into the mesh itself, then drop the hierarchy
    bpy.context.view_layer.update()
    for o in meshes:
        if o.data.users > 1: o.data = o.data.copy()
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = Matrix.Identity(4); o.data.transform(mw)
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1: bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = body.data
    # face +z (game forward), feet on the floor, centred, at trooper height
    rot = Matrix.Rotation(math.radians(YAW), 4, 'Z'); me.transform(rot)
    lo = Vector((min(v.co.x for v in me.vertices), min(v.co.y for v in me.vertices), min(v.co.z for v in me.vertices)))
    hi = Vector((max(v.co.x for v in me.vertices), max(v.co.y for v in me.vertices), max(v.co.z for v in me.vertices)))
    s = HEIGHT / max(hi.z - lo.z, 1e-6)
    # centre on the shins (15 to 35 per cent of the height), where nothing but the legs can sit
    band = [v.co for v in me.vertices if lo.z + .15 * (hi.z - lo.z) <= v.co.z <= lo.z + .35 * (hi.z - lo.z)] or [v.co for v in me.vertices]
    centre = Vector(((min(c.x for c in band) + max(c.x for c in band)) / 2, (min(c.y for c in band) + max(c.y for c in band)) / 2, lo.z))
    me.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-centre))
    # cut by nearest bone, judged on the A-pose: arm bones are swung out by ARM degrees about the shoulder
    a = math.radians(ARM)
    def arm_pt(q, side):
        # point q on a straight-down arm, swung out by ARM about the shoulder (rotation about game z)
        sh = Vector((.31 * side, 1.6, 0)); d = Vector(q) - Vector((.31, 1.6, 0)); d.x *= side
        c, s_ = math.cos(a), math.sin(a)
        x, y = d.x * c - d.y * s_ * side, d.x * s_ * side + d.y * c
        return sh + Vector((x, y, d.z))
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    groups = {}
    for f in bm.faces:
        p = g(f.calc_center_median()); side = 1 if p.x >= 0 else -1
        best, bd = None, 1e9
        for name, (b0, b1) in BONES.items():
            if name in ('upperarm', 'forearm', 'hand'): b0, b1 = arm_pt(b0, side), arm_pt(b1, side)
            elif name in ('thigh', 'shin', 'boot'): b0 = Vector((b0[0] * side, b0[1], b0[2])); b1 = Vector((b1[0] * side, b1[1], b1[2]))
            d = seg_dist(p, b0, b1)
            if d < bd: bd, best = d, name
        # pieces on the midline stay whole; only limbs are split by side
        groups.setdefault((best, side if best in LIMBS else 0), []).append(f.index)
    # build one object per group; arm pieces are swung back down to the rest pose; only the right-hand limbs are kept
    out = []
    for (name, side), idx in groups.items():
        if name in LIMBS and side < 0: continue
        nb = bm.copy(); keep = set(idx)
        bmesh.ops.delete(nb, geom=[f for f in nb.faces if f.index not in keep], context='FACES')
        if name in ('upperarm', 'forearm', 'hand'):
            # swing back by -ARM in the game's x-y plane; a turn of x toward y in game space is a turn about Blender -y
            shoulder = G(.31, 1.6, 0); R = Matrix.Rotation(a, 3, 'Y')
            bmesh.ops.rotate(nb, verts=nb.verts, cent=shoulder, matrix=R)
        nm = bpy.data.meshes.new(name + '__hd'); nb.to_mesh(nm); nb.free()
        for m in me.materials: nm.materials.append(m)
        o = bpy.data.objects.new(name + '__hd_mesh', nm); bpy.context.scene.collection.objects.link(o); out.append((name, o))
    bm.free(); bpy.data.objects.remove(body)
    # parent each piece to a joint empty named like the kit groups, so the game finds "<joint>__hd"
    for name, o in out:
        e = bpy.data.objects.new(name + '__hd', None); e.location = G(*J[name]); bpy.context.scene.collection.objects.link(e)
        bpy.context.view_layer.update(); mw = o.matrix_world.copy(); o.parent = e; o.matrix_world = mw
    counts = {n: len(o.data.polygons) for n, o in out}
    assert len(counts) == len(out), 'two pieces share a joint name'
    print('FIT pieces', counts)
    bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_apply=True, export_materials='EXPORT',
        export_normals=True, export_texcoords=True)
    print('FIT exported', DST)

main()
