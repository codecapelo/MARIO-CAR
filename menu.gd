extends Control

# ============================================================
#  MENU INICIAL — primeira tela do jogo.
#  Jogar / Configurações / Como jogar / Sair.
#  As configurações guardam: voltas, dificuldade, pista, cor do
#  kart e volumes (tudo salvo em disco pelo autoload Jogo).
# ============================================================

@onready var painel_config: Control = $PainelConfig
@onready var painel_controles: Control = $PainelControles


func _ready() -> void:
	Jogo.estado = Jogo.Estado.MENU
	# Liga os botões principais.
	$Centro/Botoes/Jogar.pressed.connect(_ao_jogar)
	$Centro/Botoes/Config.pressed.connect(func(): painel_config.visible = true)
	$Centro/Botoes/Controles.pressed.connect(func(): painel_controles.visible = true)
	$Centro/Botoes/Sair.pressed.connect(func(): get_tree().quit())
	$Centro/Botoes/Jogar.grab_focus()   # foco para teclado/gamepad

	# Painéis.
	painel_config.visible = false
	painel_controles.visible = false
	_montar_config()
	painel_controles.get_node("Caixa/Voltar").pressed.connect(func():
		painel_controles.visible = false
		$Centro/Botoes/Jogar.grab_focus())


func _ao_jogar() -> void:
	Jogo.reiniciar_dados_corrida()
	Jogo.estado = Jogo.Estado.CONTAGEM
	Transicao.trocar_cena(Jogo.cena_corrida_atual())


# ------------------------------------------------------------
#  CONFIGURAÇÕES
# ------------------------------------------------------------
func _montar_config() -> void:
	var c := painel_config

	# Número de voltas.
	c.get_node("Caixa/Voltas/Menos").pressed.connect(func(): _mudar_voltas(-1))
	c.get_node("Caixa/Voltas/Mais").pressed.connect(func(): _mudar_voltas(1))

	# Dificuldade.
	c.get_node("Caixa/Dificuldade/Menos").pressed.connect(func(): _mudar_dificuldade(-1))
	c.get_node("Caixa/Dificuldade/Mais").pressed.connect(func(): _mudar_dificuldade(1))

	# Pista.
	c.get_node("Caixa/Pista/Menos").pressed.connect(func(): _mudar_pista(-1))
	c.get_node("Caixa/Pista/Mais").pressed.connect(func(): _mudar_pista(1))

	# Cor do kart.
	c.get_node("Caixa/Cor/Menos").pressed.connect(func(): _mudar_cor(-1))
	c.get_node("Caixa/Cor/Mais").pressed.connect(func(): _mudar_cor(1))

	_atualizar_labels()

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
	_atualizar_labels()


func _mudar_dificuldade(d: int) -> void:
	Jogo.dificuldade = clampi(Jogo.dificuldade + d, 0, Jogo.DIFICULDADES.size() - 1)
	_atualizar_labels()


func _mudar_pista(d: int) -> void:
	# Dá a volta na lista (cíclico) para escolher a pista.
	Jogo.pista_idx = (Jogo.pista_idx + d) % Jogo.PISTAS.size()
	if Jogo.pista_idx < 0:
		Jogo.pista_idx += Jogo.PISTAS.size()
	_atualizar_labels()


func _mudar_cor(d: int) -> void:
	Jogo.cor_kart_idx = (Jogo.cor_kart_idx + d) % Jogo.CORES_KART.size()
	if Jogo.cor_kart_idx < 0:
		Jogo.cor_kart_idx += Jogo.CORES_KART.size()
	_atualizar_labels()


func _atualizar_labels() -> void:
	var c := painel_config
	c.get_node("Caixa/Voltas/Valor").text = str(Jogo.total_voltas)
	c.get_node("Caixa/Dificuldade/Valor").text = Jogo.nome_dificuldade()
	c.get_node("Caixa/Pista/Valor").text = Jogo.nome_pista()
	var lbl_cor := c.get_node("Caixa/Cor/Valor") as Label
	lbl_cor.text = Jogo.nome_cor_kart()
	lbl_cor.add_theme_color_override("font_color", Jogo.cor_kart())


func _set_master(v: float) -> void:
	Jogo.vol_master = v
	Jogo.aplicar_volumes()


func _set_musica(v: float) -> void:
	Jogo.vol_musica = v
	Jogo.aplicar_volumes()


func _set_sfx(v: float) -> void:
	Jogo.vol_sfx = v
	Jogo.aplicar_volumes()
