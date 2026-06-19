extends Node3D

# ============================================================
#  GERENTE DA CORRIDA (anexado ao nó raiz "Main")
#
#  É o "juiz" da corrida. Faz:
#   - a contagem de largada 3-2-1-VAI (avisando o HUD por sinais);
#   - a contagem de VOLTAS de TODOS os corredores, medindo o
#     progresso de cada um ao longo da Curve3D da pista (robusto:
#     não depende do nome do nó nem de Area3D);
#   - a POSIÇÃO em tempo real (1º, 2º, ...);
#   - o FIM da corrida quando o jogador completa as voltas.
# ============================================================

@export var path_node: NodePath = NodePath("TrackPath")

# Sinais avisam o HUD sem o gerente precisar conhecê-lo.
signal contagem(numero: int)            # 3, 2, 1
signal largada()                        # "VAI!"
signal volta_completada(no: Node, voltas: int)
signal corrida_terminou()

var _curva: Curve3D
var _no_path: Node3D
var _comprimento: float = 0.0

# Um "corredor" é um dicionário com os dados de cada kart.
var _corredores: Array = []
var _jogador: Node3D

var _tempo_corrida: float = 0.0
var _fase_contagem: float = 3.99
var _ultimo_n: int = 99
var _terminou: bool = false
var _contramao: bool = false             # o jogador está indo no sentido errado?

# tempos de volta do jogador
var _inicio_volta: float = 0.0
var _melhor_volta: float = -1.0
var _tempos_voltas: Array[float] = []


func _ready() -> void:
	add_to_group("pista")
	_no_path = get_node_or_null(path_node) as Node3D
	if _no_path:
		_curva = (_no_path as Path3D).curve
		_comprimento = _curva.get_baked_length()
	else:
		push_error("pista: TrackPath não encontrado em '%s'." % path_node)

	# Registra todos os corredores (jogador + rivais) que já se anunciaram.
	_jogador = get_tree().get_first_node_in_group("jogador") as Node3D
	for n in get_tree().get_nodes_in_group("corredores"):
		var no := n as Node3D
		var nome: String = "Você"
		if not no.is_in_group("jogador"):
			# usa o nome do piloto, se o rival tiver um; senão, o nome do nó
			nome = String(no.piloto_nome) if ("piloto_nome" in no and String(no.piloto_nome) != "") else String(no.name)
		var off0 := 0.0
		if _curva and _no_path:
			off0 = _curva.get_closest_offset(_no_path.to_local(no.global_position))
		_corredores.append({
			"no": no, "nome": nome, "voltas": 0, "passou": false, "off_ant": off0,
			"progresso": 0.0, "terminou": false, "colocacao": 0,
		})

	# Começa na contagem regressiva, com todos travados.
	Jogo.estado = Jogo.Estado.CONTAGEM
	if _jogador and "travado" in _jogador:
		_jogador.travado = true


func _process(delta: float) -> void:
	if Jogo.estado != Jogo.Estado.CONTAGEM:
		return
	_fase_contagem -= delta
	if _fase_contagem > 0.0:
		# ceil(3.99) seria 4 no 1º frame; limita a 3 para a largada ser "3-2-1".
		var n := mini(int(ceil(_fase_contagem)), 3)
		if n != _ultimo_n:
			_ultimo_n = n
			contagem.emit(n)        # HUD mostra "3", "2", "1" e dá o bipe
	else:
		_largar()


func _largar() -> void:
	Jogo.estado = Jogo.Estado.CORRENDO
	if _jogador and "travado" in _jogador:
		_jogador.travado = false
	_inicio_volta = 0.0
	largada.emit()                  # HUD mostra "VAI!" e toca o som


func _physics_process(delta: float) -> void:
	if Jogo.estado != Jogo.Estado.CORRENDO or _curva == null or _comprimento <= 0.0:
		return
	_tempo_corrida += delta
	for d in _corredores:
		_atualizar_corredor(d)


# Mede onde o corredor está na pista e detecta quando fecha uma volta.
func _atualizar_corredor(d: Dictionary) -> void:
	var no := d["no"] as Node3D
	if no == null:
		return
	var local := _no_path.to_local(no.global_position)
	var off := _curva.get_closest_offset(local)
	var off_ant: float = d["off_ant"]

	# Avançou no sentido CERTO? Passo pequeno para frente, ou a "emenda" da
	# linha cruzada para frente (salto grande negativo: de ~L para ~0).
	# Isso impede contar volta indo de ré (passo negativo ou salto grande +).
	var diff := off - off_ant
	var avancou := (diff > 0.0 and diff < _comprimento * 0.5) or (diff < -_comprimento * 0.5)

	# "Passou da metade" da volta? (banda no meio da pista para evitar
	# contagem falsa logo na largada ou ao reposicionar após uma queda.)
	if avancou and off > _comprimento * 0.4 and off < _comprimento * 0.6:
		d["passou"] = true
	# Cruzou a linha PARA FRENTE depois de passar da metade -> fechou uma volta.
	if d["passou"] and avancou and off < _comprimento * 0.12 and off_ant > _comprimento * 0.5:
		d["passou"] = false
		d["voltas"] = int(d["voltas"]) + 1
		_ao_fechar_volta(d)

	d["off_ant"] = off
	d["progresso"] = int(d["voltas"]) * _comprimento + off

	# Só para o jogador: detecta se ele está virado contra o sentido da pista.
	if no == _jogador:
		var p_now := _curva.sample_baked(off)
		var p_next := _curva.sample_baked(fmod(off + 2.0, _comprimento))
		var tang := p_next - p_now
		var frente := -no.global_transform.basis.z
		tang.y = 0.0; frente.y = 0.0
		var rapido: bool = ("velocidade_atual" in no) and absf(no.velocidade_atual) > 3.0
		if tang.length() > 0.01 and frente.length() > 0.01:
			_contramao = rapido and tang.normalized().dot(frente.normalized()) < -0.25
		else:
			_contramao = false


func _ao_fechar_volta(d: Dictionary) -> void:
	var no := d["no"] as Node3D
	volta_completada.emit(no, int(d["voltas"]))
	if no == _jogador:
		var t := _tempo_corrida - _inicio_volta
		_inicio_volta = _tempo_corrida
		_tempos_voltas.append(t)
		if _melhor_volta < 0.0 or t < _melhor_volta:
			_melhor_volta = t
		if int(d["voltas"]) >= Jogo.total_voltas:
			_terminar()


func _terminar() -> void:
	if _terminou:
		return
	_terminou = true
	Jogo.estado = Jogo.Estado.RESULTADO

	# Posição final do jogador = quantos têm mais progresso que ele + 1.
	var prog_jog := progresso_de(_jogador)
	var pos := 1
	for d in _corredores:
		if d["no"] != _jogador and float(d["progresso"]) > prog_jog:
			pos += 1

	# Preenche os dados que a tela de resultado vai ler.
	Jogo.resultado_posicao = pos
	Jogo.resultado_total_corredores = _corredores.size()
	Jogo.resultado_tempo_total = _tempo_corrida
	Jogo.resultado_melhor_volta = _melhor_volta
	Jogo.resultado_tempos_voltas = _tempos_voltas.duplicate()
	Jogo.resultado_bateu_recorde = Jogo.registrar_recorde(_melhor_volta)
	Jogo.resultado_classificacao = _classificacao_nomes()

	# Trava o jogador e, após um instante, vai para a tela de resultado.
	if _jogador and "travado" in _jogador:
		_jogador.travado = true
	corrida_terminou.emit()
	await get_tree().create_timer(1.6).timeout
	Transicao.trocar_cena(Jogo.CENA_RESULTADO)


# ------------------------------------------------------------
#  CONSULTAS usadas pela IA (npc.gd) e pelo HUD.
# ------------------------------------------------------------
func progresso_de(no: Node) -> float:
	for d in _corredores:
		if d["no"] == no:
			return float(d["progresso"])
	return 0.0


func progresso_jogador() -> float:
	return progresso_de(_jogador)


# Posição (1, 2, 3...) de um corredor agora.
func posicao_de(no: Node) -> int:
	var p := progresso_de(no)
	var pos := 1
	for d in _corredores:
		if d["no"] != no and float(d["progresso"]) > p:
			pos += 1
	return pos


func voltas_de(no: Node) -> int:
	for d in _corredores:
		if d["no"] == no:
			return int(d["voltas"])
	return 0


func total_corredores() -> int:
	return _corredores.size()


# Tempo da volta atual do jogador (para o cronômetro do HUD).
func tempo_volta_atual() -> float:
	return maxf(0.0, _tempo_corrida - _inicio_volta)


func melhor_volta_jogador() -> float:
	return _melhor_volta


# O jogador está indo no sentido errado da pista? (só vale durante a corrida)
func esta_contramao() -> bool:
	return _contramao and Jogo.estado == Jogo.Estado.CORRENDO


# ------------------------------------------------------------
#  SORTEIO DE ITENS (igual ao Mario Kart: quem está atrás tem
#  chance de itens melhores; o líder pega itens mais fracos).
# ------------------------------------------------------------
func sortear_item_para(no: Node) -> String:
	var total := maxi(total_corredores(), 1)
	var pos := posicao_de(no)
	# frac: 0.0 = líder, 1.0 = último colocado
	var frac := 0.0 if total <= 1 else clampf(float(pos - 1) / float(total - 1), 0.0, 1.0)
	var pesos := {
		"turbo": 3.0,
		"banana": lerpf(3.0, 0.4, frac),
		"casco": lerpf(1.0, 2.0, frac),
		"raio": lerpf(0.0, 1.6, frac),
		"estrela": lerpf(0.0, 2.2, frac),
	}
	return _sortear_por_peso(pesos)


func _sortear_por_peso(pesos: Dictionary) -> String:
	var soma := 0.0
	for k in pesos:
		soma += float(pesos[k])
	if soma <= 0.0:
		return "turbo"
	var r := randf() * soma
	for k in pesos:
		r -= float(pesos[k])
		if r <= 0.0:
			return String(k)
	return "turbo"


# Classificação ao vivo (1º, 2º, ...) para o HUD: lista de {nome, eh_jogador}.
func classificacao_atual() -> Array:
	var lista := _corredores.duplicate()
	lista.sort_custom(func(a, b): return float(a["progresso"]) > float(b["progresso"]))
	var res: Array = []
	for d in lista:
		res.append({"nome": String(d["nome"]), "eh_jogador": d["no"] == _jogador})
	return res


func _classificacao_nomes() -> Array[String]:
	var lista := _corredores.duplicate()
	lista.sort_custom(func(a, b): return float(a["progresso"]) > float(b["progresso"]))
	var nomes: Array[String] = []
	for d in lista:
		nomes.append(String(d["nome"]))
	return nomes
