extends Control

# ============================================================
#  MENU INICIAL — primeira tela do jogo.
#  Jogar / Configurações (voltas + volumes) / Sair.
# ============================================================

@onready var painel_config: Control = $PainelConfig


func _ready() -> void:
	Jogo.estado = Jogo.Estado.MENU
	# Liga os botões principais.
	$Centro/Botoes/Jogar.pressed.connect(_ao_jogar)
	$Centro/Botoes/Config.pressed.connect(func(): painel_config.visible = true)
	$Centro/Botoes/Sair.pressed.connect(func(): get_tree().quit())
	$Centro/Botoes/Jogar.grab_focus()   # foco para teclado/gamepad

	# Painel de configurações.
	painel_config.visible = false
	_montar_config()


func _ao_jogar() -> void:
	Jogo.reiniciar_dados_corrida()
	Jogo.estado = Jogo.Estado.CONTAGEM
	Transicao.trocar_cena(Jogo.CENA_CORRIDA)


# ------------------------------------------------------------
#  CONFIGURAÇÕES
# ------------------------------------------------------------
func _montar_config() -> void:
	var c := painel_config

	# Número de voltas (botões - e +).
	c.get_node("Caixa/Voltas/Menos").pressed.connect(func(): _mudar_voltas(-1))
	c.get_node("Caixa/Voltas/Mais").pressed.connect(func(): _mudar_voltas(1))
	_atualizar_label_voltas()

	# Sliders de volume (0..100 -> 0..1).
	_ligar_slider(c.get_node("Caixa/VolMaster/Slider"), Jogo.vol_master, _set_master)
	_ligar_slider(c.get_node("Caixa/VolMusica/Slider"), Jogo.vol_musica, _set_musica)
	_ligar_slider(c.get_node("Caixa/VolSfx/Slider"), Jogo.vol_sfx, _set_sfx)

	c.get_node("Caixa/Voltar").pressed.connect(func():
		Jogo.salvar()
		painel_config.visible = false
		$Centro/Botoes/Jogar.grab_focus())


func _ligar_slider(s: HSlider, valor: float, callback: Callable) -> void:
	s.min_value = 0.0
	s.max_value = 100.0
	s.value = valor * 100.0
	s.value_changed.connect(func(v): callback.call(v / 100.0))


func _mudar_voltas(d: int) -> void:
	Jogo.total_voltas = clampi(Jogo.total_voltas + d, 1, 9)
	_atualizar_label_voltas()


func _atualizar_label_voltas() -> void:
	painel_config.get_node("Caixa/Voltas/Valor").text = str(Jogo.total_voltas)


func _set_master(v: float) -> void:
	Jogo.vol_master = v
	Jogo.aplicar_volumes()


func _set_musica(v: float) -> void:
	Jogo.vol_musica = v
	Jogo.aplicar_volumes()


func _set_sfx(v: float) -> void:
	Jogo.vol_sfx = v
	Jogo.aplicar_volumes()
