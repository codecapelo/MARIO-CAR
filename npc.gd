extends CharacterBody3D

# ============================================================
#  IA DO RIVAL — segue a curva da pista (TrackPath) com "elástico"
#  (rubber-banding): se está muito atrás do jogador, acelera; se está
#  muito na frente, alivia — assim a corrida fica sempre disputada.
#
#  O rival é um CORPO FÍSICO (CharacterBody3D): em vez de só seguir a
#  linha ideal, ele guarda uma "linha lateral atual" (_offset_atual).
#  Quando BATE em outro kart, essa linha é EMPURRADA para o lado e
#  volta devagar — então a trombada realmente tira o rival do percurso
#  (e não some no frame seguinte).
#
#  Ele também USA ITENS (por tempo): turbo, banana, casco, raio e
#  estrela, sorteados conforme a posição dele na corrida.
#
#  A dificuldade escolhida no menu deixa os rivais mais rápidos e mais
#  "elásticos".
# ============================================================

@export var velocidade_base: float = 23.0   # metros por segundo (ritmo natural)
@export var offset_lateral: float = 4.5      # quanto fica para o lado da pista
@export var ganho_borracha: float = 0.08     # quão forte reage à distância
@export var vel_min: float = 17.0            # nunca anda mais devagar que isso
@export var vel_max: float = 34.0            # nem mais rápido que isso
@export var indice: int = 1                  # número do rival (1, 2, 3...)
@export var piloto_nome: String = ""         # nome que aparece na classificação
@export var cor: Color = Color(0.16, 0.62, 0.2, 1)  # cor do corpo do rival
@export var aceleracao: float = 26.0         # acelera do zero na largada (m/s²)
@export var dist_inicial: float = 0.0        # deslocamento na pista p/ o grid

# Empurrão muito grande (largada/respawn/pilha de karts): reposiciona direto.
const DISTANCIA_TELEPORTE: float = 10.0
const FATOR_VEL_MAX: float = 1.8

var curva: Curve3D
var no_path: Node3D
var pista: Node                              # o gerente da corrida (grupo "pista")
var dist: float = 0.0                        # distância percorrida na curva
var _vel_atual: float = 0.0                  # velocidade real (sobe do zero)

# linha lateral: onde o rival "quer" ficar; muda com as batidas e volta devagar
var _offset_atual: float = 0.0
var _knock_timer: float = 0.0                # tempo "empurrado" (recupera devagar)

# poderes / penalidades
var _raio_timer: float = 0.0                 # lento por causa do raio
var _boost_timer: float = 0.0                # turbo ativo
var _estrela_timer: float = 0.0              # estrela (rápido + imune)
var _rodopio_timer: float = 0.0              # rodopiando (levou banana/casco)
var _item_timer: float = 6.0                 # quando vai usar o próximo item
var _spin_visual: float = 0.0                # giro extra do corpo no rodopio

@onready var motor: AudioStreamPlayer3D = get_node_or_null("MotorNPC")
@onready var visual: Node3D = get_node_or_null("Visual")
var _rodas: Array = []
var _rodas_base: Array = []   # basis original de cada roda (para girar certo)


func _ready() -> void:
	add_to_group("corredores")
	add_to_group("rivais")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	# Dificuldade escolhida no menu: rivais mais rápidos e mais "elásticos".
	velocidade_base *= Jogo.fator_vel_rival()
	vel_max *= Jogo.fator_vel_rival()
	ganho_borracha *= Jogo.fator_borracha()
	_offset_atual = offset_lateral
	_item_timer = randf_range(4.0, 9.0)

	no_path = get_node_or_null("../TrackPath") as Node3D
	if no_path:
		curva = (no_path as Path3D).curve
	else:
		push_warning("NPC '%s': TrackPath não encontrado — o rival vai ficar parado." % name)

	pista = get_tree().get_first_node_in_group("pista")

	# Posição de largada no grid.
	if curva:
		dist = fposmod(dist_inicial, curva.get_baked_length())
		var par := _alvo_e_frente(dist)
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

	# Temporizadores dos poderes.
	if _boost_timer > 0.0:
		_boost_timer -= delta
	if _estrela_timer > 0.0:
		_estrela_timer -= delta
	var rodopiando: bool = _rodopio_timer > 0.0
	if rodopiando:
		_rodopio_timer -= delta

	var correndo: bool = (Jogo.estado == Jogo.Estado.CORRENDO)
	if correndo:
		if rodopiando:
			# perdeu o controle: praticamente para e roda no lugar
			_vel_atual = move_toward(_vel_atual, 0.0, aceleracao * 1.5 * delta)
		else:
			var vel := _velocidade_com_elastico()
			if _raio_timer > 0.0:
				_raio_timer -= delta
				vel *= 0.35                       # atingido pelo raio: bem lento
			if _boost_timer > 0.0:
				vel += 12.0                       # turbo
			_vel_atual = move_toward(_vel_atual, vel, aceleracao * delta)

			# usa um item de tempos em tempos
			_item_timer -= delta
			if _item_timer <= 0.0:
				_usar_item_ia()
				_item_timer = randf_range(7.0, 13.0)

		dist = fmod(dist + _vel_atual * delta, comprimento)
		_girar_rodas(_vel_atual, delta)
	else:
		_vel_atual = 0.0

	_atualizar_spin_visual(delta, rodopiando)
	_seguir_pista(delta, maxf(_vel_atual, vel_min))

	if motor:
		motor.pitch_scale = 0.85 + (_vel_atual / vel_max) * 0.5


# Velocidade do rival reagindo à distância para o jogador.
func _velocidade_com_elastico() -> float:
	if pista == null:
		pista = get_tree().get_first_node_in_group("pista")
	if pista == null or not pista.has_method("progresso_de") or not pista.has_method("progresso_jogador"):
		return velocidade_base
	var meu: float = pista.progresso_de(self)
	var jog: float = pista.progresso_jogador()
	var diferenca := jog - meu          # positivo = estou atrás do jogador
	return clampf(velocidade_base + diferenca * ganho_borracha, vel_min, vel_max)


# ------------------------------------------------------------
#  PODERES recebidos / usados
# ------------------------------------------------------------
func levar_raio(duracao: float) -> void:
	if _estrela_timer > 0.0:
		return
	_raio_timer = maxf(_raio_timer, duracao)


func rodopiar(dur: float = 0.9) -> void:
	if _estrela_timer > 0.0:
		return
	_rodopio_timer = maxf(_rodopio_timer, dur)


# A IA sorteia um item (pela posição) e usa na hora.
func _usar_item_ia() -> void:
	var tipo := "turbo"
	if pista and pista.has_method("sortear_item_para"):
		tipo = pista.sortear_item_para(self)
	match tipo:
		"estrela":
			_boost_timer = maxf(_boost_timer, 5.0)
			_estrela_timer = maxf(_estrela_timer, 5.0)
		"raio":
			for r in get_tree().get_nodes_in_group("corredores"):
				if r != self and r.has_method("levar_raio"):
					r.levar_raio(3.0)
		"banana":
			_soltar_obstaculo("res://banana.tscn", -2.6, 0.1)
		"casco":
			_disparar_casco_ia()
		_:
			_boost_timer = maxf(_boost_timer, 2.5)


func _soltar_obstaculo(cena_path: String, dist_frente: float, altura: float) -> void:
	var cena := load(cena_path)
	if cena == null:
		return
	var ob = cena.instantiate()   # sem tipo fixo: vamos acessar .dono dinamicamente
	var frente := -global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	ob.dono = self
	get_tree().current_scene.add_child(ob)
	ob.global_position = global_position + frente * dist_frente + Vector3.UP * altura


func _disparar_casco_ia() -> void:
	var cena := load("res://casco.tscn")
	if cena == null:
		return
	var c = cena.instantiate()   # sem tipo fixo: vamos acessar .dono/.direcao
	var frente := -global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	c.dono = self
	c.direcao = frente
	get_tree().current_scene.add_child(c)
	c.global_position = global_position + frente * 2.6 + Vector3.UP * 0.4


# ------------------------------------------------------------
#  Seguir a pista + reagir às batidas
# ------------------------------------------------------------
func _seguir_pista(delta: float, vel: float) -> void:
	# Recupera a linha ideal — devagar logo após uma batida, normal depois.
	var recup := 0.4 if _knock_timer > 0.0 else 2.5
	_offset_atual = move_toward(_offset_atual, offset_lateral, recup * delta)
	if _knock_timer > 0.0:
		_knock_timer -= delta

	var par := _alvo_e_frente(dist)
	var alvo: Vector3 = par[0]
	var frente: Vector3 = par[1]

	var para_alvo := alvo - global_position
	para_alvo.y = 0.0

	if para_alvo.length() > DISTANCIA_TELEPORTE:
		global_position = alvo
		velocity = Vector3.ZERO
	else:
		velocity = (para_alvo / delta).limit_length(vel * FATOR_VEL_MAX)

	move_and_slide()
	global_position.y = alvo.y   # trava a altura na pista

	# Bateu em outro kart? Empurra a linha lateral para o lado (fica fora da
	# trajetória por um tempo) e perde um pouco de velocidade.
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var o = c.get_collider()   # Object: acessamos métodos de Node dinamicamente
		if o and o != self and o.is_in_group("corredores"):
			var nrm := c.get_normal()
			nrm.y = 0.0
			var lateral := Vector3.UP.cross(frente).normalized()
			_offset_atual = clampf(_offset_atual + nrm.dot(lateral) * 2.2, -7.0, 7.0)
			_knock_timer = 0.7
			_vel_atual *= 0.85
			break

	look_at(global_position + frente, Vector3.UP)


# Gira extra o corpo (Visual) quando está rodopiando; senão volta a zero.
func _atualizar_spin_visual(delta: float, rodopiando: bool) -> void:
	if visual == null:
		return
	if rodopiando:
		_spin_visual += TAU * 1.5 * delta
	else:
		_spin_visual = lerp_angle(_spin_visual, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	visual.rotation.y = _spin_visual


# [ponto_ideal_no_corredor, direção_para_frente] numa distância da curva.
func _alvo_e_frente(d: float) -> Array:
	var comprimento := curva.get_baked_length()
	var pos := curva.sample_baked(d)
	var frente := curva.sample_baked(fmod(d + 1.5, comprimento)) - pos
	frente.y = 0.0
	if frente.length() < 0.01:
		frente = -global_transform.basis.z
	frente = frente.normalized()
	var lado := Vector3.UP.cross(frente).normalized()
	return [pos + lado * _offset_atual, frente]


# Gira as rodas proporcional à velocidade (puro visual).
func _girar_rodas(vel: float, delta: float) -> void:
	if _rodas.is_empty():
		return
	var ang := (vel / 0.42) * delta   # 0.42 = raio da roda; ω = v / r
	for i in _rodas.size():
		var r := _rodas[i] as Node3D
		if r:
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
