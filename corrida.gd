extends Area3D

# ============================================================
#  CRONÔMETRO DE VOLTA + CONTADOR DE VOLTAS
#  Este nó é uma "zona invisível" (Area3D) na linha de chegada.
#  Quando o kart entra na zona, fechamos uma volta.
# ============================================================

# Caminho até o texto na tela (Label dentro do HUD).
@export var label_path: NodePath

var label: Label
var tempo_volta: float = 0.0     # tempo da volta atual (segundos)
var melhor: float = -1.0         # melhor volta (-1 = ainda não fez)
var voltas: int = 0
# 'armado' evita contar uma volta na largada: só conta depois que o
# kart SAIU da linha pelo menos uma vez (deu a volta no circuito).
var armado: bool = false


func _ready() -> void:
	label = get_node_or_null(label_path) as Label
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	_atualizar_texto()


func _physics_process(delta: float) -> void:
	tempo_volta += delta
	_atualizar_texto()


func _ao_sair(corpo: Node) -> void:
	# O kart saiu da linha: começa a contar a volta e arma o fechamento.
	if corpo.name == "Kart":
		armado = true
		tempo_volta = 0.0


func _ao_entrar(corpo: Node) -> void:
	if corpo.name == "Kart" and armado:
		voltas += 1
		if melhor < 0.0 or tempo_volta < melhor:
			melhor = tempo_volta
		tempo_volta = 0.0
		armado = false


func _atualizar_texto() -> void:
	if label == null:
		return
	var txt := "Volta: %d\nTempo: %.2f s" % [voltas, tempo_volta]
	if melhor >= 0.0:
		txt += "\nMelhor: %.2f s" % melhor
	label.text = txt
