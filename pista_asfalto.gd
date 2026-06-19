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

	# Amostra a curva FECHADA (inclui o trecho último->primeiro).
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

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := centro.size()
	var baixo := Vector3(0.0, -espessura, 0.0)
	for idx in m:
		var c0 := centro[idx]
		var c1 := centro[(idx + 1) % m]
		var fwd := c1 - c0
		fwd.y = 0.0
		if fwd.length() < 1e-5:
			continue
		fwd = fwd.normalized()
		var lat := Vector3.UP.cross(fwd).normalized()
		var l0 := c0 + lat * meia_largura
		var r0 := c0 - lat * meia_largura
		var l1 := c1 + lat * meia_largura
		var r1 := c1 - lat * meia_largura
		# topo (visto de cima)
		_quad(st, l0, l1, r1, r0, Vector3.UP)
		# saia esquerda e direita (parecer um deck sólido)
		_quad(st, l0 + baixo, l1 + baixo, l1, l0, lat)
		_quad(st, r0, r1, r1 + baixo, r0 + baixo, -lat)

	st.generate_tangents()
	mesh = st.commit()

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
