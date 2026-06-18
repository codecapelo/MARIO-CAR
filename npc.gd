extends Node3D

# ============================================================
#  IA DO RIVAL — segue a curva da pista (TrackPath) com "elástico"
#  (rubber-banding): se está muito atrás do jogador, acelera; se está
#  muito na frente, alivia — assim a corrida fica sempre disputada.
#
#  O rival só anda depois da largada (Jogo.estado == CORRENDO).
# ============================================================

@export var velocidade_base: float = 18.0   # metros por segundo (ritmo natural)
@export var offset_lateral: float = 4.5      # quanto fica para o lado da pista
@export var ganho_borracha: float = 0.06     # quão forte reage à distância
@export var vel_min: float = 13.0            # nunca anda mais devagar que isso
@export var vel_max: float = 25.0            # nem mais rápido que isso
@export var indice: int = 1                  # número do rival (1, 2, 3...)
@export var cor: Color = Color(0.16, 0.62, 0.2, 1)  # cor do corpo do rival

var curva: Curve3D
var no_path: Node3D
var pista: Node                              # o gerente da corrida (grupo "pista")
var dist: float = 0.0                        # distância já percorrida na curva

@onready var motor: AudioStreamPlayer3D = get_node_or_null("MotorNPC")
var _rodas: Array = []
var _rodas_base: Array = []   # basis original de cada roda (para girar certo)


func _ready() -> void:
	add_to_group("corredores")
	add_to_group("rivais")

	no_path = get_node_or_null("../TrackPath") as Node3D
	if no_path:
		curva = (no_path as Path3D).curve
	else:
		push_warning("NPC '%s': TrackPath não encontrado — o rival vai ficar parado." % name)

	pista = get_tree().get_first_node_in_group("pista")

	_pintar_corpo()
	_coletar_rodas()

	if motor:
		motor.play()


func _physics_process(delta: float) -> void:
	if curva == null:
		return
	var comprimento := curva.get_baked_length()
	if comprimento <= 0.0:
		return

	# Só avança depois da largada.
	var correndo: bool = (Jogo.estado == Jogo.Estado.CORRENDO)
	var vel := velocidade_base
	if correndo:
		vel = _velocidade_com_elastico()
		dist = fmod(dist + vel * delta, comprimento)
		_girar_rodas(vel, delta)

	_posicionar()

	# Motor espacial: um zumbido que varia um pouco com a velocidade.
	if motor:
		motor.pitch_scale = 0.85 + (vel / vel_max) * 0.5


# Calcula a velocidade do rival reagindo à distância para o jogador.
func _velocidade_com_elastico() -> float:
	# O gerente (grupo "pista") só entra no grupo depois do _ready do pai,
	# então pode estar nulo no início: buscamos de novo até encontrar.
	if pista == null:
		pista = get_tree().get_first_node_in_group("pista")
	if pista == null or not pista.has_method("progresso_de") or not pista.has_method("progresso_jogador"):
		return velocidade_base
	var meu: float = pista.progresso_de(self)
	var jog: float = pista.progresso_jogador()
	var diferenca := jog - meu          # positivo = estou atrás do jogador
	return clampf(velocidade_base + diferenca * ganho_borracha, vel_min, vel_max)


# Coloca e orienta o rival na pista (mesmo parado, fica na linha de largada).
func _posicionar() -> void:
	var comprimento := curva.get_baked_length()
	var pos := curva.sample_baked(dist)
	var pos_frente := curva.sample_baked(fmod(dist + 1.5, comprimento))
	var frente := (pos_frente - pos).normalized()
	if frente.length() < 0.01:
		frente = -global_transform.basis.z
	var lado := Vector3.UP.cross(frente).normalized()
	global_position = pos + lado * offset_lateral
	look_at(global_position + frente, Vector3.UP)


# Gira as rodas proporcional à velocidade (puro visual).
func _girar_rodas(vel: float, delta: float) -> void:
	if _rodas.is_empty():
		return
	var ang := (vel / 0.42) * delta   # 0.42 = raio da roda; ω = v / r
	for i in _rodas.size():
		var r := _rodas[i] as Node3D
		if r:
			# Gira em torno do eixo X local do kart (o eixo das rodas).
			var bb: Basis = Basis(Vector3.RIGHT, _giro_acumulado(i, ang)) * _rodas_base[i]
			r.transform.basis = bb


var _giros: Array = []
func _giro_acumulado(i: int, passo: float) -> float:
	while _giros.size() <= i:
		_giros.append(0.0)
	_giros[i] += passo
	return float(_giros[i])


func _coletar_rodas() -> void:
	for nome in ["RodaFE", "RodaFD", "RodaTE", "RodaTD", "AroFE", "AroFD", "AroTE", "AroTD"]:
		var r := get_node_or_null("Visual/" + nome) as Node3D
		if r:
			_rodas.append(r)
			_rodas_base.append(r.transform.basis)


# Dá ao rival uma cor própria (cada rival fica de um tom diferente).
func _pintar_corpo() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.metallic = 0.35
	mat.roughness = 0.35
	for nome in ["Chassi", "Corpo", "AsaTras", "PodE", "PodD"]:
		var m := get_node_or_null("Visual/" + nome) as MeshInstance3D
		if m:
			m.material_override = mat
