extends MeshInstance3D

# ============================================================
#  ASFALTO DA PISTA (malha gerada por código)
#
#  Antes a pista era um CSGPolygon3D extrudado pela curva. Em
#  curvas fechadas o CSG se auto-interceptava e ABRIA BURACOS na
#  borda (dava pra ver a água, e a zebra ficava "solta" do asfalto).
#
#  Aqui montamos a faixa de asfalto como uma MALHA de verdade,
#  seguindo a Curve3D do TrackPath e FECHANDO o laço (o segmento
#  do último ponto de volta ao primeiro, que o baked deixa de fora).
#  Geramos também a COLISÃO (trimesh) para o kart continuar no chão.
#
#  IMPORTANTE: a lateral (direção da largura) é calculada UMA VEZ
#  POR VÉRTICE (diferença central), e os vértices de borda são
#  COMPARTILHADOS entre faixas vizinhas. Se calculássemos a lateral
#  por segmento, em curvas a borda de um quad não casaria com o
#  começo do próximo e abriria fendas (buracos) na pista.
# ============================================================

@export var path_node: NodePath = NodePath("../TrackPath")
@export var meia_largura: float = 8.0     # metade da largura do asfalto
@export var espessura: float = 0.5        # "saia" lateral para parecer sólido
@export var passos_por_trecho: int = 10   # suavidade da curva


func _ready() -> void:
	var p := get_node_or_null(path_node) as Path3D
	if p == null or p.curve == null:
		push_error("pista_asfalto: TrackPath/curva não encontrado.")
		return
	var curva := p.curve
	var n := curva.get_point_count()
	if n < 2:
		return

	# 1) Amostra a curva FECHADA (inclui o trecho último->primeiro).
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
	if m < 3:
		return

	# 2) Borda esquerda/direita com UMA lateral POR VÉRTICE (diferença
	#    central), compartilhada pelas faixas vizinhas -> sem fendas.
	var esq: Array[Vector3] = []
	var dir: Array[Vector3] = []
	for i in m:
		var ant := centro[(i - 1 + m) % m]
		var prox := centro[(i + 1) % m]
		var tang := prox - ant
		tang.y = 0.0
		if tang.length() < 1e-6:
			tang = Vector3.FORWARD
		tang = tang.normalized()
		var lat := Vector3.UP.cross(tang).normalized()
		esq.append(centro[i] + lat * meia_largura)
		dir.append(centro[i] - lat * meia_largura)

	# 3) Constrói a fita: topo + saias laterais, reusando os vértices.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var baixo := Vector3(0.0, -espessura, 0.0)
	for i in m:
		var j := (i + 1) % m
		var le := esq[i]
		var lj := esq[j]
		var re := dir[i]
		var rj := dir[j]
		# topo (normal para cima)
		_quad(st, le, lj, rj, re, Vector3.UP)
		# saia esquerda e direita (parecer um deck sólido)
		var nl := (le - centro[i]).normalized()
		var nr := (re - centro[i]).normalized()
		_quad(st, le + baixo, lj + baixo, lj, le, nl)
		_quad(st, re, rj, rj + baixo, re + baixo, nr)

	st.generate_tangents()
	mesh = st.commit()

	# Material visível dos dois lados (seguro contra qualquer face invertida).
	if material_override and material_override is BaseMaterial3D:
		var mm: BaseMaterial3D = material_override.duplicate()
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		material_override = mm

	# Colisão para o raycast do kart achar o chão.
	create_trimesh_collision()


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


# Quad a->b->c->d com a normal informada (dois triângulos).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(nrm)
		st.set_uv(Vector2(v.x, v.z) * 0.09)
		st.add_vertex(v)
