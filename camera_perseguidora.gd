extends Camera3D

# ============================================================
#  CÂMERA PERSEGUIDORA — segue o kart por trás, de forma suave,
#  e "sente" a velocidade: abre o campo de visão (FOV) quando o
#  kart corre, dá um empurrão extra no turbo e treme de leve.
#  É filha do Kart, mas usa coordenadas globais (top_level),
#  então ela "persegue" o kart em vez de ficar grudada nele.
# ============================================================

# Quão atrás / acima do kart a câmera fica (metros).
@export var distancia: float = 6.5
@export var altura: float = 2.8
# Suavidade do movimento (maior = acompanha mais rápido).
@export var suavidade: float = 7.0
# A câmera mira um pouco acima do kart (para ver melhor a pista).
@export var olhar_acima: float = 1.2

# --- sensação de velocidade ---
@export var fov_base: float = 72.0       # campo de visão parado/devagar
@export var fov_max: float = 88.0        # campo de visão em alta velocidade
@export var fov_extra_boost: float = 7.0 # abertura extra durante o turbo
@export var vel_fov: float = 5.0         # rapidez da transição do FOV
@export var shake_boost: float = 0.10    # tremor contínuo durante o turbo (m)
@export var shake_decay: float = 7.0     # quão rápido um tranco decai

var alvo: Node3D
var _shake: float = 0.0   # tranco momentâneo (pousos, batidas, pegar turbo)


func _ready() -> void:
	# O alvo é o pai, ou seja, o Kart.
	alvo = get_parent() as Node3D
	# Desgruda do pai: a partir de agora a câmera usa posição global própria.
	top_level = true
	fov = fov_base


func _physics_process(delta: float) -> void:
	if alvo == null:
		return

	# "Atrás" do kart é o eixo +Z dele (porque a frente é -Z).
	var atras := alvo.global_transform.basis.z
	var pos_desejada := alvo.global_position + atras * distancia + Vector3.UP * altura

	# Suavização independente de FPS: (1 - exp(-k*delta)).
	var t := 1.0 - exp(-suavidade * delta)
	global_position = global_position.lerp(pos_desejada, t)

	# --- FOV pela velocidade (o olho mede velocidade pela abertura) ---
	var frac := 0.0
	var em_boost := false
	if "velocidade_atual" in alvo and "velocidade_maxima" in alvo:
		frac = clampf(absf(alvo.velocidade_atual) / alvo.velocidade_maxima, 0.0, 1.0)
	if "boost_timer" in alvo:
		em_boost = alvo.boost_timer > 0.0
	var fov_alvo := lerpf(fov_base, fov_max, frac)
	if em_boost:
		fov_alvo += fov_extra_boost
	fov = lerpf(fov, fov_alvo, 1.0 - exp(-vel_fov * delta))

	# --- mira, com tremor ---
	var olhar := alvo.global_position + Vector3.UP * olhar_acima
	# tremor contínuo enquanto o turbo está ativo
	var tremor := _shake
	if em_boost:
		tremor = maxf(tremor, shake_boost)
	if tremor > 0.0001:
		olhar += Vector3(randf_range(-tremor, tremor), randf_range(-tremor, tremor), 0.0)
		_shake = move_toward(_shake, 0.0, shake_decay * delta)

	look_at(olhar, Vector3.UP)


# Dá um tranco momentâneo na câmera (chamado em pousos, batidas, turbo).
func tremer(intensidade: float = 0.25) -> void:
	_shake = maxf(_shake, intensidade)
