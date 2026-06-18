#!/usr/bin/env python3
# Gera kart_3d.tscn (jogador, vermelho) e kart_npc.tscn (rival).
# Cada kart tem:
#   - um nó "Visual" que embrulha TODA a malha (assim o script pode
#     inclinar/achatar o visual sem mexer na física nem no raycast);
#   - rodas que o script faz girar;
#   - (jogador) partículas de turbo/fumaça/poeira e sons de boost/drift;
#   - (rival) um motor com áudio espacial 3D.
import math, os, re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def norm(a):
    m = math.sqrt(a[0]*a[0]+a[1]*a[1]+a[2]*a[2])
    return (a[0]/m, a[1]/m, a[2]/m) if m > 1e-9 else (0.0, 0.0, 0.0)
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def r4(x): return round(x, 4)

def xf(cols, o):
    # Godot lê Transform3D por linhas -> emitimos a transposta (colunas corretas)
    x, y, z = cols
    v = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2], o[0], o[1], o[2]]
    return "Transform3D(" + ", ".join(str(r4(t)) for t in v) + ")"

I = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))          # identidade
WHEEL = ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))     # cilindro (Y) -> eixo X (roda)
ALONGZ = ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))    # cilindro/toro (Y) -> eixo Z

def basis_from_y(yd):
    yd = norm(yd)
    ref = (1.0, 0.0, 0.0) if abs(yd[0]) < 0.9 else (0.0, 0.0, 1.0)
    x = norm(cross(ref, yd))
    z = cross(x, yd)
    return (x, yd, z)

ARM = basis_from_y((0.0, -0.45, -1.0))   # braço apontando para frente-baixo

def build(cor_corpo, cor_accent, cor_suit, cor_capacete, com_script):
    meshes = {
        "Mesh_chassi": ("BoxMesh", "size = Vector3(1.5, 0.3, 2.9)"),
        "Mesh_corpo": ("BoxMesh", "size = Vector3(0.95, 0.42, 1.5)"),
        "Mesh_bico": ("BoxMesh", "size = Vector3(0.66, 0.22, 0.9)"),
        "Mesh_asaf": ("BoxMesh", "size = Vector3(1.6, 0.06, 0.34)"),
        "Mesh_asat": ("BoxMesh", "size = Vector3(1.5, 0.08, 0.42)"),
        "Mesh_sup": ("BoxMesh", "size = Vector3(0.08, 0.46, 0.12)"),
        "Mesh_pod": ("BoxMesh", "size = Vector3(0.3, 0.3, 1.2)"),
        "Mesh_escape": ("CylinderMesh", "top_radius = 0.07\nbottom_radius = 0.07\nheight = 0.7"),
        "Mesh_roda": ("CylinderMesh", "top_radius = 0.42\nbottom_radius = 0.42\nheight = 0.4"),
        "Mesh_aro": ("CylinderMesh", "top_radius = 0.22\nbottom_radius = 0.22\nheight = 0.42"),
        "Mesh_torso": ("CapsuleMesh", "radius = 0.27\nheight = 0.78"),
        "Mesh_cabeca": ("SphereMesh", "radius = 0.18\nheight = 0.36"),
        "Mesh_capacete": ("SphereMesh", "radius = 0.24\nheight = 0.48"),
        "Mesh_visor": ("BoxMesh", "size = Vector3(0.34, 0.13, 0.12)"),
        "Mesh_braco": ("CapsuleMesh", "radius = 0.075\nheight = 0.62"),
        "Mesh_volante": ("TorusMesh", "inner_radius = 0.1\nouter_radius = 0.19"),
    }
    mats = {
        "Mat_corpo": (cor_corpo, "metallic = 0.35\nroughness = 0.35"),
        "Mat_escuro": ("Color(0.08, 0.08, 0.1, 1)", "roughness = 0.6"),
        "Mat_accent": (cor_accent, "roughness = 0.4"),
        "Mat_aro": ("Color(0.7, 0.72, 0.78, 1)", "metallic = 0.8\nroughness = 0.3"),
        "Mat_suit": (cor_suit, "roughness = 0.6"),
        "Mat_pele": ("Color(0.85, 0.66, 0.52, 1)", "roughness = 0.7"),
        "Mat_capacete": (cor_capacete, "metallic = 0.2\nroughness = 0.3"),
        "Mat_visor": ("Color(0.05, 0.06, 0.09, 1)", "metallic = 0.6\nroughness = 0.1"),
    }
    # (nome, mesh, material, cols, pos) — todas as malhas ficam dentro de "Visual"
    P = [
        ("Chassi", "Mesh_chassi", "Mat_corpo", I, (0, 0.32, 0)),
        ("Corpo", "Mesh_corpo", "Mat_corpo", I, (0, 0.62, 0.15)),
        ("Bico", "Mesh_bico", "Mat_accent", I, (0, 0.42, -1.5)),
        ("AsaFrente", "Mesh_asaf", "Mat_accent", I, (0, 0.34, -1.95)),
        ("AsaTras", "Mesh_asat", "Mat_corpo", I, (0, 1.02, 1.35)),
        ("SupTrasE", "Mesh_sup", "Mat_escuro", I, (-0.55, 0.78, 1.35)),
        ("SupTrasD", "Mesh_sup", "Mat_escuro", I, (0.55, 0.78, 1.35)),
        ("PodE", "Mesh_pod", "Mat_corpo", I, (-0.72, 0.42, 0.15)),
        ("PodD", "Mesh_pod", "Mat_corpo", I, (0.72, 0.42, 0.15)),
        ("EscapeE", "Mesh_escape", "Mat_escuro", ALONGZ, (-0.16, 0.6, 1.45)),
        ("EscapeD", "Mesh_escape", "Mat_escuro", ALONGZ, (0.16, 0.6, 1.45)),
        ("RodaFE", "Mesh_roda", "Mat_escuro", WHEEL, (-0.82, 0.42, -0.95)),
        ("RodaFD", "Mesh_roda", "Mat_escuro", WHEEL, (0.82, 0.42, -0.95)),
        ("RodaTE", "Mesh_roda", "Mat_escuro", WHEEL, (-0.82, 0.42, 0.95)),
        ("RodaTD", "Mesh_roda", "Mat_escuro", WHEEL, (0.82, 0.42, 0.95)),
        ("AroFE", "Mesh_aro", "Mat_aro", WHEEL, (-0.82, 0.42, -0.95)),
        ("AroFD", "Mesh_aro", "Mat_aro", WHEEL, (0.82, 0.42, -0.95)),
        ("AroTE", "Mesh_aro", "Mat_aro", WHEEL, (-0.82, 0.42, 0.95)),
        ("AroTD", "Mesh_aro", "Mat_aro", WHEEL, (0.82, 0.42, 0.95)),
        ("Torso", "Mesh_torso", "Mat_suit", I, (0, 0.98, 0.28)),
        ("Cabeca", "Mesh_cabeca", "Mat_pele", I, (0, 1.42, 0.18)),
        ("Capacete", "Mesh_capacete", "Mat_capacete", I, (0, 1.45, 0.16)),
        ("Visor", "Mesh_visor", "Mat_visor", I, (0, 1.45, -0.05)),
        ("BracoE", "Mesh_braco", "Mat_suit", ARM, (-0.26, 1.02, -0.05)),
        ("BracoD", "Mesh_braco", "Mat_suit", ARM, (0.26, 1.02, -0.05)),
        ("Volante", "Mesh_volante", "Mat_escuro", ALONGZ, (0, 0.92, -0.42)),
    ]

    out = "[gd_scene load_steps=2 format=3]\n\n"  # load_steps é recontado no fim
    if com_script:
        out += '[ext_resource type="Script" path="res://kart_3d.gd" id="1_kart"]\n'
        out += '[ext_resource type="AudioStream" path="res://assets/engine.wav" id="2_motor"]\n'
        out += '[ext_resource type="AudioStream" path="res://assets/whoosh.wav" id="3_whoosh"]\n'
        out += '[ext_resource type="AudioStream" path="res://assets/drift.wav" id="4_drift"]\n'
    else:
        out += '[ext_resource type="AudioStream" path="res://assets/engine.wav" id="2_motor"]\n'
    out += "\n"
    for k, (typ, body) in meshes.items():
        out += '[sub_resource type="%s" id="%s"]\n%s\n\n' % (typ, k, body)
    for k, (cor, extra) in mats.items():
        out += '[sub_resource type="StandardMaterial3D" id="%s"]\nalbedo_color = %s\n%s\n\n' % (k, cor, extra)

    if com_script:
        out += '[sub_resource type="BoxShape3D" id="Shape_corpo"]\nsize = Vector3(1.5, 0.9, 2.9)\n\n'
        # material das partículas: sem sombra, usa a cor da partícula
        out += ('[sub_resource type="StandardMaterial3D" id="Mat_part"]\n'
                'shading_mode = 0\nvertex_color_use_as_albedo = true\n'
                'transparency = 1\nalbedo_color = Color(1, 1, 1, 1)\n\n')
        out += ('[sub_resource type="SphereMesh" id="PMesh_part"]\n'
                'radius = 0.12\nheight = 0.24\nmaterial = SubResource("Mat_part")\n\n')
        out += ('[sub_resource type="ParticleProcessMaterial" id="PM_turbo"]\n'
                'direction = Vector3(0, 0, 1)\nspread = 22.0\n'
                'initial_velocity_min = 7.0\ninitial_velocity_max = 13.0\n'
                'gravity = Vector3(0, 0, 0)\nscale_min = 0.35\nscale_max = 0.85\n'
                'color = Color(1, 0.6, 0.1, 1)\n\n')
        out += ('[sub_resource type="ParticleProcessMaterial" id="PM_fumaca"]\n'
                'direction = Vector3(0, 1, 0.5)\nspread = 25.0\n'
                'initial_velocity_min = 1.0\ninitial_velocity_max = 2.5\n'
                'gravity = Vector3(0, 1.5, 0)\nscale_min = 0.25\nscale_max = 0.6\n'
                'color = Color(0.7, 0.7, 0.7, 0.45)\n\n')
        out += ('[sub_resource type="ParticleProcessMaterial" id="PM_poeira"]\n'
                'direction = Vector3(0, 1, 0)\nspread = 60.0\n'
                'initial_velocity_min = 2.0\ninitial_velocity_max = 5.0\n'
                'gravity = Vector3(0, -4, 0)\nscale_min = 0.2\nscale_max = 0.5\n'
                'color = Color(0.9, 0.9, 0.9, 0.8)\n\n')

    root = "CharacterBody3D" if com_script else "Node3D"
    out += '[node name="Kart" type="%s"]\n' % root
    if com_script:
        out += 'script = ExtResource("1_kart")\n'
    out += "\n"

    # Nó "Visual": embrulha toda a malha (a física fica no nó raiz).
    out += '[node name="Visual" type="Node3D" parent="."]\n\n'
    for (nome, mesh, mat, cols, pos) in P:
        out += '[node name="%s" type="MeshInstance3D" parent="Visual"]\n' % nome
        out += 'transform = %s\n' % xf(cols, pos)
        out += 'mesh = SubResource("%s")\n' % mesh
        out += 'material_override = SubResource("%s")\n\n' % mat

    if com_script:
        out += '[node name="Colisao" type="CollisionShape3D" parent="."]\n'
        out += 'transform = %s\n' % xf(I, (0, 0.45, 0))
        out += 'shape = SubResource("Shape_corpo")\n\n'
        out += '[node name="Motor" type="AudioStreamPlayer" parent="."]\n'
        out += 'stream = ExtResource("2_motor")\nvolume_db = -13.0\nbus = "SFX"\n\n'
        out += '[node name="SomBoost" type="AudioStreamPlayer" parent="."]\n'
        out += 'stream = ExtResource("3_whoosh")\nvolume_db = -3.0\nbus = "SFX"\n\n'
        out += '[node name="SomDrift" type="AudioStreamPlayer" parent="."]\n'
        out += 'stream = ExtResource("4_drift")\nvolume_db = -8.0\nbus = "SFX"\n\n'
        # partículas (ficam no nó raiz, não no Visual, para não herdar o roll)
        for lado, px in (("E", -0.16), ("D", 0.16)):
            out += '[node name="Turbo%s" type="GPUParticles3D" parent="."]\n' % lado
            out += 'transform = %s\n' % xf(I, (px, 0.6, 1.75))
            out += ('emitting = false\namount = 40\nlifetime = 0.5\nlocal_coords = false\n'
                    'process_material = SubResource("PM_turbo")\n'
                    'draw_pass_1 = SubResource("PMesh_part")\n\n')
        out += '[node name="Fumaca" type="GPUParticles3D" parent="."]\n'
        out += 'transform = %s\n' % xf(I, (0, 0.7, 1.6))
        out += ('amount = 16\nlifetime = 1.2\nlocal_coords = false\n'
                'process_material = SubResource("PM_fumaca")\n'
                'draw_pass_1 = SubResource("PMesh_part")\n\n')
        out += '[node name="Poeira" type="GPUParticles3D" parent="."]\n'
        out += 'transform = %s\n' % xf(I, (0, 0.25, 0.95))
        out += ('emitting = false\namount = 24\nlifetime = 0.5\nlocal_coords = false\n'
                'process_material = SubResource("PM_poeira")\n'
                'draw_pass_1 = SubResource("PMesh_part")\n\n')
    else:
        # Rival: motor com áudio espacial 3D (o npc.gd controla pitch/play).
        out += '[node name="MotorNPC" type="AudioStreamPlayer3D" parent="."]\n'
        out += ('stream = ExtResource("2_motor")\nvolume_db = -12.0\nbus = "SFX"\n'
                'unit_size = 8.0\nmax_distance = 60.0\n\n')

    # Reconta load_steps (nº de recursos + 1) para nunca dar erro ao abrir.
    n = out.count("[ext_resource") + out.count("[sub_resource")
    out = re.sub(r"load_steps=\d+", "load_steps=%d" % (n + 1), out, count=1)
    return out


# jogador (vermelho, capacete azul)
open(os.path.join(RAIZ, "kart_3d.tscn"), "w").write(
    build("Color(0.85, 0.13, 0.11, 1)", "Color(0.95, 0.8, 0.2, 1)",
          "Color(0.15, 0.32, 0.78, 1)", "Color(0.9, 0.92, 0.95, 1)", True))
# rival base (verde, capacete amarelo) — a cor de cada rival é trocada em runtime
open(os.path.join(RAIZ, "kart_npc.tscn"), "w").write(
    build("Color(0.16, 0.62, 0.2, 1)", "Color(0.95, 0.85, 0.25, 1)",
          "Color(0.1, 0.4, 0.15, 1)", "Color(0.95, 0.85, 0.2, 1)", False))
print("kart_3d.tscn e kart_npc.tscn gerados (Visual + partículas + sons).")
