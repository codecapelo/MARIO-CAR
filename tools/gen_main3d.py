#!/usr/bin/env python3
# Gera main_3d.tscn: ponte estilo Mario Kart com largada, IA, caixas de turbo,
# pista larga e levemente inclinada nas curvas, oceano/céu/montanhas.
import math

OUT = "/Users/test/Aplicativos_raul/mariocard/main_3d.tscn"

def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def add(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def mul(a, s): return (a[0]*s, a[1]*s, a[2]*s)
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a, a))
def norm(a):
    m = length(a)
    return (a[0]/m, a[1]/m, a[2]/m) if m > 1e-9 else (0.0, 0.0, 0.0)
def r4(x): return round(x, 4)
UP = (0.0, 1.0, 0.0)

def basis_look(forward, up=UP):
    z = norm(mul(forward, -1.0))
    x = norm(cross(up, z))
    y = cross(z, x)
    return x, y, z

def xf(cols, origin):
    # O texto do Transform3D no Godot é lido por LINHAS (Basis(linha0, linha1, linha2)).
    # Para que as COLUNAS (eixos x,y,z) fiquem corretas, emitimos a transposta.
    x, y, z = cols
    v = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2], origin[0], origin[1], origin[2]]
    return "Transform3D(" + ", ".join(str(r4(t)) for t in v) + ")"

def pos_xf(origin):
    return "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (r4(origin[0]), r4(origin[1]), r4(origin[2]))

# ---------- circuito ----------
N = 16
pts = []
for i in range(N):
    th = 2.0*math.pi*i/N
    r = 105.0 + 24.0*math.sin(3.0*th + 0.6) + 16.0*math.cos(2.0*th - 0.3)
    pts.append((r*math.cos(th), 0.0, r*math.sin(th)))

def tangent_at(i):
    return norm(mul(sub(pts[(i+1) % N], pts[(i-1) % N]), 0.5))

# Sem inclinação: o banking torcia a pista na largada (kart travava e a
# faixa quadriculada ficava torta). Pista plana resolve os dois.
tilts = [0.0 for _ in range(N)]

curve_vals = []
for i in range(N):
    tang = mul(sub(pts[(i+1) % N], pts[(i-1) % N]), 0.5)
    out_c = mul(tang, 1.0/3.0)
    in_c = mul(out_c, -1.0)
    curve_vals += [in_c[0], in_c[1], in_c[2], out_c[0], out_c[1], out_c[2],
                   pts[i][0], pts[i][1], pts[i][2]]
curve_str = ", ".join(str(r4(v)) for v in curve_vals)
tilts_str = ", ".join(str(r4(v)) for v in tilts)

# travessas em X das torres (usa xf para ficar consistente com a convenção)
def _braco(ax, ay, bx, by):
    dx, dy = bx-ax, by-ay
    L = math.hypot(dx, dy)
    c, s = dx/L, dy/L
    cols = ((dx, dy, 0.0), (-s, c, 0.0), (0.0, 0.0, 1.0))   # X = diagonal (compr. L)
    return xf(cols, ((ax+bx)/2.0, (ay+by)/2.0, 0.0))
braco1 = _braco(-9.0, 2.0, 9.0, 9.0)
braco2 = _braco(-9.0, 9.0, 9.0, 2.0)

fwd0 = tangent_at(0)
across0 = norm(cross(UP, fwd0))
kart_xf = xf(basis_look(fwd0), (pts[0][0], 0.9, pts[0][2]))
npc_xf = xf(basis_look(fwd0), add((pts[0][0], 0.0, pts[0][2]), mul(across0, 4.0)))
linha_xf = xf(basis_look(fwd0), pts[0])
finish_xf = xf(basis_look(fwd0), (pts[0][0], 0.05, pts[0][2]))
sun_xf = xf(basis_look(norm((-0.35, -0.82, -0.45))), (0.0, 80.0, 0.0))

# rampa de salto: caixa inclinada ~16° num trecho da pista (ponto 2)
_th = math.radians(16.0)
_rf = tangent_at(2)
_rfp = norm((_rf[0]*math.cos(_th), math.sin(_th), _rf[2]*math.cos(_th)))
ramp_xf = xf(basis_look(_rfp), (pts[2][0], 0.0, pts[2][2]))

# (LOOP removido a pedido — pista limpa.) Mantém referência p/ o turbo perto da largada.
_lp1 = pts[1]; _lf1 = tangent_at(1)
loop_nodes = []

# ---------- torres + cabos ----------
torres_nodes, cabos_nodes = [], []
cabo_id = 0
for ti in (0, 5, 11):
    P = pts[ti]; fwd = tangent_at(ti); across = norm(cross(UP, fwd)); cols = basis_look(fwd)
    base = f"Torre{ti}"
    torres_nodes.append(f'''[node name="{base}" type="Node3D" parent="Torres"]
transform = {xf(cols, P)}

[node name="ColEsq" type="MeshInstance3D" parent="Torres/{base}"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -9.2, 5, 0)
mesh = SubResource("Mesh_coluna")
material_override = SubResource("Mat_vermelho")

[node name="ColDir" type="MeshInstance3D" parent="Torres/{base}"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 9.2, 5, 0)
mesh = SubResource("Mesh_coluna")
material_override = SubResource("Mat_vermelho")

[node name="VigaTopo" type="MeshInstance3D" parent="Torres/{base}"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 9.3, 0)
mesh = SubResource("Mesh_viga")
material_override = SubResource("Mat_vermelho")

[node name="VigaMeio" type="MeshInstance3D" parent="Torres/{base}"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4.8, 0)
mesh = SubResource("Mesh_viga")
material_override = SubResource("Mat_vermelho")

[node name="BracoX1" type="MeshInstance3D" parent="Torres/{base}"]
transform = {braco1}
mesh = SubResource("Mesh_braco")
material_override = SubResource("Mat_vermelho")

[node name="BracoX2" type="MeshInstance3D" parent="Torres/{base}"]
transform = {braco2}
mesh = SubResource("Mesh_braco")
material_override = SubResource("Mat_vermelho")
''')
    # (cabos removidos a pedido — ponte sem cabos)

# ---------- caixas de item (turbo) em fileiras ----------
itens_nodes, item_id = [], 0
for pi in (3, 8, 13):
    P = pts[pi]; across = norm(cross(UP, tangent_at(pi)))
    for o in (-3.5, 0.0, 3.5):
        item_id += 1
        origem = add(add(P, mul(across, o)), (0.0, 1.4, 0.0))
        itens_nodes.append(f'''[node name="Item{item_id}" parent="Itens" instance=ExtResource("12_item")]
transform = {pos_xf(origem)}
''')
# turbo na reta de largada, logo antes do loop (pra entrar com velocidade)
_pre = add(_lp1, mul(_lf1, -16.0))
_acpre = norm(cross(UP, _lf1))
for _o in (-3.5, 0.0, 3.5):
    item_id += 1
    _orig = add(add(_pre, mul(_acpre, _o)), (0.0, 1.4, 0.0))
    itens_nodes.append('[node name="Item%d" parent="Itens" instance=ExtResource("12_item")]\ntransform = %s\n' % (item_id, pos_xf(_orig)))

# ---------- montanhas ----------
mont_centros = [
    (-340.0, -150.0, 1.35), (-280.0, 170.0, 0.95), (350.0, -260.0, 1.20),
    (390.0, 150.0, 0.80), (-40.0, -450.0, 1.65), (200.0, -390.0, 1.05),
]
mont_nodes, mi = [], 0
for (mx, mz, s) in mont_centros:
    for (dx, dz, ss) in [(0.0, 0.0, 1.0), (60.0, 25.0, 0.6), (-50.0, -35.0, 0.7)]:
        sc = s * ss; oy = -10.0 + 77.5 * sc; mi += 1
        mont_nodes.append(f'''[node name="Mont{mi}" type="MeshInstance3D" parent="Cenario"]
transform = {xf(((sc,0,0),(0,sc,0),(0,0,sc)), (mx+dx*s, oy, mz+dz*s))}
mesh = SubResource("Mesh_montanha")
material_override = SubResource("Mat_montanha")
''')
montanhas = "".join(mont_nodes)
blimp_xf = xf(((0,1,0),(-1,0,0),(0,0,1)), (140.0, 78.0, -40.0))

# ============================ HEADER ============================
header = '''[gd_scene load_steps=39 format=3]

[ext_resource type="PackedScene" path="res://kart_3d.tscn" id="1_kart"]
[ext_resource type="Script" path="res://camera_perseguidora.gd" id="2_cam"]
[ext_resource type="Shader" path="res://water.gdshader" id="3_agua"]
[ext_resource type="Texture2D" path="res://assets/sky.png" id="4_sky"]
[ext_resource type="Texture2D" path="res://assets/road_stone.png" id="5_pedra"]
[ext_resource type="PackedScene" path="res://kart_npc.tscn" id="6_npc"]
[ext_resource type="Script" path="res://corrida.gd" id="7_corrida"]
[ext_resource type="Texture2D" path="res://assets/checker.png" id="8_checker"]
[ext_resource type="Script" path="res://hud.gd" id="9_hud"]
[ext_resource type="Shader" path="res://mountain.gdshader" id="10_mont"]
[ext_resource type="Script" path="res://npc.gd" id="11_npc"]
[ext_resource type="PackedScene" path="res://item_box.tscn" id="12_item"]
[ext_resource type="AudioStream" path="res://assets/beep.wav" id="13_beep"]
[ext_resource type="AudioStream" path="res://assets/go.wav" id="14_go"]
[ext_resource type="Texture2D" path="res://assets/water_normal.png" id="15_wnormal"]

[sub_resource type="PanoramaSkyMaterial" id="Sky_mat"]
panorama = ExtResource("4_sky")

[sub_resource type="Sky" id="Sky_1"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env_1"]
background_mode = 2
sky = SubResource("Sky_1")
ambient_light_source = 2
ambient_light_color = Color(0.85, 0.84, 0.82, 1)
ambient_light_energy = 0.65
reflected_light_source = 2
tonemap_mode = 3
tonemap_exposure = 1.05
glow_enabled = true

[sub_resource type="ShaderMaterial" id="Water_mat"]
shader = ExtResource("3_agua")
shader_parameter/normalmap = ExtResource("15_wnormal")

[sub_resource type="PlaneMesh" id="Ocean_mesh"]
size = Vector2(6000, 6000)
subdivide_width = 400
subdivide_depth = 400

[sub_resource type="StandardMaterial3D" id="Mat_pedra"]
albedo_texture = ExtResource("5_pedra")
uv1_triplanar = true
uv1_world_triplanar = true
uv1_scale = Vector3(0.13, 0.13, 0.13)
roughness = 0.9

[sub_resource type="StandardMaterial3D" id="Mat_vermelho"]
albedo_color = Color(0.74, 0.12, 0.1, 1)
metallic = 0.2
roughness = 0.55

[sub_resource type="StandardMaterial3D" id="Mat_cabo"]
albedo_color = Color(0.86, 0.86, 0.83, 1)
roughness = 0.6

[sub_resource type="ShaderMaterial" id="Mat_montanha"]
shader = ExtResource("10_mont")

[sub_resource type="StandardMaterial3D" id="Mat_blimp"]
albedo_color = Color(0.92, 0.92, 0.94, 1)
metallic = 0.1
roughness = 0.4

[sub_resource type="BoxMesh" id="Mesh_coluna"]
size = Vector3(1.0, 10.0, 1.2)

[sub_resource type="BoxMesh" id="Mesh_viga"]
size = Vector3(20.0, 1.4, 1.2)

[sub_resource type="CylinderMesh" id="Mesh_cabo"]
top_radius = 0.08
bottom_radius = 0.08
height = 1.0

[sub_resource type="CylinderMesh" id="Mesh_montanha"]
top_radius = 0.0
bottom_radius = 92.0
height = 155.0
radial_segments = 28
rings = 14

[sub_resource type="CapsuleMesh" id="Mesh_blimp"]
radius = 5.0
height = 30.0

[sub_resource type="BoxMesh" id="Mesh_fin"]
size = Vector3(6.0, 0.4, 4.0)

[sub_resource type="StandardMaterial3D" id="Mat_checker"]
albedo_texture = ExtResource("8_checker")
roughness = 0.7

[sub_resource type="BoxMesh" id="Mesh_finish"]
size = Vector3(16.0, 0.08, 3.0)

[sub_resource type="BoxShape3D" id="Shape_linha"]
size = Vector3(16.0, 4.0, 2.0)

[sub_resource type="BoxMesh" id="Mesh_braco"]
size = Vector3(1.0, 0.35, 0.35)

[sub_resource type="BoxMesh" id="Mesh_rampa"]
size = Vector3(9.0, 0.6, 10.0)

[sub_resource type="BoxShape3D" id="Shape_rampa"]
size = Vector3(9.0, 0.6, 10.0)

[sub_resource type="Curve3D" id="Track_curve"]
_data = {
"points": PackedVector3Array(%CURVE%),
"tilts": PackedFloat32Array(%TILTS%),
"point_count": %N%
}

'''.replace("%CURVE%", curve_str).replace("%TILTS%", tilts_str).replace("%N%", str(N))

# ============================ CENA ============================
scene = f'''[node name="Main" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_1")

[node name="Sol" type="DirectionalLight3D" parent="."]
transform = {sun_xf}
shadow_enabled = true
light_energy = 2.1
light_color = Color(1.0, 0.97, 0.9, 1)

[node name="Oceano" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -8, 0)
mesh = SubResource("Ocean_mesh")
material_override = SubResource("Water_mat")

[node name="TrackPath" type="Path3D" parent="."]
curve = SubResource("Track_curve")

[node name="Deck" type="CSGPolygon3D" parent="."]
mode = 2
polygon = PackedVector2Array(-8, -0.5, 8, -0.5, 8, 0, -8, 0)
path_node = NodePath("../TrackPath")
path_interval_type = 0
path_interval = 2.0
path_joined = true
path_rotation = 1
use_collision = true
smooth_faces = false
material = SubResource("Mat_pedra")

[node name="FinishLine" type="MeshInstance3D" parent="."]
transform = {finish_xf}
mesh = SubResource("Mesh_finish")
material_override = SubResource("Mat_checker")

[node name="LinhaChegada" type="Area3D" parent="."]
transform = {linha_xf}
script = ExtResource("7_corrida")
label_path = NodePath("../HUD/Tempo")

[node name="Forma" type="CollisionShape3D" parent="LinhaChegada"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0)
shape = SubResource("Shape_linha")

[node name="Rampa" type="StaticBody3D" parent="."]

[node name="RampaMesh" type="MeshInstance3D" parent="Rampa"]
transform = {ramp_xf}
mesh = SubResource("Mesh_rampa")
material_override = SubResource("Mat_vermelho")

[node name="RampaCol" type="CollisionShape3D" parent="Rampa"]
transform = {ramp_xf}
shape = SubResource("Shape_rampa")

[node name="Torres" type="Node3D" parent="."]

[node name="Itens" type="Node3D" parent="."]

[node name="Cenario" type="Node3D" parent="."]

[node name="Blimp" type="MeshInstance3D" parent="Cenario"]
transform = {blimp_xf}
mesh = SubResource("Mesh_blimp")
material_override = SubResource("Mat_blimp")

[node name="KartNPC" parent="." instance=ExtResource("6_npc")]
transform = {npc_xf}
script = ExtResource("11_npc")
velocidade = 18.0
offset_lateral = 4.5

[node name="Kart" parent="." instance=ExtResource("1_kart")]
transform = {kart_xf}

[node name="Camera3D" type="Camera3D" parent="Kart"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.8, 6.5)
script = ExtResource("2_cam")

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("9_hud")
kart_path = NodePath("../Kart")
label_velocidade_path = NodePath("Velocidade")
label_largada_path = NodePath("Largada")
beep_path = NodePath("Beep")
go_path = NodePath("Go")

[node name="Tempo" type="Label" parent="HUD"]
offset_left = 22.0
offset_top = 16.0
offset_right = 430.0
offset_bottom = 150.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 30
text = "Volta: 0
Tempo: 0.00 s"

[node name="Velocidade" type="Label" parent="HUD"]
offset_left = 22.0
offset_top = 150.0
offset_right = 430.0
offset_bottom = 230.0
theme_override_colors/font_color = Color(1, 0.95, 0.6, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 42
text = "0 km/h"

[node name="Largada" type="Label" parent="HUD"]
anchor_right = 1.0
anchor_bottom = 1.0
horizontal_alignment = 1
vertical_alignment = 1
theme_override_colors/font_color = Color(1, 1, 0.3, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 12
theme_override_font_sizes/font_size = 130
text = "3"

[node name="Beep" type="AudioStreamPlayer" parent="HUD"]
stream = ExtResource("13_beep")

[node name="Go" type="AudioStreamPlayer" parent="HUD"]
stream = ExtResource("14_go")
volume_db = -2.0
'''

full = (header + "\n" + scene + "\n" + "".join(torres_nodes) + "\n"
        + "".join(itens_nodes) + "\n" + "".join(loop_nodes) + "\n" + montanhas)

with open(OUT, "w") as f:
    f.write(full)

print("main_3d.tscn (largada+IA+itens) gerado.")
print("  torres:3 | cabos:", cabo_id, "| itens:", item_id)
print("  tilts:", [r4(t) for t in tilts])
