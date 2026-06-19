extends Area3D

# ============================================================
#  CAIXA DE ITEM "?"
#  Fica girando e mudando de cor. Quando o JOGADOR passa por cima,
#  ela sorteia um item (a chance depende da posição na corrida —
#  quem está atrás ganha itens melhores), guarda no kart, some, e
#  reaparece depois de alguns segundos.
#
#  Os rivais NÃO consomem as caixas: eles têm o próprio sistema de
#  itens (por tempo) no npc.gd, para as caixas serem sempre do jogador.
# ============================================================

@export var reaparece: float = 4.0

@onready var malha: MeshInstance3D = get_node_or_null("Malha")
@onready var som: Node = get_node_or_null("Som")
@onready var brilho: GPUParticles3D = get_node_or_null("Brilho")

var ativo: bool = true
var _mat: StandardMaterial3D
var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_ao_entrar)
	# Material próprio (a cor muda no _process para o efeito "?").
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 2.2
	_mat.metallic = 0.2
	_mat.roughness = 0.3
	if malha:
		malha.material_override = _mat


func _process(delta: float) -> void:
	if malha:
		malha.rotate_y(delta * 2.5)
	# Cor "arco-íris" girando devagar — só quando a caixa está disponível.
	if _mat:
		if ativo:
			_t = fmod(_t + delta * 0.35, 1.0)
			var cor := Color.from_hsv(_t, 0.8, 1.0)
			_mat.albedo_color = cor
			_mat.emission = cor
		else:
			_mat.albedo_color = Color(0.2, 0.2, 0.2)
			_mat.emission = Color(0.05, 0.05, 0.05)


func _ao_entrar(corpo: Node) -> void:
	if not ativo:
		return
	# Só o jogador pega das caixas (rivais têm itens próprios).
	if not corpo.is_in_group("jogador") or not corpo.has_method("pegar_item"):
		return
	# Se o jogador já está segurando um item, a caixa não é consumida.
	if corpo.has_method("pode_pegar_item") and not corpo.pode_pegar_item():
		return

	# Sorteia o item conforme a posição do jogador na corrida.
	var tipo := "turbo"
	var pista := get_tree().get_first_node_in_group("pista")
	if pista and pista.has_method("sortear_item_para"):
		tipo = pista.sortear_item_para(corpo)
	corpo.pegar_item(tipo)

	ativo = false
	if malha:
		malha.visible = false
	if som:
		som.play()
	if brilho:
		brilho.restart()
		brilho.emitting = true
	await get_tree().create_timer(reaparece).timeout
	ativo = true
	if malha:
		malha.visible = true
