extends CharacterBody3D

# ============================================================
#  IA DO RIVAL — segue a curva da pista (TrackPath) com "elástico"
#  (rubber-banding): se está muito atrás do jogador, acelera; se está
#  muito na frente, alivia — assim a corrida fica sempre disputada.
#
#  O rival agora é um CORPO FÍSICO (CharacterBody3D): em vez de se
#  teleportar para a curva, ele anda em direção ao ponto ideal usando
#  uma "velocidade-alvo", e o move_and_slide() resolve as COLISÕES com
#  os outros karts. Resultado: os carrinhos não se atravessam mais —
#  batem e deslizam um no outro.
#
#  Ele colide SÓ com outros karts (máscara "Karts"), ignorando a pista
#  no cálculo de colisão. Assim continua seguindo a curva plana sem
#  bater na rampa nem precisar de gravidade.
#
#  O rival só anda depois da largada (Jogo.estado == CORRENDO).
# ============================================================

@export var velocidade_base: float = 18.0   # metros por segundo (ritmo natural)
@export var offset_lateral: float = 4.5      # quanto fica para o lado da pista
@export var ganho_borracha: float = 0.06     # quão forte reage à distância
@export var vel_min: float = 13.0            # nunca anda mais devagar que isso
@export var vel_max: float = 25.0            # nem mais rápido que isso
@export var indice: int = 1                  # número do rival (1, 2, 3...)
@export var cor: Color = Color(0.16, 0.62, 0.2, 1)  # cor do corpo do rival

# Se for empurrado para MUITO longe do lugar dele na pista (batida feia,
# largada, respawn), reposiciona direto em vez de voltar correndo — evita
# disparos esquisitos.
const DISTANCIA_TELEPORTE: float = 10.0
# Teto da velocidade de reconvergência (× a velocidade atual), para o kart
# não "tremer" tentando voltar ao lugar depois de uma trombada.
const FATOR_VEL_MAX: float = 1.8

var curva: Curve3D
var no_path: Node3D
var pista: Node                              # o gerente da corrida (grupo "pista")
var dist: float = 0.0                        # distância já percorrida na curva

@onready var motor: AudioStreamPlayer3D = get_node_or_null("MotorNPC")
var _rodas: Array = []
var _rodas_base: Array = []   # basis original de cada roda (para girar certo)


func _ready() -> void:
	add_to_group("corredores")
	add_to_group("rivais")

	# Movimento "flutuante": sem gravidade nem noção de chão. O kart anda no
	# plano da pista e o move_and_slide() só serve para bater nos outros karts.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	no_path = get_node_or_null("../TrackPath") as Node3D
	if no_path:
		curva = (no_path as Path3D).curve
	else:
		push_warning("NPC '%s': TrackPath não encontrado — o rival vai ficar parado." % name)

	pista = get_tree().get_first_node_in_group("pista")

	# Já começa alinhado na linha de largada (sobre a curva, no seu corredor).
	if curva:
		var par := _alvo_e_frente(0.0)
		global_position = par[0]
		look_at(global_position + par[1], Vector3.UP)

	_pintar_corpo()
	_coletar_rodas()

	if motor:
		motor.play()


func _physics_process(delta: float) -> void:
	if curva == null:
		return
	var comprimento := curva.get_baked_length()
	if comprimento <= 0.0:
		return

	# Só avança depois da largada.
	var correndo: bool = (Jogo.estado == Jogo.Estado.CORRENDO)
	var vel := velocidade_base
	if correndo:
		vel = _velocidade_com_elastico()
		dist = fmod(dist + vel * delta, comprimento)
		_girar_rodas(vel, delta)

	_seguir_pista(delta, vel)

	# Motor espacial: um zumbido que varia um pouco com a velocidade.
	if motor:
		motor.pitch_scale = 0.85 + (vel / vel_max) * 0.5


# Calcula a velocidade do rival reagindo à distância para o jogador.
func _velocidade_com_elastico() -> float:
	# O gerente (grupo "pista") só entra no grupo depois do _ready do pai,
	# então pode estar nulo no início: buscamos de novo até encontrar.
	if pista == null:
		pista = get_tree().get_first_node_in_group("pista")
	if pista == null or not pista.has_method("progresso_de") or not pista.has_method("progresso_jogador"):
		return velocidade_base
	var meu: float = pista.progresso_de(self)
	var jog: float = pista.progresso_jogador()
	var diferenca := jog - meu          # positivo = estou atrás do jogador
	return clampf(velocidade_base + diferenca * ganho_borracha, vel_min, vel_max)


# Anda em direção ao ponto ideal na pista, deixando o move_and_slide() resolver
# as colisões com os outros karts (é isso que produz a "trombada").
func _seguir_pista(delta: float, vel: float) -> void:
	var par := _alvo_e_frente(dist)
	var alvo: Vector3 = par[0]
	var frente: Vector3 = par[1]

	# Vetor até o ponto ideal, só no plano (a pista é plana, y é constante).
	var para_alvo := alvo - global_position
	para_alvo.y = 0.0

	if para_alvo.length() > DISTANCIA_TELEPORTE:
		# Muito longe (largada / respawn / empurrão forte): reposiciona na pista.
		global_position = alvo
		velocity = Vector3.ZERO
	else:
		# Velocidade que chegaria ao ponto ideal neste frame. Quando há outro
		# kart na frente, o move_and_slide() segura e o rival desliza para o
		# lado em vez de atravessar. O teto evita tremores ao reconvergir.
		velocity = (para_alvo / delta).limit_length(vel * FATOR_VEL_MAX)

	move_and_slide()
	global_position.y = alvo.y   # trava a altura na pista (sem subir/cair)

	# Aponta o corpo na direção da pista (só visual; não afeta a colisão).
	look_at(global_position + frente, Vector3.UP)


# Devolve [ponto_ideal_no_corredor, direção_para_frente] numa distância da curva.
func _alvo_e_frente(d: float) -> Array:
	var comprimento := curva.get_baked_length()
	var pos := curva.sample_baked(d)
	var frente := curva.sample_baked(fmod(d + 1.5, comprimento)) - pos
	frente.y = 0.0
	if frente.length() < 0.01:
		frente = -global_transform.basis.z
	frente = frente.normalized()
	var lado := Vector3.UP.cross(frente).normalized()
	return [pos + lado * offset_lateral, frente]


# Gira as rodas proporcional à velocidade (puro visual).
func _girar_rodas(vel: float, delta: float) -> void:
	if _rodas.is_empty():
		return
	var ang := (vel / 0.42) * delta   # 0.42 = raio da roda; ω = v / r
	for i in _rodas.size():
		var r := _rodas[i] as Node3D
		if r:
			# Gira em torno do eixo X local do kart (o eixo das rodas).
			var bb: Basis = Basis(Vector3.RIGHT, _giro_acumulado(i, ang)) * _rodas_base[i]
			r.transform.basis = bb


var _giros: Array = []
func _giro_acumulado(i: int, passo: float) -> float:
	while _giros.size() <= i:
		_giros.append(0.0)
	_giros[i] += passo
	return float(_giros[i])


func _coletar_rodas() -> void:
	for nome in ["RodaFE", "RodaFD", "RodaTE", "RodaTD", "AroFE", "AroFD", "AroTE", "AroTD"]:
		var r := get_node_or_null("Visual/" + nome) as Node3D
		if r:
			_rodas.append(r)
			_rodas_base.append(r.transform.basis)


# Dá ao rival uma cor própria (cada rival fica de um tom diferente).
func _pintar_corpo() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.metallic = 0.35
	mat.roughness = 0.35
	for nome in ["Chassi", "Corpo", "AsaTras", "PodE", "PodD"]:
		var m := get_node_or_null("Visual/" + nome) as MeshInstance3D
		if m:
			m.material_override = mat
