# Embed out/trooper_kit.b64 into the game as const TKIT.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import re
p='/home/claude/starfall-vanguard.html';s=open(p).read();k=open('/home/claude/blender/out/trooper_kit.b64').read()
a=s.index("const TKIT='")+len("const TKIT='");b=s.index("'",a);s=s[:a]+k+s[b:];open(p,'w').write(s);print('swapped',len(k))
