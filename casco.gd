extends Area3D

# ============================================================
#  CASCO (verde) — projétil que anda reto para frente. No primeiro
#  corredor que acertar (menos o dono no disparo), faz RODOPIAR.
#  Some por tempo ou se cair do mapa.
# ============================================================

var dono: Node = null
var direcao: Vector3 = Vector3.FORWARD   # definido por quem dispara
var velocidade: float = 34.0
var _vida: float = 3.5


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _physics_process(delta: float) -> void:
	global_position += direcao * velocidade * delta
	rotate_y(delta * 6.0)
	_vida -= delta
	if _vida <= 0.0 or global_position.y < -6.0:
		queue_free()


func _ao_entrar(corpo: Node) -> void:
	if not corpo.is_in_group("corredores"):
		return
	# ignora o dono no instante do disparo (ele está logo atrás do casco)
	if corpo == dono and _vida > 3.2:
		return
	if corpo.has_method("rodopiar"):
		corpo.rodopiar(0.9)
	queue_free()
