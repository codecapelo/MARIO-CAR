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

	_esquentar_sons()


func _process(_delta: float) -> void:
	# Velocímetro (em km/h).
	if kart and lbl_vel and "velocidade_atual" in kart:
		lbl_vel.text = "%d km/h" % int(round(absf(kart.velocidade_atual) * 3.6))

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
		lbl_largada.text = str(n)
	if beep:
		beep.pitch_scale = 0.9 if n >= 2 else 1.1   # sobe a tensão no "1"
		beep.play()


func _ao_largada() -> void:
	if lbl_largada:
		lbl_largada.text = "VAI!"
	if go:
		go.pitch_scale = 1.0
		go.play()
	# limpa o "VAI!" depois de 1s, de forma segura mesmo se a cena trocar
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(func():
		if is_instance_valid(lbl_largada):
			lbl_largada.text = "")


func _ao_terminar() -> void:
	if lbl_largada:
		var pos := Jogo.resultado_posicao
		lbl_largada.text = "1º LUGAR!" if pos == 1 else "%dº LUGAR" % pos


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
		Transicao.trocar_cena(Jogo.CENA_CORRIDA)


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
		rein.pressed.connect(func(): Transicao.trocar_cena(Jogo.CENA_CORRIDA))
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
