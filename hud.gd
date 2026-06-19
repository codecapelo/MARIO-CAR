extends CanvasLayer

# ============================================================
#  HUD — tudo que aparece na tela durante a corrida:
#   velocímetro, contador de voltas (X/Y), posição (1º/N),
#   cronômetro + recorde, barra de turbo, contagem de largada
#   e o MENU DE PAUSA.
#
#  Quem manda na corrida é o gerente (nó "Main", pai deste HUD):
#  o HUD só ESCUTA os sinais dele e DESENHA o resultado.
# ============================================================

@export var kart_path: NodePath
@export var label_velocidade_path: NodePath
@export var label_largada_path: NodePath
@export var label_tempo_path: NodePath
@export var label_voltas_path: NodePath
@export var label_posicao_path: NodePath
@export var barra_boost_path: NodePath
@export var menu_pausa_path: NodePath
@export var beep_path: NodePath
@export var go_path: NodePath
@export var ranking_path: NodePath
@export var item_slot_path: NodePath
@export var aviso_path: NodePath

var kart: Node
var gerente: Node                 # o nó "Main" com o script pista.gd
var lbl_vel: Label
var lbl_largada: Label
var lbl_tempo: Label
var lbl_voltas: Label
var lbl_posicao: Label
var barra_boost: ProgressBar
var menu_pausa: Control
var beep: AudioStreamPlayer
var go: AudioStreamPlayer
var lbl_ranking: Label
var item_slot: Control
var item_nome: Label
var aviso: Label
var _rank_timer: float = 0.0

# Nome e cor de cada item, para o quadradinho do HUD.
const ITENS_INFO: Dictionary = {
	"turbo": {"nome": "TURBO", "cor": Color(1, 0.6, 0.1)},
	"estrela": {"nome": "ESTRELA", "cor": Color(1, 0.85, 0.1)},
	"raio": {"nome": "RAIO", "cor": Color(0.4, 0.6, 1)},
	"banana": {"nome": "BANANA", "cor": Color(0.95, 0.85, 0.1)},
	"casco": {"nome": "CASCO", "cor": Color(0.2, 0.8, 0.25)},
}


func _ready() -> void:
	kart = get_node_or_null(kart_path)
	gerente = get_parent()                      # o nó Main (pista.gd)
	lbl_vel = get_node_or_null(label_velocidade_path) as Label
	lbl_largada = get_node_or_null(label_largada_path) as Label
	lbl_tempo = get_node_or_null(label_tempo_path) as Label
	lbl_voltas = get_node_or_null(label_voltas_path) as Label
	lbl_posicao = get_node_or_null(label_posicao_path) as Label
	barra_boost = get_node_or_null(barra_boost_path) as ProgressBar
	menu_pausa = get_node_or_null(menu_pausa_path) as Control
	beep = get_node_or_null(beep_path) as AudioStreamPlayer
	go = get_node_or_null(go_path) as AudioStreamPlayer
	lbl_ranking = get_node_or_null(ranking_path) as Label
	item_slot = get_node_or_null(item_slot_path) as Control
	if item_slot:
		item_nome = item_slot.get_node_or_null("ItemNome") as Label
		item_slot.visible = false
	aviso = get_node_or_null(aviso_path) as Label
	if aviso:
		aviso.visible = false

	if menu_pausa:
		menu_pausa.visible = false
		_ligar_botoes_pausa()

	# Conecta os sinais do gerente da corrida.
	if gerente:
		if gerente.has_signal("contagem"):
			gerente.contagem.connect(_ao_contagem)
		if gerente.has_signal("largada"):
			gerente.largada.connect(_ao_largada)
		if gerente.has_signal("corrida_terminou"):
			gerente.corrida_terminou.connect(_ao_terminar)
		if gerente.has_signal("volta_completada"):
			gerente.volta_completada.connect(_ao_volta)

	_esquentar_sons()


func _process(delta: float) -> void:
	# Velocímetro (em km/h).
	if kart and lbl_vel and "velocidade_atual" in kart:
		lbl_vel.text = "%d km/h" % int(round(absf(kart.velocidade_atual) * 3.6))

	# Item guardado (quadradinho central no topo).
	if item_slot and kart and "item_guardado" in kart:
		var it: String = kart.item_guardado
		if it == "":
			item_slot.visible = false
		else:
			item_slot.visible = true
			if item_nome:
				var info: Dictionary = ITENS_INFO.get(it, {"nome": it.to_upper(), "cor": Color.WHITE})
				item_nome.text = String(info["nome"])
				item_nome.add_theme_color_override("font_color", info["cor"])

	# Aviso de contramão (piscando).
	if aviso and gerente and gerente.has_method("esta_contramao"):
		var errado: bool = gerente.esta_contramao()
		aviso.visible = errado and (int(Time.get_ticks_msec() / 300) % 2 == 0)

	# Classificação ao vivo (atualiza algumas vezes por segundo).
	_rank_timer -= delta
	if _rank_timer <= 0.0:
		_rank_timer = 0.25
		_atualizar_ranking()

	# Voltas (X/Y) e posição (1º/N).
	if gerente and gerente.has_method("voltas_de") and kart:
		if lbl_voltas:
			var v: int = mini(gerente.voltas_de(kart) + 1, Jogo.total_voltas)
			lbl_voltas.text = "Volta %d/%d" % [v, Jogo.total_voltas]
		if lbl_posicao and gerente.has_method("posicao_de"):
			lbl_posicao.text = "%dº/%d" % [gerente.posicao_de(kart), gerente.total_corredores()]

	# Cronômetro da volta + recorde.
	if lbl_tempo and gerente and gerente.has_method("tempo_volta_atual"):
		var txt := "Volta: %.2f s" % gerente.tempo_volta_atual()
		if Jogo.recorde_volta >= 0.0:
			txt += "\nRecorde: %.2f s" % Jogo.recorde_volta
		lbl_tempo.text = txt

	# Barra de turbo (mostra o tempo de boost restante).
	if barra_boost and kart and "boost_timer" in kart:
		barra_boost.value = kart.boost_timer
		barra_boost.visible = kart.boost_timer > 0.05


# ------------------------------------------------------------
#  LARGADA (vindo do gerente)
# ------------------------------------------------------------
func _ao_contagem(n: int) -> void:
	if lbl_largada:
		lbl_largada.add_theme_font_size_override("font_size", 130)
		lbl_largada.add_theme_color_override("font_color", Color(1, 1, 0.3))
		lbl_largada.text = str(n)
		_pop_largada(1.6)
	if beep:
		beep.pitch_scale = 0.9 if n >= 2 else 1.1   # sobe a tensão no "1"
		beep.play()


func _ao_largada() -> void:
	if lbl_largada:
		lbl_largada.add_theme_font_size_override("font_size", 120)
		lbl_largada.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		lbl_largada.text = "VAI!"
		_pop_largada(1.5)
	if go:
		go.pitch_scale = 1.0
		go.play()
	# limpa o "VAI!" depois de 1s, de forma segura mesmo se a cena trocar
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(func():
		if is_instance_valid(lbl_largada) and lbl_largada.text == "VAI!":
			lbl_largada.text = "")


# Última volta do jogador: mostra o aviso "ÚLTIMA VOLTA!".
func _ao_volta(no: Node, voltas: int) -> void:
	if no != kart or Jogo.total_voltas <= 1:
		return
	if voltas == Jogo.total_voltas - 1 and lbl_largada:
		lbl_largada.add_theme_font_size_override("font_size", 60)
		lbl_largada.add_theme_color_override("font_color", Color(1, 0.55, 0.15))
		lbl_largada.text = "ÚLTIMA VOLTA!"
		_pop_largada(1.3)
		if go:
			go.pitch_scale = 1.2
			go.play()
		var t := get_tree().create_timer(1.4)
		t.timeout.connect(func():
			if is_instance_valid(lbl_largada) and lbl_largada.text == "ÚLTIMA VOLTA!":
				lbl_largada.text = "")


func _ao_terminar() -> void:
	if lbl_largada:
		var pos := Jogo.resultado_posicao
		lbl_largada.add_theme_font_size_override("font_size", 76)
		lbl_largada.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		lbl_largada.text = "1º LUGAR!" if pos == 1 else "%dº LUGAR" % pos
		_pop_largada(1.4)


# Dá um "pop" (escala que cresce e assenta) no texto central da largada.
func _pop_largada(escala_ini: float = 1.5) -> void:
	if lbl_largada == null:
		return
	lbl_largada.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	lbl_largada.scale = Vector2(escala_ini, escala_ini)
	var tw := create_tween()
	tw.tween_property(lbl_largada, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Monta a lista de classificação (1º, 2º, ...) com o jogador destacado.
func _atualizar_ranking() -> void:
	if lbl_ranking == null or gerente == null or not gerente.has_method("classificacao_atual"):
		return
	var lista: Array = gerente.classificacao_atual()
	var txt := ""
	for i in lista.size():
		var d: Dictionary = lista[i]
		var marca := "> " if d["eh_jogador"] else ""
		txt += "%d. %s%s\n" % [i + 1, marca, String(d["nome"])]
	lbl_ranking.text = txt


# ------------------------------------------------------------
#  PAUSA
# ------------------------------------------------------------
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar"):
		if Jogo.estado == Jogo.Estado.CORRENDO:
			_pausar(true)
		elif Jogo.estado == Jogo.Estado.PAUSADO:
			_pausar(false)
	elif evento.is_action_pressed("reiniciar") and Jogo.estado in [Jogo.Estado.CORRENDO, Jogo.Estado.PAUSADO]:
		Transicao.trocar_cena(Jogo.cena_corrida_atual())


func _pausar(p: bool) -> void:
	get_tree().paused = p
	Jogo.estado = Jogo.Estado.PAUSADO if p else Jogo.Estado.CORRENDO
	if menu_pausa:
		menu_pausa.visible = p
		if p:
			var btn := menu_pausa.get_node_or_null("Caixa/Continuar")
			if btn:
				btn.grab_focus()


func _ligar_botoes_pausa() -> void:
	var cont := menu_pausa.get_node_or_null("Caixa/Continuar")
	var rein := menu_pausa.get_node_or_null("Caixa/Reiniciar")
	var menu := menu_pausa.get_node_or_null("Caixa/Menu")
	if cont:
		cont.pressed.connect(func(): _pausar(false))
	if rein:
		rein.pressed.connect(func(): Transicao.trocar_cena(Jogo.cena_corrida_atual()))
	if menu:
		menu.pressed.connect(func(): Transicao.trocar_cena(Jogo.CENA_MENU))


# Toca cada som uma vez em volume zero para o primeiro "de verdade" não engasgar.
func _esquentar_sons() -> void:
	for p in [beep, go]:
		if p:
			var v: float = p.volume_db
			p.volume_db = -80.0
			p.play()
			p.stop()
			p.volume_db = v
