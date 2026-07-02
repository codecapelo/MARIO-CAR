extends MultiMeshInstance3D

# ============================================================
#  ZEBRAS (kerbs) DA PISTA — agora em MULTIMESH
#
#  Antes, cada plaquinha vermelha/branca era um nó MeshInstance3D
#  separado (~200 por pista). Cada nó desses vira um "draw call"
#  (um pedido de desenho à placa de vídeo) por quadro — e draw call
#  é caro. Com o MultiMesh, mandamos TODAS as plaquinhas de uma vez:
#  a GPU desenha as ~200 zebras num único pedido.
#
#  A cor alternada (vermelho/branco) vai na COR POR INSTÂNCIA do
#  MultiMesh — por isso o material usa vertex_color_use_as_albedo.
#
#  A amostragem da curva é a MESMA do asfalto (pista_asfalto.gd):
#  bezier fechado usando os pontos de controle do TrackPath, para a
#  zebra acompanhar exatamente a borda da pista.
# ============================================================

@export var path_node: NodePath = NodePath("../TrackPath")
@export var cor_a: Color = Color(0.85, 0.12, 0.1)   # cor das placas pares
@export var cor_b: Color = Color(0.95, 0.95, 0.96)  # cor das placas ímpares
@export var passos_por_trecho: int = 6              # subdivisões por trecho da curva
@export var afastamento: float = 7.3                # distância lateral do centro
@export var altura_y: float = 0.06                  # altura acima do asfalto


func _ready() -> void:
	var p := get_node_or_null(path_node) as Path3D
	if p == null or p.curve == null:
		push_error("pista_zebras: TrackPath/curva não encontrado.")
		return
	var curva := p.curve
	var n := curva.get_point_count()
	if n < 2:
		return

	# 1) Amostra a curva FECHADA (inclui o trecho último->primeiro),
	#    igual ao asfalto, para as placas casarem com a borda.
	var centro: Array[Vector3] = []
	for i in n:
		var a := curva.get_point_position(i)
		var a_out := a + curva.get_point_out(i)
		var j := (i + 1) % n
		var b := curva.get_point_position(j)
		var b_in := b + curva.get_point_in(j)
		for k in passos_por_trecho:
			var t := float(k) / float(passos_por_trecho)
			centro.append(_bezier(a, a_out, b_in, b, t))
	var m := centro.size()
	if m < 2:
		return

	# 2) Borda esquerda/direita como POLILINHAS PRÓPRIAS (uma lateral por
	#    vértice, igual ao asfalto). Cada placa tira comprimento e orientação
	#    do SEU trilho: no lado externo da curva os trechos são mais longos e
	#    no interno mais curtos — medir pela linha central abriria frestas.
	var esq: Array[Vector3] = []
	var dire: Array[Vector3] = []
	for i in m:
		var ant := centro[(i - 1 + m) % m]
		var prox := centro[(i + 1) % m]
		var tang := prox - ant
		tang.y = 0.0
		if tang.length() < 1e-6:
			tang = Vector3.FORWARD
		tang = tang.normalized()
		var lat := Vector3.UP.cross(tang).normalized()
		esq.append(centro[i] + lat * afastamento)
		dire.append(centro[i] - lat * afastamento)

	# 3) Monta o MultiMesh: uma caixinha esticada por segmento, dos dois lados.
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1.0, 0.12, 1.0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true   # a cor vem de cada instância
	# A cor por instância chega "crua" ao shader; sem isto o Godot a trataria
	# como linear e o vermelho escuro viraria um salmão desbotado na tela.
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.55
	caixa.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = caixa
	mm.instance_count = m * 2                # esquerda + direita

	var idx := 0
	for i in m:
		var cor := cor_a if i % 2 == 0 else cor_b
		# 2 mm alternados: as placas se sobrepõem 4% na emenda; sem esse
		# degrau invisível, os topos coplanares "piscariam" (z-fighting).
		var ny := altura_y + 0.002 * float(i % 2)
		for trilho in [esq, dire]:
			var cur: Vector3 = trilho[i]
			var nxt: Vector3 = trilho[(i + 1) % m]
			var seg := nxt - cur
			seg.y = 0.0
			var comp := seg.length()
			if comp < 0.0001:
				comp = 0.0001
				seg = Vector3.FORWARD * comp
			var frente := seg / comp
			# base olhando para a frente do trecho, esticada p/ emendar na próxima
			var base := Basis.looking_at(frente, Vector3.UP)
			base.z *= comp * 1.04
			var origem := (cur + nxt) * 0.5
			origem.y = ny
			mm.set_instance_transform(idx, Transform3D(base, origem))
			mm.set_instance_color(idx, cor)
			idx += 1

	multimesh = mm
	# Placas de 12 cm de altura não projetam sombra visível: tirar do passe
	# de sombras economiza mais um desenho por cascata de sombra.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)
