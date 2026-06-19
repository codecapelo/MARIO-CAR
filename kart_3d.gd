class_name Kart
extends CharacterBody3D

# ============================================================
#  KART 3D — ARCADE com "SEGUIR O CHÃO" (dirige rampas e loop)
#
#  O kart INCLINA para acompanhar a superfície embaixo dele
#  (detectada por um raycast). A gravidade é REAL: subir tira
#  velocidade (precisa de embalo); descer devolve.
#
#  Recursos de "kart de verdade":
#   - aceleração com PESO (forte no começo, custa chegar ao máximo);
#   - direção mais fina em alta velocidade + inércia lateral (agarra);
#   - DRIFT/derrapagem segurando o botão de drift -> mini-turbo;
#   - controle no ar e pouso com baque;
#   - respawn suave com penalidade ao cair no mar;
#   - rodas girando/esterçando, corpo inclinando, partículas e som.
# ============================================================

# --- velocidades e aceleração ---
@export var velocidade_maxima: float = 34.0
@export var velocidade_maxima_re: float = 11.0
@export var aceleracao: float = 26.0
@export var atrito: float = 10.0
@export var boost_extra: float = 24.0

# --- direção ---
@export var velocidade_giro: float = 2.4
@export var velocidade_minima_para_virar: float = 0.8
@export var giro_min_fator: float = 0.45   # em alta velocidade, vira só 45%
@export var grip: float = 8.0              # agarramento lateral (menor = mais deriva)

# --- drift / powerslide ---
@export var drift_giro_extra: float = 1.4
@export var drift_min_velocidade: float = 9.0
@export var drift_grip_fator: float = 0.35   # no drift, agarra menos (derrapa)
@export var carga_turbo1: float = 0.9        # segundos de drift p/ turbo pequeno
@export var carga_turbo2: float = 1.7        # turbo grande

# --- física do mundo ---
@export var gravidade: float = 28.0
@export var altura_de_queda: float = -6.0
@export var forca_alinhar: float = 22.0
@export var forca_grude: float = 4.0
@export var forca_grude_loop: float = 4.0

# --- estado (público: HUD, câmera e gerente da corrida leem daqui) ---
var velocidade_atual: float = 0.0
var travado: bool = true
var boost_timer: float = 0.0
var estrela_timer: float = 0.0   # tempo restante de "estrela" (super poder)
var _estrela_extra: float = 0.0  # velocidade extra que a estrela concede
var driftando: bool = false
var drift_sentido: float = 0.0   # -1 esquerda, +1 direita (travado ao iniciar)
var drift_carga: float = 0.0     # segundos acumulados derrapando

var no_chao: bool = false
var chao_normal: Vector3 = Vector3.UP
var _transform_inicial: Transform3D
var _ultimo_seguro: Transform3D
var _t_seguro: float = 0.0
var _estava_no_ar: bool = false
var _acelerando: bool = false
var _pitch_motor: float = 0.85
var _spin_rodas: float = 0.0
var _esterco: float = 0.0
var _roll: float = 0.0

# --- nós (podem não existir em versões antigas da cena: get_node_or_null) ---
@onready var motor: AudioStreamPlayer = get_node_or_null("Motor")
@onready var som_boost: AudioStreamPlayer = get_node_or_null("SomBoost")
@onready var som_drift: AudioStreamPlayer = get_node_or_null("SomDrift")
@onready var visual: Node3D = get_node_or_null("Visual")
@onready var turbo_e: GPUParticles3D = get_node_or_null("TurboE")
@onready var turbo_d: GPUParticles3D = get_node_or_null("TurboD")
@onready var fumaca: GPUParticles3D = get_node_or_null("Fumaca")
@onready var poeira: GPUParticles3D = get_node_or_null("Poeira")

var _rodas: Array = []
var _rodas_base: Array = []
var _rodas_frente: Array = []   # true para as rodas dianteiras


func _ready() -> void:
	add_to_group("jogador")
	add_to_group("corredores")
	_transform_inicial = global_transform
	_ultimo_seguro = global_transform
	floor_max_angle = PI          # qualquer inclinação conta como "chão"
	floor_stop_on_slope = false
	_coletar_rodas()
	if motor:
		motor.play()               # o loop agora vem da importação do .wav


func _teto() -> float:
	var teto := velocidade_maxima
	if boost_timer > 0.0:
		teto += boost_extra
	if estrela_timer > 0.0:
		teto += _estrela_extra
	return teto


func _physics_process(delta: float) -> void:
	if travado:
		velocity = -global_transform.basis.y * 2.0   # assenta no chão
		move_and_slide()
		_atualizar_motor()
		return

	_detectar_chao()
	_acelerar_ou_frear(delta)
	_atualizar_drift(delta)
	_virar(delta)
	_mover(delta)
	if boost_timer > 0.0:
		boost_timer -= delta
	if estrela_timer > 0.0:
		estrela_timer -= delta
		boost_timer = maxf(boost_timer, 0.2)   # mantém o turbo aceso durante a estrela
		if estrela_timer <= 0.0:
			_estrela_extra = 0.0
	_atualizar_motor()
	_atualizar_visual(delta)
	_atualizar_vfx()
	_checar_queda(delta)


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
	var teto := _teto()
	_acelerando = Input.is_action_pressed("acelerar")
	if _acelerando:
		# Quanto mais perto do teto, MENOS acelera -> sensação de "peso".
		var fracao_restante := 1.0 - clampf(velocidade_atual / teto, 0.0, 1.0)
		var empuxo := aceleracao * (0.25 + 0.75 * fracao_restante)
		velocidade_atual += empuxo * delta
	elif Input.is_action_pressed("re"):
		velocidade_atual -= aceleracao * 1.3 * delta   # ré/freio responde mais forte
	else:
		velocidade_atual = move_toward(velocidade_atual, 0.0, atrito * delta)
	# Freio de mão (tecla/botão separado): segura o kart com força.
	if Input.is_action_pressed("freio") and velocidade_atual > 0.0:
		velocidade_atual = move_toward(velocidade_atual, 0.0, aceleracao * 2.0 * delta)
	velocidade_atual = clamp(velocidade_atual, -velocidade_maxima_re, teto)


# Gira em torno do "para cima" ATUAL do kart (funciona inclinado / no loop).
func _virar(delta: float) -> void:
	if absf(velocidade_atual) < velocidade_minima_para_virar:
		return
	var sentido := Input.get_axis("virar_esquerda", "virar_direita")
	# Em alta velocidade vira menos (mais estável); devagar vira amplo.
	var frac := clampf(absf(velocidade_atual) / velocidade_maxima, 0.0, 1.0)
	var giro := velocidade_giro * lerpf(1.0, giro_min_fator, frac)
	if driftando:
		giro += drift_giro_extra
		# durante o drift mantém um piso de esterço para o lado travado
		sentido = clampf(sentido + drift_sentido * 0.5, -1.0, 1.0)
	# o kart anda de ré olhando para frente: inverte o giro na ré
	var dir := signf(velocidade_atual) if absf(velocidade_atual) > 0.1 else 1.0
	rotate(global_transform.basis.y.normalized(), -sentido * giro * delta * dir)


# Inicia/mantém o drift e converte o tempo derrapando em mini-turbo.
func _atualizar_drift(delta: float) -> void:
	if not no_chao:
		return
	var quer := Input.is_action_pressed("drift")
	var sentido := Input.get_axis("virar_esquerda", "virar_direita")
	if quer and not driftando and velocidade_atual > drift_min_velocidade and absf(sentido) > 0.2:
		driftando = true
		drift_sentido = signf(sentido)     # trava o lado da derrapagem
		drift_carga = 0.0
		if som_drift and not som_drift.playing:
			som_drift.play()
	if driftando:
		if quer and velocidade_atual > drift_min_velocidade * 0.6:
			drift_carga += delta
		else:
			_soltar_drift()


func _soltar_drift() -> void:
	# Ao soltar, a carga acumulada vira um turbinho (dois níveis, como no MK).
	if drift_carga >= carga_turbo2:
		aplicar_boost(1.3)
	elif drift_carga >= carga_turbo1:
		aplicar_boost(0.75)
	driftando = false
	drift_carga = 0.0
	drift_sentido = 0.0
	if som_drift:
		som_drift.stop()


func _mover(delta: float) -> void:
	if no_chao:
		if _estava_no_ar:
			_ao_pousar()
			_estava_no_ar = false

		# 1) inclina o kart para acompanhar a superfície (mantendo a frente)
		var frente := -global_transform.basis.z
		var f_proj := frente - chao_normal * frente.dot(chao_normal)
		if f_proj.length() > 0.01:
			f_proj = f_proj.normalized()
			var direita := f_proj.cross(chao_normal).normalized()
			var alvo := Basis(direita, chao_normal, -f_proj).orthonormalized()
			var atual := global_transform.basis.orthonormalized()
			global_transform.basis = atual.slerp(alvo, clampf(forca_alinhar * delta, 0.0, 1.0))

		# 2) gravidade ao longo da inclinação: subir tira, descer devolve
		var frente2 := -global_transform.basis.z
		velocidade_atual -= gravidade * frente2.y * delta
		velocidade_atual = clamp(velocidade_atual, -velocidade_maxima_re, _teto())

		# 3) inércia lateral (grip): conserva parte do momento de lado
		var vel_alvo := frente2 * velocidade_atual
		floor_snap_length = 0.4 + forca_grude_loop * (1.0 - clampf(chao_normal.y, 0.0, 1.0))
		if chao_normal.y < 0.5:
			# em paredes/loop, cola na direção da frente (estabilidade total)
			velocity = vel_alvo - chao_normal * forca_grude
		else:
			var vel_planar := velocity - chao_normal * velocity.dot(chao_normal)
			var g := grip * (drift_grip_fator if driftando else 1.0)
			var nova := vel_planar.lerp(vel_alvo, clampf(g * delta, 0.0, 1.0))
			velocity = nova - chao_normal * forca_grude
		up_direction = chao_normal
		apply_floor_snap()

		# salva o último ponto seguro (chão plano) para o respawn
		_t_seguro += delta
		if _t_seguro > 0.5 and chao_normal.y > 0.7 and velocidade_atual > 2.0:
			_t_seguro = 0.0
			_ultimo_seguro = global_transform
	else:
		# no ar: voo balístico + leve controle de guinada
		velocity += Vector3.DOWN * gravidade * delta
		up_direction = Vector3.UP
		var sentido := Input.get_axis("virar_esquerda", "virar_direita")
		rotate(Vector3.UP, -sentido * 1.0 * delta)
		_estava_no_ar = true

	move_and_slide()


func _ao_pousar() -> void:
	# Pousar muito de bico custa velocidade; sempre dá um baque na câmera.
	var dir_mov := velocity.normalized()
	if velocity.length() > 0.1:
		var alinhamento := (-global_transform.basis.z).dot(dir_mov)
		if alinhamento < 0.6:
			velocidade_atual *= 0.7
	_tremer_camera(0.2)
	if visual:
		# "squash": achata por um instante e volta ao normal (juice de pouso).
		var tw := create_tween()
		visual.scale = Vector3(1.15, 0.78, 1.1)
		tw.tween_property(visual, "scale", Vector3.ONE, 0.18)


func _checar_queda(_delta: float) -> void:
	if global_position.y < altura_de_queda:
		_respawn()


func _respawn() -> void:
	velocity = Vector3.ZERO
	velocidade_atual = 0.0
	boost_timer = 0.0
	estrela_timer = 0.0
	_estrela_extra = 0.0
	driftando = false
	drift_carga = 0.0
	if som_drift:
		som_drift.stop()
	global_transform = _ultimo_seguro
	_tremer_camera(0.15)
	# pequena penalidade: ~0.8s parado antes de voltar a correr
	travado = true
	await get_tree().create_timer(0.8).timeout
	# só devolve o controle se a corrida ainda estiver rolando (não no
	# resultado nem pausado), senão o kart "descongelaria" na tela de fim.
	if is_instance_valid(self) and Jogo.estado == Jogo.Estado.CORRENDO:
		travado = false


func aplicar_boost(duracao: float = 2.0) -> void:
	boost_timer = maxf(boost_timer, duracao)
	# empurra para perto do novo teto sem cravar (entrada suave)
	velocidade_atual = maxf(velocidade_atual, velocidade_maxima + boost_extra * 0.6)
	if som_boost:
		som_boost.play()
	_tremer_camera(0.3)


# Chamado pela caixa de item. Cada "tipo" dá um poder diferente.
func pegar_item(tipo: String) -> void:
	match tipo:
		"estrela":
			ativar_estrela(6.0)
		"raio":
			disparar_raio()
		_:
			aplicar_boost(2.0)   # turbo comum


# ESTRELA: um super-turbo — anda MUITO mais rápido e por mais tempo.
func ativar_estrela(duracao: float) -> void:
	estrela_timer = maxf(estrela_timer, duracao)
	_estrela_extra = 16.0
	aplicar_boost(duracao)


# RAIO: deixa todos os rivais lentos por alguns segundos (vantagem na corrida).
func disparar_raio() -> void:
	for r in get_tree().get_nodes_in_group("rivais"):
		if r.has_method("levar_raio"):
			r.levar_raio(3.5)
	if som_boost:
		som_boost.play()
	_tremer_camera(0.35)


func _tremer_camera(intensidade: float) -> void:
	var cam := get_node_or_null("Camera3D")
	if cam and cam.has_method("tremer"):
		cam.tremer(intensidade)


# ------------------------------------------------------------
#  SOM E VISUAL
# ------------------------------------------------------------
func _atualizar_motor() -> void:
	if motor == null:
		return
	# rpm normalizado pelo TETO atual (assim o turbo não estoura o pitch)
	var rpm := clampf(absf(velocidade_atual) / _teto(), 0.0, 1.0)
	var alvo := 0.85 + rpm * 0.9 + (0.12 if _acelerando else 0.0)
	_pitch_motor = lerpf(_pitch_motor, alvo, 0.18)
	motor.pitch_scale = _pitch_motor
	motor.volume_db = -16.0 + rpm * 9.0


func _atualizar_visual(delta: float) -> void:
	# 1) rodas girando (ω = v / raio) e dianteiras esterçando
	_spin_rodas += (velocidade_atual / 0.42) * delta
	var sentido := Input.get_axis("virar_esquerda", "virar_direita")
	if driftando:
		sentido = clampf(sentido + drift_sentido * 0.4, -1.0, 1.0)
	# -sentido para a roda apontar para o MESMO lado que o kart vira (ver _virar)
	_esterco = lerpf(_esterco, deg_to_rad(24.0) * -sentido, clampf(10.0 * delta, 0.0, 1.0))
	for i in _rodas.size():
		var r := _rodas[i] as Node3D
		if r == null:
			continue
		var b: Basis = Basis(Vector3.RIGHT, _spin_rodas) * _rodas_base[i]
		if _rodas_frente[i]:
			b = Basis(Vector3.UP, _esterco) * b
		r.transform.basis = b

	# 2) inclinação (roll) do corpo na curva — só no nó Visual (não afeta física)
	if visual:
		var frac := clampf(velocidade_atual / velocidade_maxima, 0.0, 1.0)
		var roll_alvo := -sentido * deg_to_rad(8.0) * frac
		if driftando:
			roll_alvo *= 1.8
		_roll = lerpf(_roll, roll_alvo, clampf(8.0 * delta, 0.0, 1.0))
		visual.rotation.z = _roll


func _atualizar_vfx() -> void:
	var em_boost := boost_timer > 0.0
	if turbo_e:
		turbo_e.emitting = em_boost
	if turbo_d:
		turbo_d.emitting = em_boost
	# fumaça do escapamento: mais ao acelerar, um fiozinho parado
	if fumaca:
		fumaca.amount_ratio = 1.0 if _acelerando else 0.3
	# poeira/faíscas ao derrapar
	if poeira:
		poeira.emitting = driftando and no_chao
		if driftando and poeira.process_material:
			# a cor sobe com a carga: branco -> laranja -> azul (mini-turbo)
			var mat := poeira.process_material as ParticleProcessMaterial
			if mat:
				if drift_carga >= carga_turbo2:
					mat.color = Color(0.4, 0.7, 1.0)
				elif drift_carga >= carga_turbo1:
					mat.color = Color(1.0, 0.6, 0.1)
				else:
					mat.color = Color(0.9, 0.9, 0.9)


func _coletar_rodas() -> void:
	# Procura as rodas dentro do nó Visual (a malha completa do kart).
	var frente := {"RodaFE": true, "RodaFD": true, "AroFE": true, "AroFD": true,
		"RodaTE": false, "RodaTD": false, "AroTE": false, "AroTD": false}
	for nome in frente.keys():
		var r := get_node_or_null("Visual/" + nome) as Node3D
		if r:
			_rodas.append(r)
			_rodas_base.append(r.transform.basis)
			_rodas_frente.append(frente[nome])
