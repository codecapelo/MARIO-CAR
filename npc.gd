extends Node3D

# ============================================================
#  IA SIMPLES DO ADVERSÁRIO
#  Segue a curva da pista (TrackPath) a uma velocidade fixa.
#  IMPORTANTE: só começa a andar quando a largada libera
#  (quando o kart do jogador deixa de estar "travado").
# ============================================================

@export var velocidade: float = 18.0       # metros por segundo
@export var offset_lateral: float = 4.5     # quanto fica para o lado da pista

var curva: Curve3D
var kart: Node                              # o kart do jogador (para saber a largada)
var dist: float = 0.0                       # distância já percorrida na pista


func _ready() -> void:
	var path := get_node_or_null("../TrackPath") as Path3D
	if path:
		curva = path.curve
	kart = get_node_or_null("../Kart")


func _physics_process(delta: float) -> void:
	if curva == null:
		return
	var comprimento := curva.get_baked_length()
	if comprimento <= 0.0:
		return

	# Só avança se a corrida já começou (kart do jogador destravado).
	var largou: bool = (kart == null) or (not kart.travado)
	if largou:
		dist = fmod(dist + velocidade * delta, comprimento)

	# Posiciona e orienta o kart na pista (mesmo parado, fica na linha).
	var pos := curva.sample_baked(dist)
	var pos_frente := curva.sample_baked(fmod(dist + 1.5, comprimento))
	var frente := (pos_frente - pos).normalized()
	var lado := Vector3.UP.cross(frente).normalized()
	global_position = pos + lado * offset_lateral
	look_at(global_position + frente, Vector3.UP)
