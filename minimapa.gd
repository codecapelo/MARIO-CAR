extends Control

# ============================================================
#  MINIMAPA — desenha a pista vista de cima e a posição de cada
#  kart. Como a pista já é uma Curve3D (no TrackPath), não precisa
#  de arte: amostramos a curva e projetamos no plano (x, z).
# ============================================================

@export var path_node: NodePath        # o Path3D da pista
@export var kart_path: NodePath         # o kart do jogador (ponto amarelo)

var _curva: Curve3D
var _pontos: PackedVector2Array = PackedVector2Array()
var _min := Vector2.ZERO
var _esc := 1.0
var _margem := 10.0


func _ready() -> void:
	var p := get_node_or_null(path_node) as Path3D
	if p:
		_curva = p.curve
	_preparar_pontos()


# Converte a curva 3D em pontos 2D que cabem no quadrado do minimapa.
func _preparar_pontos() -> void:
	if _curva == null:
		return
	var comprimento := _curva.get_baked_length()
	if comprimento <= 0.0:
		return
	var amostras := 80
	var bruto: PackedVector2Array = PackedVector2Array()
	for i in amostras + 1:
		var pos := _curva.sample_baked(comprimento * float(i) / amostras)
		bruto.append(Vector2(pos.x, pos.z))   # vista de cima = (x, z)

	# Acha o retângulo que envolve a pista para normalizar a escala.
	var minv := bruto[0]
	var maxv := bruto[0]
	for v in bruto:
		minv = minv.min(v)
		maxv = maxv.max(v)
	_min = minv
	var tam := maxv - minv
	var lado := minf(size.x, size.y) - _margem * 2.0
	_esc = lado / maxf(maxf(tam.x, tam.y), 0.001)

	_pontos.clear()
	for v in bruto:
		_pontos.append(_mundo_para_mapa3(Vector3(v.x, 0.0, v.y)))


func _mundo_para_mapa3(p3: Vector3) -> Vector2:
	return (Vector2(p3.x, p3.z) - _min) * _esc + Vector2(_margem, _margem)


func _process(_delta: float) -> void:
	queue_redraw()   # redesenha todo frame para os pontos se moverem


func _draw() -> void:
	if _pontos.size() < 2:
		return
	# Fundo translúcido para o mapa "destacar" do cenário.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), true)
	# A pista (linha branca grossa).
	draw_polyline(_pontos, Color(1, 1, 1, 0.8), 3.0, true)

	# Pontos dos karts: amarelo = jogador, azul = rivais.
	for n in get_tree().get_nodes_in_group("corredores"):
		var no := n as Node3D
		if no == null:
			continue
		var ponto := _mundo_para_mapa3(no.global_position)
		var eh_jogador: bool = no.is_in_group("jogador")
		var cor := Color(1, 0.9, 0.2) if eh_jogador else Color(0.4, 0.65, 1.0)
		draw_circle(ponto, 5.0 if eh_jogador else 4.0, cor)
