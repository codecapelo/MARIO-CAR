extends CharacterBody3D

# ============================================================
#  KART 3D — ARCADE com "SEGUIR O CHÃO" (dirige rampas e loop)
#
#  O kart agora INCLINA para acompanhar a superfície embaixo dele
#  (detectada por um raycast). A gravidade continua REAL: ao subir,
#  ela tira velocidade (precisa de embalo); ao descer, devolve.
#  Assim dá pra fazer o loop SE entrar rápido o suficiente.
# ============================================================

@export var velocidade_maxima: float = 24.0
@export var velocidade_maxima_re: float = 9.0
@export var aceleracao: float = 18.0
@export var atrito: float = 14.0
@export var velocidade_giro: float = 2.4
@export var velocidade_minima_para_virar: float = 0.8
@export var gravidade: float = 28.0
@export var altura_de_queda: float = -6.0
@export var boost_extra: float = 16.0
@export var forca_alinhar: float = 22.0    # quão rápido o kart se cola na pista
@export var forca_grude: float = 4.0       # empurrãozinho contra a pista (contato)
@export var forca_grude_loop: float = 4.0  # snap EXTRA (m) em paredes/loop p/ segurar a curva

var velocidade_atual: float = 0.0
var travado: bool = true
var boost_timer: float = 0.0

var no_chao: bool = false
var chao_normal: Vector3 = Vector3.UP
var _transform_inicial: Transform3D
@onready var motor: AudioStreamPlayer = get_node_or_null("Motor")


func _ready() -> void:
	_transform_inicial = global_transform
	floor_max_angle = PI          # qualquer inclinação conta como "chão" (até invertido)
	floor_stop_on_slope = false
	if motor and motor.stream is AudioStreamWAV:
		var s: AudioStreamWAV = motor.stream
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		motor.play()


func _teto() -> float:
	return velocidade_maxima + (boost_extra if boost_timer > 0.0 else 0.0)


func _physics_process(delta: float) -> void:
	if travado:
		velocity = -global_transform.basis.y * 2.0   # assenta no chão
		move_and_slide()
		_atualizar_motor()
		return

	_detectar_chao()
	_acelerar_ou_frear(delta)
	_virar(delta)
	_mover(delta)
	if boost_timer > 0.0:
		boost_timer -= delta
	_atualizar_motor()
	_checar_queda()


# Raycast "para baixo" (relativo ao kart) para achar a pista e sua inclinação.
func _detectar_chao() -> void:
	var space := get_world_3d().direct_space_state
	var up := global_transform.basis.y
	var origem := global_position + up * 1.0
	var destino := global_position - up * 2.6
	var q := PhysicsRayQueryParameters3D.create(origem, destino)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	no_chao = not hit.is_empty()
	if no_chao:
		chao_normal = hit["normal"]


func _acelerar_ou_frear(delta: float) -> void:
	if Input.is_action_pressed("acelerar"):
		velocidade_atual += aceleracao * delta
	elif Input.is_action_pressed("re"):
		velocidade_atual -= aceleracao * delta
	else:
		velocidade_atual = move_toward(velocidade_atual, 0.0, atrito * delta)
	velocidade_atual = clamp(velocidade_atual, -velocidade_maxima_re, _teto())


# Gira em torno do "para cima" ATUAL do kart (funciona mesmo inclinado/no loop).
func _virar(delta: float) -> void:
	if absf(velocidade_atual) < velocidade_minima_para_virar:
		return
	var sentido := Input.get_axis("virar_esquerda", "virar_direita")
	rotate(global_transform.basis.y.normalized(), -sentido * velocidade_giro * delta)


func _mover(delta: float) -> void:
	if no_chao:
		# 1) inclina o kart para acompanhar a superfície (mantendo a direção de frente)
		var frente := -global_transform.basis.z
		var f_proj := frente - chao_normal * frente.dot(chao_normal)
		if f_proj.length() > 0.01:
			f_proj = f_proj.normalized()
			var direita := f_proj.cross(chao_normal).normalized()
			var alvo := Basis(direita, chao_normal, -f_proj).orthonormalized()
			var atual := global_transform.basis.orthonormalized()
			global_transform.basis = atual.slerp(alvo, clampf(forca_alinhar * delta, 0.0, 1.0))

		# 2) gravidade ao longo da inclinação: subir tira velocidade, descer devolve
		var frente2 := -global_transform.basis.z
		velocidade_atual -= gravidade * frente2.y * delta
		velocidade_atual = clamp(velocidade_atual, -velocidade_maxima_re, _teto())

		# 3) anda na superfície; o FLOOR SNAP é que segura o kart na pista.
		#    Snap forte nas partes íngremes/invertidas (loop), fraco no plano
		#    (assim a rampa ainda consegue lançar o kart no fim dela).
		floor_snap_length = 0.4 + forca_grude_loop * (1.0 - clampf(chao_normal.y, 0.0, 1.0))
		velocity = frente2 * velocidade_atual - chao_normal * forca_grude
		up_direction = chao_normal
		apply_floor_snap()
	else:
		# no ar: voo balístico com gravidade do mundo
		velocity += Vector3.DOWN * gravidade * delta
		up_direction = Vector3.UP

	move_and_slide()


func _checar_queda() -> void:
	if global_position.y < altura_de_queda:
		velocity = Vector3.ZERO
		velocidade_atual = 0.0
		boost_timer = 0.0
		global_transform = _transform_inicial


func aplicar_boost(duracao: float = 2.0) -> void:
	boost_timer = maxf(boost_timer, duracao)
	velocidade_atual = velocidade_maxima + boost_extra


func _atualizar_motor() -> void:
	if motor:
		motor.pitch_scale = 0.75 + (absf(velocidade_atual) / velocidade_maxima) * 0.85
