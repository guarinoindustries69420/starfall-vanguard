# Starfall Vanguard objective props, built in Blender. MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G³), a department of Guarino Industries LLC.
import bpy,math,sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import importlib.util
spec=importlib.util.spec_from_file_location('E',os.path.join(os.path.dirname(os.path.abspath(__file__)),'enemies_lib.py'));E=importlib.util.module_from_spec(spec);spec.loader.exec_module(E)
from mathutils import Vector
OUT=sys.argv[sys.argv.index('--')+1]
E.OUT=OUT
def relay():
    E.reset();root,body,L,R=E.rig()
    E.box('pad',(0,0,.06),(.9,.9,.12),'dark',body,bevel=.03)
    E.box('base',(0,0,.25),(.55,.55,.3),'base',body,bevel=.04)
    for sx in(-1,1):
        for sy in(-1,1):E.seg(f'leg{sx}{sy}',(sx*.24,sy*.24,.38),(sx*.06,sy*.06,1.25),.035,.025,'trim',body,verts=6)
    for z in(.65,.95):E.box(f'band{z}',(0,0,z),(.36-.25*(z-.65),.36-.25*(z-.65),.04),'trim',body,bevel=.01)
    E.cyl('mast',(0,0,1.45),.03,.02,.5,'dark',body,verts=8)
    E.ell('dish',(.12,-.08,1.28),(.26,.26,.07),'acc',body,seg=20,rings=10)
    E.ell('beacon',(0,0,1.72),(.06,.06,.06),'glow',body,seg=10,rings=6)
    E.box('panel',(0,-.29,.28),(.3,.02,.16),'glow',body,bevel=.005)
    E.export('prop_relay.glb')
def gate():
    E.reset();root,body,L,R=E.rig()
    E.cyl('plinth',(0,0,.08),.95,1.0,.16,'dark',body,verts=32)
    E.cyl('deck',(0,0,.2),.8,.85,.1,'base',body,verts=32)
    E.cyl('core',(0,0,.27),.55,.55,.04,'glow',body,verts=32)
    for a in range(3):
        ang=a*2*math.pi/3;x=math.cos(ang)*.82;y=math.sin(ang)*.82
        E.box(f'pylon{a}',(x,y,.6),(.16,.16,.9),'trim',body,rot=(0,0,ang),bevel=.03)
        E.box(f'cap{a}',(x,y,1.08),(.22,.22,.08),'acc',body,rot=(0,0,ang),bevel=.02)
        E.seg(f'arc{a}',(x*.95,y*.95,1.0),(0,0,.7),.025,.02,'acc',body,verts=6)
    E.ell('eye',(0,0,.7),(.16,.16,.16),'glow',body,seg=14,rings=8)
    E.export('prop_gate.glb')
def recorder():
    E.reset();root,body,L,R=E.rig()
    E.box('crater',(0,0,.02),(1.3,.9,.04),'dark',body,bevel=.02)
    E.box('hull',(0,0,.22),(.9,.42,.32),'base',body,rot=(0,.12,.25),bevel=.06)
    E.box('stripe',(.05,0,.39),(.6,.44,.06),'acc',body,rot=(0,.12,.25),bevel=.01)
    E.cyl('fin',(-.38,-.1,.42),.02,.02,.4,'trim',body,rot=(.4,0,.3),verts=6)
    E.ell('light',(.38,.05,.38),(.06,.06,.06),'glow',body,seg=10,rings=6)
    for i in range(4):E.box(f'debris{i}',(math.cos(i*1.7)*.62,math.sin(i*1.7)*.42,.05),(.12,.08,.05),'trim',body,rot=(0,0,i),bevel=.01)
    E.export('prop_recorder.glb')
def shuttle():
    E.reset();root,body,L,R=E.rig()
    E.ell('fuselage',(0,0,.55),(.42,1.25,.32),'base',body,seg=24,rings=12)
    E.ell('cockpit',(0,-.95,.68),(.32,.26,.2),'glow',body,seg=16,rings=8)
    for sx in(-1,1):
        E.box(f'wing{sx}',(sx*.75,.15,.5),(.9,.5,.06),'trim',body,rot=(0,sx*-.12,0),bevel=.02)
        E.cyl(f'engine{sx}',(sx*.45,.85,.55),.16,.13,.5,'dark',body,rot=(math.pi/2,0,0),verts=14)
        E.ell(f'exh{sx}',(sx*.45,1.11,.55),(.1,.03,.1),'acc',body,seg=12,rings=6)
        E.seg(f'gear{sx}',(sx*.35,0,.3),(sx*.42,0,.02),.03,.03,'dark',body,verts=6)
    E.box('tail',(0,.75,.92),(.06,.4,.45),'trim',body,bevel=.02)
    E.box('stripe',(0,-.2,.86),(.3,.9,.04),'acc',body,bevel=.01)
    E.export('prop_shuttle.glb')
def pod():
    E.reset();root,body,L,R=E.rig()
    E.cyl('pod',(0,0,.35),.3,.22,.7,'base',body,verts=12,smooth=False)
    E.cyl('cap',(0,0,.74),.22,.08,.12,'trim',body,verts=12,smooth=False)
    for a in range(3):
        ang=a*2*math.pi/3;E.box(f'fin{a}',(math.cos(ang)*.3,math.sin(ang)*.3,.2),(.05,.22,.3),'trim',body,rot=(0,0,ang+math.pi/2),bevel=.01)
    E.box('band',(0,0,.5),(.62,.62,.06),'acc',body,bevel=.02)
    E.ell('light',(0,0,.84),(.05,.05,.05),'glow',body,seg=10,rings=6)
    E.export('prop_pod.glb')
relay();gate();recorder();shuttle();pod()
