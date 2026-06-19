extends Area3D

# ============================================================
#  BANANA — obstáculo solto na pista. Quem encostar (que não seja
#  o dono nos primeiros instantes) RODOPIA e perde velocidade.
#  Some sozinha depois de um tempo.
# ============================================================

var dono: Node = null            # quem soltou (ignorado no comecinho)
var _vida: float = 12.0
var _armar: float = 0.0


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _process(delta: float) -> void:
	_armar += delta
	_vida -= delta
	rotate_y(delta * 1.5)
	if _vida <= 0.0:
		queue_free()


func _ao_entrar(corpo: Node) -> void:
	if not corpo.is_in_group("corredores"):
		return
	# o próprio dono só é afetado depois de 1s (já saiu de cima dela)
	if corpo == dono and _armar < 1.0:
		return
	if corpo.has_method("rodopiar"):
		corpo.rodopiar(0.9)
	queue_free()
