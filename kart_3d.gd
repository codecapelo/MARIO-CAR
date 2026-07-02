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

# --- vácuo (slipstream) e manobra ---
@export var vacuo_dist: float = 13.0         # distância p/ "pegar o vácuo" de um rival
@export var vacuo_tempo: float = 1.1         # segundos no vácuo até ganhar o empurrão

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
var _resgate_timer: float = 0.0  # tempo segurando o botão de voltar à pista
var driftando: bool = false
var drift_sentido: float = 0.0   # -1 esquerda, +1 direita (travado ao iniciar)
var drift_carga: float = 0.0     # segundos acumulados derrapando

# --- itens (segura um item e usa quando quiser, igual ao Mario Kart) ---
var item_guardado: String = ""   # "" = nenhum; senão "turbo"/"estrela"/"raio"/"banana"/"casco"
var item_roleta: float = 0.0     # tempo restante da "roleta" (HUD gira os nomes)
var _item_pendente: String = ""  # o item já sorteado, revelado quando a roleta para
var _rodopio_timer: float = 0.0  # tempo rodopiando (atingido por banana/casco)
var _rodopiando: bool = false
var _raio_timer: float = 0.0     # tempo lento por causa do raio
var _col_timer: float = 0.0      # respiro entre reações de colisão

# As cenas dos itens já carregadas na memória (preload): soltar uma banana
# no meio da corrida não precisa ler o disco (evita engasgo no 1º uso).
const CENA_BANANA: PackedScene = preload("res://banana.tscn")
const CENA_CASCO: PackedScene = preload("res://casco.tscn")

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
var _yaw_drift: float = 0.0      # giro extra do corpo (Visual) durante o drift
var _vacuo_timer: float = 0.0    # tempo acumulado "colado" atrás de um rival
var _tempo_ar: float = 0.0       # tempo no ar (para a manobra na rampa)
var _truque: bool = false        # fez a manobra? (dá turbo ao pousar)
var _tw_truque: Tween = null     # animação do giro (cancelada ao pousar)
var _tw_pulinho: Tween = null    # animação do pulinho do drift
var _respawn_timer: float = 0.0  # penalidade parado depois de cair no mar

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
	_aplicar_cor()                 # pinta o kart com a cor escolhida no menu
	if motor:
		motor.play()               # o loop agora vem da importação do .wav


# Pinta o corpo do kart com a cor que o jogador escolheu nas opções.
func _aplicar_cor() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Jogo.cor_kart()
	mat.metallic = 0.35
	mat.roughness = 0.35
	for nome in ["Chassi", "Corpo", "AsaTras", "PodE", "PodD"]:
		var m := get_node_or_null("Visual/" + nome) as MeshInstance3D
		if m:
			m.material_override = mat


func _teto() -> float:
	var teto := velocidade_maxima
	if boost_timer > 0.0:
		teto += boost_extra
	if estrela_timer > 0.0:
		teto += _estrela_extra
	if _raio_timer > 0.0:
		teto *= 0.5            # atingido pelo raio: anda pela metade
	return teto


func _physics_process(delta: float) -> void:
	if travado:
		velocity = -global_transform.basis.y * 2.0   # assenta no chão
		move_and_slide()
		# Cruzou a linha de chegada derrapando/turbinado? O gerente trava o
		# kart POR FORA — precisamos encerrar o que ficou "aceso", senão o
		# som do drift, as faíscas e o motor a pleno RPM vazam por ~2 s
		# sobre a tela de resultado.
		if driftando:
			_cancelar_drift()
		velocidade_atual = move_toward(velocidade_atual, 0.0, atrito * delta)
		if boost_timer > 0.0:
			boost_timer -= delta
		_atualizar_roleta(delta)
		_atualizar_vfx()
		_atualizar_motor(delta)
		# A penalidade do respawn conta AQUI (no physics) de propósito: com o
		# jogo pausado o physics não roda, então pausar não "come" o timer —
		# e o kart nunca fica travado para sempre.
		if _respawn_timer > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0 and Jogo.estado == Jogo.Estado.CORRENDO:
				travado = false
		# Mesmo travado (fim de corrida), cair no mar reposiciona o kart —
		# senão ele afundaria na água na frente da câmera.
		_checar_queda(delta)
		return

	if _checar_resgate(delta):
		return

	_atualizar_roleta(delta)

	# Usar o item guardado (tecla E / botão L1).
	if Input.is_action_just_pressed("usar_item"):
		_usar_item()

	# Rodopio (depois de levar banana/casco): perde o controle por um instante.
	_rodopiando = _rodopio_timer > 0.0
	if _rodopiando:
		_rodopio_timer -= delta
	if _raio_timer > 0.0:
		_raio_timer -= delta
	if _col_timer > 0.0:
		_col_timer -= delta

	_detectar_chao()
	_acelerar_ou_frear(delta)
	_atualizar_drift(delta)
	_atualizar_vacuo(delta)
	_virar(delta)
	_mover(delta)
	_processar_colisoes()
	if boost_timer > 0.0:
		boost_timer -= delta
	if estrela_timer > 0.0:
		estrela_timer -= delta
		boost_timer = maxf(boost_timer, 0.2)   # mantém o turbo aceso durante a estrela
		if estrela_timer <= 0.0:
			_estrela_extra = 0.0
	_atualizar_motor(delta)
	_atualizar_visual(delta)
	_atualizar_vfx()
	_checar_queda(delta)


# Roleta de item: os nomes giram no HUD por um instante e só então o item
# sorteado "cai na mão" (igual à caixinha do Mario Kart). Continua andando
# mesmo com o kart travado, para não congelar a roleta na tela de resultado.
func _atualizar_roleta(delta: float) -> void:
	if item_roleta > 0.0:
		item_roleta -= delta
		if item_roleta <= 0.0:
			item_guardado = _item_pendente
			_item_pendente = ""


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
	# Rodopiando: o jogador não controla; a velocidade cai sozinha.
	if _rodopiando:
		_acelerando = false
		velocidade_atual = move_toward(velocidade_atual, 0.0, atrito * 2.0 * delta)
		return
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
	# Rodopiando: gira rápido no lugar (pião), ignorando o comando.
	if _rodopiando:
		rotate(global_transform.basis.y.normalized(), TAU * 1.4 * delta)
		return
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
	if _rodopiando:
		if driftando:
			_cancelar_drift()   # levar uma banana no meio do drift NÃO premia
		return
	if not no_chao:
		return
	var quer := Input.is_action_pressed("drift")
	var sentido := Input.get_axis("virar_esquerda", "virar_direita")
	if quer and not driftando and velocidade_atual > drift_min_velocidade and absf(sentido) > 0.2:
		driftando = true
		drift_sentido = signf(sentido)     # trava o lado da derrapagem
		drift_carga = 0.0
		_pulinho_drift()                   # o "hop" clássico ao entrar no drift
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
	_cancelar_drift()


# Encerra o drift SEM recompensa (usado quando o kart é atingido: a carga
# acumulada se perde — rodopiar não pode virar prêmio).
func _cancelar_drift() -> void:
	driftando = false
	drift_carga = 0.0
	drift_sentido = 0.0
	if som_drift:
		som_drift.stop()


# Pulinho ao iniciar o drift (só o Visual sobe e desce — a física não muda).
func _pulinho_drift() -> void:
	if visual == null:
		return
	# Reentrar no drift antes do pulinho anterior acabar: mata o tween velho,
	# senão os dois disputam position:y e o kart treme.
	if _tw_pulinho and _tw_pulinho.is_valid():
		_tw_pulinho.kill()
	_tw_pulinho = create_tween()
	_tw_pulinho.tween_property(visual, "position:y", 0.32, 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw_pulinho.tween_property(visual, "position:y", 0.0, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# VÁCUO (slipstream): andar "colado" atrás de outro corredor por um tempo
# dá um empurrão de velocidade — como nos Mario Kart mais novos. O ar que o
# rival "abre" na frente deixa o seu kart correr com menos resistência.
func _atualizar_vacuo(delta: float) -> void:
	if not no_chao or driftando or _rodopiando or boost_timer > 0.0 \
			or velocidade_atual < velocidade_maxima * 0.6:
		_vacuo_timer = 0.0
		return
	var frente := -global_transform.basis.z
	var atras_de_alguem := false
	for r in get_tree().get_nodes_in_group("corredores"):
		if r == self:
			continue
		var outro := r as Node3D
		if outro == null:
			continue
		var rel: Vector3 = outro.global_position - global_position
		var dist := rel.length()
		# perto E quase exatamente na direção da frente (cone estreito)
		if dist > 1.0 and dist < vacuo_dist and rel.normalized().dot(frente) > 0.9:
			atras_de_alguem = true
			break
	if atras_de_alguem:
		_vacuo_timer += delta
		if _vacuo_timer >= vacuo_tempo:
			_vacuo_timer = 0.0
			aplicar_boost(0.9)
	else:
		# perdeu a posição: o vácuo esvazia rápido, mas não zera de estalo
		_vacuo_timer = maxf(0.0, _vacuo_timer - delta * 2.0)


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
		_tempo_ar += delta
		# MANOBRA: apertar o drift no ar (depois de um voo de verdade — um
		# pulinho de quina não vale) dá um giro e um turbo ao pousar (MK7).
		if Input.is_action_just_pressed("drift") and _tempo_ar > 0.25 and not _truque:
			_truque = true
			if visual:
				_tw_truque = create_tween()
				_tw_truque.tween_property(visual, "rotation:x", TAU, 0.45).from(0.0)
				_tw_truque.tween_callback(func(): visual.rotation.x = 0.0)

	move_and_slide()


func _ao_pousar() -> void:
	# Pousar muito de bico custa velocidade; sempre dá um baque na câmera.
	var alinhamento := 1.0
	if velocity.length() > 0.1:
		alinhamento = (-global_transform.basis.z).dot(velocity.normalized())
		if alinhamento < 0.6:
			velocidade_atual *= 0.7
	# Manobra só recompensa se o pouso foi LIMPO — pousar de bico perde o
	# truque (e ainda leva a penalidade acima), como no Mario Kart.
	if _truque and alinhamento >= 0.6:
		aplicar_boost(0.85)
	_truque = false
	_tempo_ar = 0.0
	# O pouso corta o giro na hora (senão o kart continuaria rodando no chão).
	if _tw_truque and _tw_truque.is_valid():
		_tw_truque.kill()
	if visual:
		visual.rotation.x = 0.0
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
	_cancelar_estado_de_voo()   # cair no mar NÃO pode render turbo de manobra
	if som_drift:
		som_drift.stop()
	global_transform = _ultimo_seguro
	# Teleporte: avisa a interpolação de física para não "borrar" o salto.
	reset_physics_interpolation()
	_tremer_camera(0.15)
	# pequena penalidade: ~0.8s parado antes de voltar a correr
	# (o destravamento acontece no _physics_process, via _respawn_timer)
	travado = true
	_respawn_timer = 0.8


# Zera tudo que dizia respeito a estar "voando" (manobra, tempo de ar, vácuo).
# Usado nos teleportes: respawn e resgate para a pista.
func _cancelar_estado_de_voo() -> void:
	_truque = false
	_tempo_ar = 0.0
	_vacuo_timer = 0.0
	_estava_no_ar = false
	if _tw_truque and _tw_truque.is_valid():
		_tw_truque.kill()
	if visual:
		visual.rotation.x = 0.0


# Segurar o botão "voltar_pista" por um instante reposiciona o kart na pista
# (no ponto mais próximo da curva, virado para frente). Resgata quando o kart
# fica preso fora da pista sem ter caído no mar.
func _checar_resgate(delta: float) -> bool:
	if Input.is_action_pressed("voltar_pista"):
		_resgate_timer += delta
		if _resgate_timer >= 0.35:
			_voltar_para_pista()
			_resgate_timer = 0.0
			return true
	else:
		_resgate_timer = 0.0
	return false


func _voltar_para_pista() -> void:
	velocity = Vector3.ZERO
	velocidade_atual = 0.0
	boost_timer = 0.0
	estrela_timer = 0.0
	_estrela_extra = 0.0
	driftando = false
	drift_carga = 0.0
	_cancelar_estado_de_voo()
	if som_drift:
		som_drift.stop()
	var path := get_node_or_null("../TrackPath") as Path3D
	if path and path.curve and path.curve.get_baked_length() > 0.0:
		var curva := path.curve
		var comp := curva.get_baked_length()
		var off := curva.get_closest_offset(path.to_local(global_position))
		var pos: Vector3 = path.to_global(curva.sample_baked(off))
		var prox: Vector3 = path.to_global(curva.sample_baked(fmod(off + 2.0, comp)))
		var frente := prox - pos
		frente.y = 0.0
		global_position = pos + Vector3.UP * 0.8
		up_direction = Vector3.UP
		if frente.length() > 0.01:
			look_at(global_position + frente.normalized(), Vector3.UP)
	else:
		global_transform = _ultimo_seguro
	# Teleporte: avisa a interpolação de física para não "borrar" o salto.
	reset_physics_interpolation()
	_tremer_camera(0.12)


func aplicar_boost(duracao: float = 2.0) -> void:
	boost_timer = maxf(boost_timer, duracao)
	# empurra para perto do novo teto sem cravar (entrada suave)
	velocidade_atual = maxf(velocidade_atual, velocidade_maxima + boost_extra * 0.6)
	if som_boost:
		som_boost.play()
	_tremer_camera(0.3)


# Chamado pela caixa de item: GUARDA o item, mas primeiro roda a ROLETA
# (o HUD mostra os nomes girando por ~1 segundo antes de revelar).
func pegar_item(tipo: String) -> void:
	if item_guardado == "" and item_roleta <= 0.0:
		_item_pendente = tipo
		item_roleta = 1.1


# A caixa pergunta isto antes de se entregar: só pega se a mão estiver livre
# (e se a roleta não estiver girando).
func pode_pegar_item() -> bool:
	return item_guardado == "" and item_roleta <= 0.0


# Usa o item guardado (tecla E / botão). Cada tipo faz uma coisa.
func _usar_item() -> void:
	if item_guardado == "":
		return
	var t := item_guardado
	item_guardado = ""
	match t:
		"estrela":
			ativar_estrela(6.0)
		"raio":
			disparar_raio()
		"banana":
			_soltar_banana()
		"casco":
			_disparar_casco()
		_:
			aplicar_boost(2.0)   # turbo comum


# Solta uma banana logo atrás do kart.
func _soltar_banana() -> void:
	var b = CENA_BANANA.instantiate()   # sem tipo fixo: vamos acessar .dono dinamicamente
	b.dono = self
	var frente := -global_transform.basis.z
	frente.y = 0.0
	get_tree().current_scene.add_child(b)
	b.global_position = global_position - frente.normalized() * 2.6 + Vector3.UP * 0.1


# Dispara um casco reto para frente.
func _disparar_casco() -> void:
	var c = CENA_CASCO.instantiate()   # sem tipo fixo: vamos acessar .dono/.direcao
	var frente := -global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	c.dono = self
	c.direcao = frente
	get_tree().current_scene.add_child(c)
	c.global_position = global_position + frente * 2.6 + Vector3.UP * 0.4
	if som_boost:
		som_boost.play()


# Faz o kart rodopiar (perde o controle por um instante). A estrela protege.
func rodopiar(dur: float = 0.9) -> void:
	if estrela_timer > 0.0:
		return
	_rodopio_timer = maxf(_rodopio_timer, dur)
	_tremer_camera(0.25)


# Atingido pelo raio: fica lento por um tempo (a estrela protege).
func levar_raio(dur: float) -> void:
	if estrela_timer > 0.0:
		return
	_raio_timer = maxf(_raio_timer, dur)
	velocidade_atual = minf(velocidade_atual, velocidade_maxima * 0.5)
	_tremer_camera(0.2)


# Reage a bater em outro kart: com estrela, derruba o rival; sem, perde
# um pouco de velocidade. O respiro (_col_timer) evita repetir todo frame.
func _processar_colisoes() -> void:
	if _col_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var outro = c.get_collider()   # Object: acessamos métodos de Node dinamicamente
		if outro and outro != self and outro.is_in_group("corredores"):
			if estrela_timer > 0.0:
				if outro.has_method("rodopiar"):
					outro.rodopiar(0.8)
			else:
				velocidade_atual *= 0.9
			_tremer_camera(0.12)
			_col_timer = 0.25
			return


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
func _atualizar_motor(delta: float) -> void:
	if motor == null:
		return
	# rpm normalizado pelo TETO atual (assim o turbo não estoura o pitch)
	var rpm := clampf(absf(velocidade_atual) / _teto(), 0.0, 1.0)
	var alvo := 0.85 + rpm * 0.9 + (0.12 if _acelerando else 0.0)
	# suavização por delta (1 - exp): o motor responde igual em qualquer FPS
	_pitch_motor = lerpf(_pitch_motor, alvo, 1.0 - exp(-11.0 * delta))
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

		# 3) no drift o corpo aponta PARA DENTRO da curva mais do que o kart
		#    anda (o "de lado" clássico do Mario Kart) — de novo, só visual.
		var yaw_alvo := -drift_sentido * deg_to_rad(13.0) if driftando else 0.0
		_yaw_drift = lerpf(_yaw_drift, yaw_alvo, clampf(9.0 * delta, 0.0, 1.0))
		visual.rotation.y = _yaw_drift


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
			# cores como no Mario Kart: branco (carregando) -> AZUL (turbo
			# pequeno pronto) -> LARANJA (turbo grande pronto)
			var mat := poeira.process_material as ParticleProcessMaterial
			if mat:
				if drift_carga >= carga_turbo2:
					mat.color = Color(1.0, 0.45, 0.1)
				elif drift_carga >= carga_turbo1:
					mat.color = Color(0.35, 0.65, 1.0)
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
