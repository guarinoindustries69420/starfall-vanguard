# Starfall Vanguard enemy models, built in Blender (bpy) and exported as GLB.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G³), a department of Guarino Industries LLC. Blender coords: X right, -Y forward (exports to glTF +Z), Z up.
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix
OUT=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else '/tmp/out'
os.makedirs(OUT,exist_ok=True)
COL={'base':(0.55,0.6,0.3,1),'trim':(0.25,0.3,0.15,1),'acc':(0.7,0.85,0.4,1),'glow':(0.8,1,0.5,1),'dark':(0.12,0.13,0.15,1)}
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for k,c in COL.items():
        m=bpy.data.materials.new(k);m.diffuse_color=c
def empty(name,loc=(0,0,0),parent=None):
    e=bpy.data.objects.new(name,None);e.location=loc;bpy.context.scene.collection.objects.link(e)
    if parent:e.parent=parent
    return e
def finish(o,mat,parent,smooth=True,bevel=0,subd=0):
    o.data.materials.append(bpy.data.materials[mat])
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    if bevel:
        md=o.modifiers.new('b','BEVEL');md.width=bevel;md.segments=2;md.limit_method='ANGLE'
    if subd:
        md=o.modifiers.new('s','SUBSURF');md.levels=subd;md.render_levels=subd
    for md in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=md.name)
    if smooth:bpy.ops.object.shade_smooth()
    else:bpy.ops.object.shade_flat()
    o.select_set(False)
    if parent:
        mw=o.matrix_world.copy();o.parent=parent;o.matrix_world=mw
    return o
def ell(name,loc,scale,mat,parent,seg=18,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=loc)
    o=bpy.context.active_object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(scale=True)
    return finish(o,mat,parent)
def box(name,loc,size,mat,parent,rot=(0,0,0),bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot)
    o=bpy.context.active_object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(scale=True)
    return finish(o,mat,parent,smooth=False,bevel=bevel)
def cyl(name,loc,r1,r2,h,mat,parent,rot=(0,0,0),verts=12,smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r1,radius2=r2,depth=h,location=loc,rotation=rot)
    o=bpy.context.active_object;o.name=name;return finish(o,mat,parent,smooth=smooth)
def seg(name,a,b,r1,r2,mat,parent,verts=8):
    a=Vector(a);b=Vector(b);d=b-a;mid=(a+b)/2
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r1,radius2=r2,depth=d.length,location=mid)
    o=bpy.context.active_object;o.name=name
    o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized())
    finish(o,mat,parent);ell(name+'_j',a,(r1*1.15,r1*1.15,r1*1.15),mat,parent,seg=10,rings=6);return o
def torus(name,loc,R,r,mat,parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=R,minor_radius=r,major_segments=32,minor_segments=8,location=loc)
    o=bpy.context.active_object;o.name=name;return finish(o,mat,parent)
def rig():
    root=empty('root');body=empty('body',parent=root);L=empty('legL',parent=root);R=empty('legR',parent=root);return root,body,L,R
def export(fn):
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,fn),export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT',export_normals=True,export_texcoords=False,export_draco_mesh_compression_enable=False)
    print('exported',fn,os.path.getsize(os.path.join(OUT,fn)))

def bug(kind):
    reset();root,body,L,R=rig()
    s={'grunt':1.0,'heavy':1.45,'rusher':.72}[kind]
    # thorax: three overlapping plates with a ridge
    ell('thorax',(0,0,.42),(.3,.36,.2),'base',body)
    for i,y in enumerate((-.18,0,.18)):
        box(f'plate{i}',(0,y,.6),(.42-.06*abs(i-1),.14,.05),'trim',body,rot=(0,0,0),bevel=.025)
    ell('head',(0,-.44,.45),(.19,.16,.14),'trim',body)
    ell('eyeL',(-.08,-.56,.5),(.04,.04,.04),'glow',body,seg=10,rings=6)
    ell('eyeR',(.08,-.56,.5),(.04,.04,.04),'glow',body,seg=10,rings=6)
    for sx in (-1,1):
        seg(f'mand{sx}',(sx*.08,-.52,.38),(sx*.16,-.72,.34),.035,.012,'acc',body)
        seg(f'mand{sx}b',(sx*.16,-.72,.34),(sx*.06,-.82,.33),.014,.006,'acc',body)
    if kind=='grunt':
        ell('sac',(0,.5,.56),(.3,.38,.26),'acc',body)
        for i in range(3):box(f'rib{i}',(0,.38+i*.14,.8-.03*i),(.34-.04*i,.04,.05),'trim',body,bevel=.015)
        cyl('vent',(0,.66,.8),.09,.05,.12,'dark',body,rot=(-.6,0,0))
        ell('ventglow',(0,.7,.86),(.06,.06,.03),'glow',body,seg=10,rings=6)
    elif kind=='heavy':
        ell('shell',(0,.05,.58),(.44,.6,.26),'base',body)
        for i in range(5):
            y=-.36+i*.18;box(f'ridge{i}',(0,y,.82-.01*abs(i-2)**2),(.66-.05*abs(i-2),.07,.07),'trim',body,bevel=.02)
        seg('horn',(0,-.55,.55),(0,-.82,.72),.07,.015,'acc',body)
        ell('tail',(0,.62,.45),(.2,.24,.16),'trim',body)
    else:
        ell('abd',(0,.36,.44),(.18,.28,.13),'base',body)
        seg('spine',(0,.1,.6),(0,.62,.66),.03,.01,'acc',body)
    # six legs, two segments each, grouped per leg so the game can run a tripod gait
    for side,grp in ((-1,L),(1,R)):
        for i,y in enumerate((-.24,0,.24)):
            leg=empty(f'leg_{"L" if side<0 else "R"}{i}',(side*.22,y,.42),grp)
            hip=Vector((side*.22,y,.42));knee=hip+Vector((side*.3,(y)*.5,.2));foot=hip+Vector((side*.58,y*.9,-.42))
            seg(f'thigh{side}{i}',hip,knee,.045,.035,'trim',leg)
            seg(f'shin{side}{i}',knee,foot,.035,.012,'dark',leg)
            ell(f'kneecap{side}{i}',knee+Vector((0,0,.02)),(.05,.05,.04),'acc',leg,seg=10,rings=6)
    root.scale=(s,s,s)
    export(f'swarm_{kind}.glb')

def drone():
    reset();root,body,L,R=rig()
    cyl('hull',(0,0,1.15),.34,.24,.16,'base',body,verts=24)
    cyl('dome',(0,0,1.27),.2,.12,.1,'trim',body,verts=20)
    ell('domecap',(0,0,1.32),(.12,.12,.05),'trim',body)
    torus('ring',(0,0,1.15),.5,.035,'trim',body)
    for a in range(4):
        ang=a*math.pi/2;x=math.cos(ang)*.5;y=math.sin(ang)*.5
        seg(f'strut{a}',(math.cos(ang)*.3,math.sin(ang)*.3,1.15),(x,y,1.15),.025,.02,'dark',body)
        cyl(f'rotor{a}',(x,y,1.22),.15,.15,.015,'acc',body,verts=16)
        cyl(f'hub{a}',(x,y,1.18),.035,.035,.07,'dark',body,verts=8)
    ell('eye',(0,-.3,1.1),(.09,.07,.07),'glow',body,seg=12,rings=8)
    cyl('gun',(0,-.38,1.0),.03,.03,.34,'dark',body,rot=(math.pi/2,0,0),verts=8)
    cyl('gunpod',(0,-.2,1.0),.07,.06,.14,'trim',body,rot=(math.pi/2,0,0),verts=10)
    seg('ant1',(.1,.15,1.32),(.16,.3,1.55),.012,.005,'dark',body)
    export('compact_rusher.glb')

def walker():
    reset();root,body,L,R=rig()
    box('torso',(0,0,1.28),(.72,.6,.42),'base',body,bevel=.05)
    box('belly',(0,0,1.03),(.66,.52,.1),'trim',body,bevel=.03)
    box('visor',(0,-.31,1.34),(.42,.04,.1),'glow',body,bevel=.01)
    box('brow',(0,-.32,1.42),(.5,.06,.05),'trim',body,bevel=.015)
    box('pack',(-.22,.36,1.34),(.28,.24,.3),'trim',body,bevel=.03)
    cyl('tube',(.1,.08,1.68),.12,.13,.78,'dark',body,rot=(-.75,0,0),verts=14)
    cyl('tubemouth',(.1,-.2,1.95),.15,.15,.08,'acc',body,rot=(-.75,0,0),verts=14)
    for sx in (-1,1):
        box(f'hip{sx}',(sx*.3,0,.98),(.16,.24,.16),'dark',body,bevel=.02)
    for side,grp in ((-1,L),(1,R)):
        leg=empty(f'leg_{"L" if side<0 else "R"}0',(side*.27,0,.95),grp)
        hip=Vector((side*.27,0,.95));knee=Vector((side*.29,-.12,.5));ank=Vector((side*.29,.04,.1))
        box(f'thigh{side}',(hip+knee)/2,(.17,.2,.5),'trim',leg,rot=(.25,0,0),bevel=.03)
        box(f'shin{side}',(knee+ank)/2,(.14,.17,.45),'dark',leg,rot=(-.35,0,0),bevel=.03)
        cyl(f'knee{side}',knee,.1,.1,.2,'acc',leg,rot=(0,math.pi/2,0),verts=12)
        box(f'foot{side}',(side*.29,-.08,.04),(.26,.42,.08),'trim',leg,bevel=.03)
        box(f'armor{side}',(side*.29,-.13,.72),(.19,.05,.24),'base',leg,bevel=.015)
    export('compact_heavy.glb')

for k in ('grunt','heavy','rusher'):bug(k)
drone();walker()
