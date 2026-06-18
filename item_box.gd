extends Area3D

# ============================================================
#  CAIXA DE ITEM (turbo)
#  Fica girando e brilhando. Quando o kart passa por cima,
#  dá um TURBO, some, e reaparece depois de alguns segundos.
# ============================================================

@export var reaparece: float = 4.0
@export var duracao_boost: float = 2.0

@onready var malha: Node3D = get_node_or_null("Malha")
@onready var som: AudioStreamPlayer = get_node_or_null("Som")

var ativo: bool = true


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _process(delta: float) -> void:
	# Gira a caixa para ela "chamar atenção".
	rotate_y(delta * 2.5)


func _ao_entrar(corpo: Node) -> void:
	# Só funciona se o que entrou souber receber turbo (o kart do jogador).
	if ativo and corpo.has_method("aplicar_boost"):
		corpo.aplicar_boost(duracao_boost)
		ativo = false
		if malha:
			malha.visible = false
		if som:
			som.play()
		# Espera e reaparece.
		await get_tree().create_timer(reaparece).timeout
		ativo = true
		if malha:
			malha.visible = true
