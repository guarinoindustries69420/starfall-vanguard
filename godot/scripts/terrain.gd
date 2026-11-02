# Starfall Vanguard: deformable ground. A heightmap at half-metre resolution, drawn in 20 m chunks and backed by one
# HeightMapShape3D. Streets and kerbs are painted into it. Ordnance digs craters with a raised lip and a scorch mark;
# craters never fill back in, and the mission saves them so a revisited map is still scarred.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D
class_name Terrain

const RES := 0.5                  # metres between height samples
const CH := 40                    # cells per chunk side (20 m)
const MIN_H := -3.5               # deepest the ground can be dug
var surf_col := [Color("5a4a36"), Color("2e2f33"), Color("5f5f62"), Color("66625b")]   # dirt, asphalt, kerb, pavement

var size := 0.0; var n := 0; var origin := 0.0
var h := PackedFloat32Array(); var surf := PackedByteArray(); var scorch := PackedFloat32Array()
var chunks := {}                  # Vector2i -> MeshInstance3D
var shape: HeightMapShape3D
var mat: StandardMaterial3D
var body: StaticBody3D

func setup(sz: float, material: StandardMaterial3D, layer: int) -> void:
	size = sz; origin = -sz / 2.0; n = int(round(sz / RES)) + 1
	h.resize(n * n); h.fill(0.0); surf.resize(n * n); surf.fill(0); scorch.resize(n * n); scorch.fill(0.0)
	mat = material; mat.vertex_color_use_as_albedo = true
	body = StaticBody3D.new(); body.collision_layer = layer; body.collision_mask = 0; add_child(body)
	var cs := CollisionShape3D.new(); shape = HeightMapShape3D.new(); shape.map_width = n; shape.map_depth = n
	cs.shape = shape; cs.scale = Vector3(RES, 1, RES); body.add_child(cs)

func _i(x: float) -> int: return clampi(int(round((x - origin) / RES)), 0, n - 1)

# ground height at a world point, bilinear between samples
func height_at(x: float, z: float) -> float:
	var fx: float = clamp((x - origin) / RES, 0.0, n - 1.001); var fz: float = clamp((z - origin) / RES, 0.0, n - 1.001)
	var i := int(fx); var j := int(fz); var u := fx - i; var v := fz - j
	var a := h[j * n + i]; var b := h[j * n + i + 1]; var c := h[(j + 1) * n + i]; var d := h[(j + 1) * n + i + 1]
	return lerp(lerp(a, b, u), lerp(c, d, u), v)

# paint a rectangle of surface type and height (used for streets, kerbs and pavements before the first build)
func paint_rect(x0: float, z0: float, x1: float, z1: float, kind: int, height: float) -> void:
	for j in range(_i(z0), _i(z1) + 1):
		for i in range(_i(x0), _i(x1) + 1):
			surf[j * n + i] = kind; h[j * n + i] = height

# dig a crater: bowl of depth about a third of the radius, a lip of thrown earth, scorched centre
func crater(p: Vector3, r: float, rebuild := true) -> void:
	var depth := r * .32; var reach := r * 1.55
	var i0 := _i(p.x - reach); var i1 := _i(p.x + reach); var j0 := _i(p.z - reach); var j1 := _i(p.z + reach)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var x := origin + i * RES; var z := origin + j * RES
			var d := Vector2(x - p.x, z - p.z).length() / r
			var k := j * n + i; var dh := 0.0
			if d < 1.0: dh = -depth * (1.0 - d * d)
			elif d < 1.55: dh = depth * .38 * sin(PI * (d - 1.0) / .55)
			h[k] = max(MIN_H, h[k] + dh)
			if d < 1.3:
				scorch[k] = max(scorch[k], clamp(1.15 - d * .8, 0.0, 1.0))
				if surf[k] != 0 and d < .9: surf[k] = 0      # paving is blown away, earth shows through
	if not rebuild: return
	for cj in range(int(j0 / CH), int(j1 / CH) + 1):
		for ci in range(int(i0 / CH), int(i1 / CH) + 1): _chunk(ci, cj)
	shape.map_data = h

func build_all() -> void:
	var nc := int(ceil(float(n - 1) / CH))
	for cj in nc:
		for ci in nc: _chunk(ci, cj)
	shape.map_data = h

func _norm(i: int, j: int) -> Vector3:
	var l := h[j * n + max(i - 1, 0)]; var r := h[j * n + min(i + 1, n - 1)]
	var dn := h[max(j - 1, 0) * n + i]; var up := h[min(j + 1, n - 1) * n + i]
	return Vector3(l - r, 2.0 * RES, dn - up).normalized()

func _chunk(ci: int, cj: int) -> void:
	var i0 := ci * CH; var j0 := cj * CH; var i1: int = min(i0 + CH, n - 1); var j1: int = min(j0 + CH, n - 1)
	if i0 >= n - 1 or j0 >= n - 1: return
	var w := i1 - i0 + 1
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * n + i
			verts.append(Vector3(origin + i * RES, h[k], origin + j * RES)); norms.append(_norm(i, j))
			var c: Color = surf_col[surf[k]]
			var s := scorch[k]
			if h[k] < -.05 and surf[k] == 0: c = c.darkened(clamp(-h[k] * .12, 0.0, .25))   # freshly turned earth is darker
			cols.append(c.lerp(Color("1b1714"), s * .8))
	for j in range(j1 - j0):
		for i in range(w - 1):
			var a := j * w + i
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var key := Vector2i(ci, cj)
	if not chunks.has(key):
		var mi := MeshInstance3D.new(); mi.material_override = mat; add_child(mi); chunks[key] = mi
	(chunks[key] as MeshInstance3D).mesh = m
