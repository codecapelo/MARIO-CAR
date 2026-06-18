#!/usr/bin/env python3
# Gera main_3d.tscn: ponte estilo Mario Kart com largada, vários rivais
# (IA com elástico), caixas de turbo, rampa, oceano/céu/montanhas,
# ambiente turbinado (SSAO/glow/névoa), música e HUD completo.
import math, os, re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, "main_3d.tscn")

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
    # O Transform3D no Godot é lido por LINHAS; emitimos a transposta.
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

# travessas em X das torres
def _braco(ax, ay, bx, by):
    dx, dy = bx-ax, by-ay
    L = math.hypot(dx, dy)
    c, s = dx/L, dy/L
    cols = ((dx, dy, 0.0), (-s, c, 0.0), (0.0, 0.0, 1.0))
    return xf(cols, ((ax+bx)/2.0, (ay+by)/2.0, 0.0))
braco1 = _braco(-9.0, 2.0, 9.0, 9.0)
braco2 = _braco(-9.0, 9.0, 9.0, 2.0)

fwd0 = tangent_at(0)
across0 = norm(cross(UP, fwd0))
kart_xf = xf(basis_look(fwd0), (pts[0][0], 0.9, pts[0][2]))
finish_xf = xf(basis_look(fwd0), (pts[0][0], 0.05, pts[0][2]))
sun_xf = xf(basis_look(norm((-0.35, -0.82, -0.45))), (0.0, 80.0, 0.0))

# rampa de salto: caixa inclinada ~16° num trecho da pista (ponto 2)
_th = math.radians(16.0)
_rf = tangent_at(2)
_rfp = norm((_rf[0]*math.cos(_th), math.sin(_th), _rf[2]*math.cos(_th)))
ramp_xf = xf(basis_look(_rfp), (pts[2][0], 0.0, pts[2][2]))

_lp1 = pts[1]; _lf1 = tangent_at(1)

# ---------- rivais (grid lateral na largada) ----------
# (offset lateral, velocidade base, cor do corpo)
rivais = [
    (-6.0, 18.5, "Color(0.2, 0.4, 0.85, 1)"),
    (-3.0, 17.5, "Color(0.9, 0.55, 0.15, 1)"),
    (3.0, 18.0, "Color(0.16, 0.62, 0.2, 1)"),
    (6.0, 17.0, "Color(0.7, 0.25, 0.75, 1)"),
]
rivais_nodes = []
for idx, (lado, vel, cor) in enumerate(rivais):
    origem = add((pts[0][0], 0.0, pts[0][2]), mul(across0, lado))
    rivais_nodes.append(
        '[node name="Rival%d" parent="." instance=ExtResource("6_npc")]\n'
        'transform = %s\n'
        'script = ExtResource("11_npc")\n'
        'velocidade_base = %s\n'
        'offset_lateral = %s\n'
        'indice = %d\n'
        'cor = %s\n\n'
        % (idx + 1, xf(basis_look(fwd0), origem), r4(vel), r4(lado), idx + 1, cor))
rivais_str = "".join(rivais_nodes)

# ---------- torres ----------
torres_nodes = []
for ti in (0, 5, 11):
    P = pts[ti]; fwd = tangent_at(ti); cols = basis_look(fwd)
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

# ---------- caixas de item (turbo) em fileiras ----------
itens_nodes, item_id = [], 0
for pi in (3, 8, 13):
    P = pts[pi]; across = norm(cross(UP, tangent_at(pi)))
    for o in (-3.5, 0.0, 3.5):
        item_id += 1
        origem = add(add(P, mul(across, o)), (0.0, 1.4, 0.0))
        itens_nodes.append('[node name="Item%d" parent="Itens" instance=ExtResource("12_item")]\ntransform = %s\n' % (item_id, pos_xf(origem)))
# turbo na reta de largada (entrar com velocidade)
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
header = '''[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://kart_3d.tscn" id="1_kart"]
[ext_resource type="Script" path="res://camera_perseguidora.gd" id="2_cam"]
[ext_resource type="Shader" path="res://water.gdshader" id="3_agua"]
[ext_resource type="Texture2D" path="res://assets/sky.png" id="4_sky"]
[ext_resource type="Texture2D" path="res://assets/road_stone.png" id="5_pedra"]
[ext_resource type="PackedScene" path="res://kart_npc.tscn" id="6_npc"]
[ext_resource type="Texture2D" path="res://assets/checker.png" id="8_checker"]
[ext_resource type="Script" path="res://hud.gd" id="9_hud"]
[ext_resource type="Shader" path="res://mountain.gdshader" id="10_mont"]
[ext_resource type="Script" path="res://npc.gd" id="11_npc"]
[ext_resource type="PackedScene" path="res://item_box.tscn" id="12_item"]
[ext_resource type="AudioStream" path="res://assets/beep.wav" id="13_beep"]
[ext_resource type="AudioStream" path="res://assets/go.wav" id="14_go"]
[ext_resource type="Texture2D" path="res://assets/water_normal.png" id="15_wnormal"]
[ext_resource type="Script" path="res://pista.gd" id="16_pista"]
[ext_resource type="AudioStream" path="res://assets/musica_corrida.wav" id="17_musica"]
[ext_resource type="Script" path="res://minimapa.gd" id="18_mini"]
[ext_resource type="Theme" path="res://tema.tres" id="19_tema"]

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
ssao_enabled = true
ssao_radius = 1.5
ssao_intensity = 2.0
ssao_power = 1.5
glow_enabled = true
glow_intensity = 0.5
glow_bloom = 0.1
glow_hdr_threshold = 0.95
glow_blend_mode = 1
fog_enabled = true
fog_mode = 1
fog_light_color = Color(0.7, 0.8, 0.9, 1)
fog_sun_scatter = 0.2
fog_density = 0.0008
fog_sky_affect = 0.0
fog_aerial_perspective = 0.3

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

[sub_resource type="CylinderMesh" id="Mesh_montanha"]
top_radius = 0.0
bottom_radius = 92.0
height = 155.0
radial_segments = 28
rings = 14

[sub_resource type="CapsuleMesh" id="Mesh_blimp"]
radius = 5.0
height = 30.0

[sub_resource type="StandardMaterial3D" id="Mat_checker"]
albedo_texture = ExtResource("8_checker")
roughness = 0.7

[sub_resource type="BoxMesh" id="Mesh_finish"]
size = Vector3(16.0, 0.08, 3.0)

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
script = ExtResource("16_pista")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_1")

[node name="Sol" type="DirectionalLight3D" parent="."]
transform = {sun_xf}
shadow_enabled = true
shadow_blur = 1.0
light_energy = 2.1
light_color = Color(1.0, 0.97, 0.9, 1)
directional_shadow_mode = 2
directional_shadow_max_distance = 220.0
directional_shadow_split_1 = 0.1
directional_shadow_split_2 = 0.2
directional_shadow_split_3 = 0.5

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

[node name="Musica" type="AudioStreamPlayer" parent="."]
stream = ExtResource("17_musica")
volume_db = -8.0
autoplay = true
bus = "Musica"

[node name="Kart" parent="." instance=ExtResource("1_kart")]
transform = {kart_xf}

[node name="Camera3D" type="Camera3D" parent="Kart"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.8, 6.5)
script = ExtResource("2_cam")

[node name="HUD" type="CanvasLayer" parent="."]
process_mode = 3
script = ExtResource("9_hud")
kart_path = NodePath("../Kart")
label_velocidade_path = NodePath("Velocidade")
label_largada_path = NodePath("Largada")
label_tempo_path = NodePath("Tempo")
label_voltas_path = NodePath("Voltas")
label_posicao_path = NodePath("Posicao")
barra_boost_path = NodePath("BarraBoost")
menu_pausa_path = NodePath("MenuPausa")
beep_path = NodePath("Beep")
go_path = NodePath("Go")

[node name="Tempo" type="Label" parent="HUD"]
offset_left = 22.0
offset_top = 16.0
offset_right = 430.0
offset_bottom = 110.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 28
text = "Volta: 0.00 s"

[node name="Velocidade" type="Label" parent="HUD"]
offset_left = 22.0
offset_top = 110.0
offset_right = 430.0
offset_bottom = 190.0
theme_override_colors/font_color = Color(1, 0.95, 0.6, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 42
text = "0 km/h"

[node name="Voltas" type="Label" parent="HUD"]
anchor_left = 1.0
anchor_right = 1.0
offset_left = -300.0
offset_top = 16.0
offset_right = -22.0
offset_bottom = 60.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 34
horizontal_alignment = 2
text = "Volta 1/3"

[node name="Posicao" type="Label" parent="HUD"]
anchor_left = 1.0
anchor_right = 1.0
offset_left = -300.0
offset_top = 60.0
offset_right = -22.0
offset_bottom = 140.0
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 8
theme_override_font_sizes/font_size = 56
horizontal_alignment = 2
text = "1º/5"

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

[node name="BarraBoost" type="ProgressBar" parent="HUD"]
visible = false
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -130.0
offset_top = -54.0
offset_right = 130.0
offset_bottom = -30.0
max_value = 2.0
show_percentage = false

[node name="Minimapa" type="Control" parent="HUD"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -216.0
offset_top = -216.0
offset_right = -16.0
offset_bottom = -16.0
script = ExtResource("18_mini")
path_node = NodePath("../../TrackPath")
kart_path = NodePath("../../Kart")

[node name="MenuPausa" type="PanelContainer" parent="HUD"]
visible = false
theme = ExtResource("19_tema")
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -180.0
offset_top = -160.0
offset_right = 180.0
offset_bottom = 160.0
grow_horizontal = 2
grow_vertical = 2

[node name="Caixa" type="VBoxContainer" parent="HUD/MenuPausa"]
theme_override_constants/separation = 16
alignment = 1

[node name="TituloPausa" type="Label" parent="HUD/MenuPausa/Caixa"]
theme_override_font_sizes/font_size = 44
horizontal_alignment = 1
text = "PAUSA"

[node name="Continuar" type="Button" parent="HUD/MenuPausa/Caixa"]
text = "Continuar"

[node name="Reiniciar" type="Button" parent="HUD/MenuPausa/Caixa"]
text = "Reiniciar"

[node name="Menu" type="Button" parent="HUD/MenuPausa/Caixa"]
text = "Menu"

[node name="Beep" type="AudioStreamPlayer" parent="HUD"]
stream = ExtResource("13_beep")
bus = "SFX"

[node name="Go" type="AudioStreamPlayer" parent="HUD"]
stream = ExtResource("14_go")
volume_db = -2.0
bus = "SFX"
'''

full = (header + "\n" + scene + "\n" + rivais_str + "\n"
        + "".join(torres_nodes) + "\n" + "".join(itens_nodes) + "\n" + montanhas)

# Reconta load_steps automaticamente (nº de recursos + 1).
n = full.count("[ext_resource") + full.count("[sub_resource")
full = re.sub(r"load_steps=\d+", "load_steps=%d" % (n + 1), full, count=1)

with open(OUT, "w") as f:
    f.write(full)

print("main_3d.tscn gerado: %d rivais | %d itens | load_steps=%d" % (len(rivais), item_id, n + 1))
