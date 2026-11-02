# Starfall Vanguard player mechs and mech weapons, built in Blender. MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G³), a department of Guarino Industries LLC.
import bpy,math,sys,os,importlib.util
from mathutils import Vector
here=os.path.dirname(os.path.abspath(__file__))
spec=importlib.util.spec_from_file_location('E',os.path.join(here,'enemies_lib.py'));E=importlib.util.module_from_spec(spec);spec.loader.exec_module(E)
E.OUT=sys.argv[sys.argv.index('--')+1]
def legs(L,R,hipX,hipZ,kneeF,footZ,thick,digi=False):
    for side,grp in((-1,L),(1,R)):
        leg=E.empty(f'leg_{"L" if side<0 else "R"}0',(side*hipX,0,hipZ),grp)
        hip=Vector((side*hipX,0,hipZ));knee=Vector((side*hipX*1.05,(kneeF if digi else -kneeF),hipZ*.55));ank=Vector((side*hipX*1.05,(-kneeF*.5 if digi else .04),footZ+.14))
        E.seg(f'thigh{side}',hip,knee,thick*.62,thick*.5,'trim',leg,verts=8)
        E.seg(f'shin{side}',knee,ank,thick*.5,thick*.42,'dark',leg,verts=8)
        E.cyl(f'knee{side}',knee,thick*.6,thick*.6,thick*1.3,'acc',leg,rot=(0,math.pi/2,0),verts=12)
        E.ell(f'ankle{side}',ank,(thick*.45,thick*.45,thick*.45),'dark',leg,seg=10,rings=6)
        E.box(f'foot{side}',(ank.x,ank.y-.1,footZ+.05),(thick*1.7,thick*3.0,.1),'trim',leg,bevel=.03)
        E.box(f'hipplate{side}',(side*hipX*1.1,-.02,hipZ-.12),(thick*1.2,thick*1.5,.3),'base',leg,bevel=.03)
def jackal():
    E.reset();root,body,L,R=E.rig()
    E.box('pelvis',(0,0,1.25),(.5,.38,.22),'dark',body,bevel=.04)
    E.box('torso',(0,.02,1.55),(.62,.5,.4),'base',body,bevel=.07)
    E.ell('canopy',(0,-.24,1.62),(.2,.12,.12),'glow',body,seg=14,rings=8)
    E.box('spine',(0,.28,1.6),(.18,.12,.36),'trim',body,bevel=.02)
    E.seg('antenna',(.2,.25,1.75),(.26,.38,2.2),.015,.006,'dark',body,verts=6)
    for sx in(-1,1):E.box(f'shoulder{sx}',(sx*.4,0,1.62),(.18,.3,.22),'trim',body,bevel=.03)
    E.empty('armL',(-.52,-.05,1.55),body);E.empty('armR',(.52,-.05,1.55),body)
    legs(L,R,.2,1.2,.22,0,.13,digi=True)
    root.scale=(1,1,1);E.export('mech_jackal.glb')
def ironclad():
    E.reset();root,body,L,R=E.rig()
    E.box('pelvis',(0,0,1.25),(.66,.46,.26),'dark',body,bevel=.04)
    E.box('torso',(0,0,1.65),(.95,.72,.62),'base',body,bevel=.09)
    E.box('chest',(0,-.37,1.62),(.6,.06,.36),'trim',body,bevel=.02)
    E.box('visor',(0,-.41,1.78),(.42,.04,.08),'glow',body,bevel=.01)
    E.box('pack',(0,.45,1.72),(.6,.24,.5),'trim',body,bevel=.04)
    for sx in(-1,1):
        E.box(f'vent{sx}',(sx*.18,.6,1.86),(.12,.06,.16),'dark',body,bevel=.01)
        E.ell(f'shoulder{sx}',(sx*.55,0,1.82),(.22,.24,.18),'trim',body)
    E.empty('armL',(-.7,-.08,1.62),body);E.empty('armR',(.7,-.08,1.62),body)
    legs(L,R,.28,1.22,.18,0,.17)
    E.export('mech_ironclad.glb')
def colossus():
    E.reset();root,body,L,R=E.rig()
    E.box('pelvis',(0,0,1.32),(.9,.6,.32),'dark',body,bevel=.05)
    E.box('torso',(0,.05,1.82),(1.3,.95,.8),'base',body,bevel=.12)
    E.box('cockpit',(0,-.5,1.95),(.56,.16,.32),'trim',body,bevel=.04)
    E.box('slit',(0,-.59,2.0),(.42,.03,.07),'glow',body,bevel=.005)
    E.box('plating',(0,-.48,1.6),(1.05,.08,.3),'trim',body,bevel=.03)
    for sx in(-1,1):
        E.box(f'pauldron{sx}',(sx*.78,0,2.08),(.42,.62,.24),'trim',body,bevel=.06)
        E.cyl(f'stack{sx}',(sx*.35,.55,2.3),.08,.07,.5,'dark',body,verts=10)
    E.box('stripe',(0,.05,2.23),(1.0,.2,.05),'acc',body,bevel=.01)
    E.empty('armL',(-.92,-.1,1.78),body);E.empty('armR',(.92,-.1,1.78),body)
    legs(L,R,.38,1.3,.16,0,.24)
    E.export('mech_colossus.glb')
# weapons point along -Y (forward), origin at the mount
def w_autocannon():
    E.reset();root,body,L,R=E.rig()
    E.box('recv',(0,-.1,0),(.2,.42,.22),'trim',body,bevel=.03);E.cyl('barrel',(0,-.6,0),.06,.055,.7,'dark',body,rot=(math.pi/2,0,0),verts=12)
    E.cyl('brake',(0,-.96,0),.085,.085,.1,'acc',body,rot=(math.pi/2,0,0),verts=10);E.box('mag',(0,.0,-.18),(.14,.2,.18),'dark',body,bevel=.02)
    E.export('mw_autocannon.glb')
def w_minigun():
    E.reset();root,body,L,R=E.rig()
    E.cyl('motor',(0,-.05,0),.13,.13,.3,'trim',body,rot=(math.pi/2,0,0),verts=12)
    for a in range(6):ang=a*math.pi/3;E.cyl(f'b{a}',(math.cos(ang)*.06,-.5,math.sin(ang)*.06),.022,.022,.7,'dark',body,rot=(math.pi/2,0,0),verts=6)
    E.cyl('clamp',(0,-.7,0),.1,.1,.05,'acc',body,rot=(math.pi/2,0,0),verts=12);E.box('drum',(.17,.05,-.05),(.16,.26,.26),'base',body,bevel=.03)
    E.export('mw_minigun.glb')
def w_rockets():
    E.reset();root,body,L,R=E.rig()
    E.box('pod',(0,-.25,0),(.36,.6,.32),'base',body,bevel=.04)
    for i in range(3):
        for j in range(2):E.cyl(f't{i}{j}',(-.11+i*.11,-.56,-.07+j*.14),.045,.045,.04,'dark',body,rot=(math.pi/2,0,0),verts=8)
    E.box('band',(0,-.25,.17),(.37,.1,.03),'acc',body,bevel=.01)
    E.export('mw_rockets.glb')
def w_flamer():
    E.reset();root,body,L,R=E.rig()
    E.cyl('tank',(0,.0,.05),.11,.11,.4,'acc',body,verts=12)
    E.cyl('nozzle',(0,-.45,0),.05,.08,.55,'dark',body,rot=(math.pi/2,0,0),verts=10)
    E.ell('pilot',(0,-.74,0),(.04,.04,.04),'glow',body,seg=8,rings=6);E.box('guard',(0,-.2,-.08),(.18,.3,.08),'trim',body,bevel=.02)
    E.export('mw_flamer.glb')
def w_lance():
    E.reset();root,body,L,R=E.rig()
    E.box('housing',(0,-.2,0),(.18,.5,.18),'trim',body,bevel=.03)
    for a in range(3):ang=a*2*math.pi/3;E.box(f'rail{a}',(math.cos(ang)*.07,-.62,math.sin(ang)*.07),(.03,.5,.03),'base',body,rot=(0,ang,0),bevel=.008)
    E.ell('focus',(0,-.86,0),(.05,.05,.05),'glow',body,seg=10,rings=6);E.cyl('coil',(0,-.3,0),.11,.11,.12,'acc',body,rot=(math.pi/2,0,0),verts=12)
    E.export('mw_lance.glb')
jackal();ironclad();colossus();w_autocannon();w_minigun();w_rockets();w_flamer();w_lance()
