extends Area3D

# ============================================================
#  CAIXA DE ITEM (turbo)
#  Fica girando e brilhando. Quando o kart passa por cima,
#  dá um TURBO, solta um flash de partículas, some, e reaparece
#  depois de alguns segundos.
# ============================================================

@export var reaparece: float = 4.0
@export var duracao_boost: float = 2.0

@onready var malha: Node3D = get_node_or_null("Malha")
@onready var som: Node = get_node_or_null("Som")
@onready var brilho: GPUParticles3D = get_node_or_null("Brilho")

var ativo: bool = true


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _process(delta: float) -> void:
	# Gira e flutua de leve para "chamar atenção".
	if malha:
		malha.rotate_y(delta * 2.5)


func _ao_entrar(corpo: Node) -> void:
	# Só funciona se o que entrou souber receber turbo (o kart do jogador).
	if ativo and corpo.has_method("aplicar_boost"):
		corpo.aplicar_boost(duracao_boost)
		ativo = false
		if malha:
			malha.visible = false
		if som:
			som.play()
		if brilho:
			brilho.restart()        # dispara o flash de partículas (one-shot)
			brilho.emitting = true
		# Espera e reaparece.
		await get_tree().create_timer(reaparece).timeout
		ativo = true
		if malha:
			malha.visible = true
