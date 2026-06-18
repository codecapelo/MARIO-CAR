extends Area3D

# ============================================================
#  CAIXA DE ITEM (turbo)
#  Fica girando e brilhando. Quando o kart passa por cima,
#  dá um TURBO, solta um flash de partículas, some, e reaparece
#  depois de alguns segundos.
# ============================================================

@export var reaparece: float = 4.0
@export var duracao_boost: float = 2.0
@export var tipo: String = "turbo"   # "turbo", "estrela" ou "raio"

@onready var malha: Node3D = get_node_or_null("Malha")
@onready var som: Node = get_node_or_null("Som")
@onready var brilho: GPUParticles3D = get_node_or_null("Brilho")

var ativo: bool = true


func _ready() -> void:
	body_entered.connect(_ao_entrar)
	_pintar()


# Cada tipo de item tem uma cor própria, para o jogador reconhecer de longe.
func _pintar() -> void:
	var cor := Color(1.0, 0.55, 0.0)        # turbo = laranja
	match tipo:
		"estrela":
			cor = Color(1.0, 0.85, 0.1)     # estrela = dourado
		"raio":
			cor = Color(0.35, 0.6, 1.0)     # raio = azul
	var m := get_node_or_null("Malha") as MeshInstance3D
	if m:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor
		mat.emission_enabled = true
		mat.emission = cor
		mat.emission_energy_multiplier = 2.2
		mat.metallic = 0.2
		mat.roughness = 0.3
		m.material_override = mat


func _process(delta: float) -> void:
	# Gira e flutua de leve para "chamar atenção".
	if malha:
		malha.rotate_y(delta * 2.5)


func _ao_entrar(corpo: Node) -> void:
	# Só funciona se o que entrou souber receber turbo (o kart do jogador).
	if ativo and corpo.has_method("pegar_item"):
		corpo.pegar_item(tipo)
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
