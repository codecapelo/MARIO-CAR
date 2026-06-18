extends Camera3D

# ============================================================
#  CÂMERA PERSEGUIDORA — segue o kart por trás, de forma suave.
#  É filha do Kart, mas usa coordenadas globais (top_level),
#  então ela "persegue" o kart em vez de ficar grudada nele.
# ============================================================

# Quão atrás do kart a câmera fica (metros).
@export var distancia: float = 6.5

# Quão acima do kart a câmera fica (metros).
@export var altura: float = 2.8

# Suavidade do movimento (maior = acompanha mais rápido / mais "duro").
@export var suavidade: float = 7.0

# A câmera mira um pouco acima do kart (para ver melhor a pista).
@export var olhar_acima: float = 1.2

var alvo: Node3D


func _ready() -> void:
	# O alvo é o pai, ou seja, o Kart.
	alvo = get_parent() as Node3D
	# Desgruda do pai: a partir de agora a câmera usa posição global própria.
	top_level = true


func _physics_process(delta: float) -> void:
	if alvo == null:
		return

	# "Atrás" do kart é o eixo +Z dele (porque a frente é -Z).
	var atras := alvo.global_transform.basis.z

	# Posição que QUEREMOS: atrás e acima do kart.
	var pos_desejada := alvo.global_position + atras * distancia + Vector3.UP * altura

	# Vamos suavemente da posição atual até a desejada.
	# (1 - exp(-k*delta)) deixa a suavização igual em qualquer FPS.
	var t := 1.0 - exp(-suavidade * delta)
	global_position = global_position.lerp(pos_desejada, t)

	# Sempre olhar para o kart (um pouco acima do chão).
	look_at(alvo.global_position + Vector3.UP * olhar_acima, Vector3.UP)
