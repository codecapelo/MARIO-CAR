extends Control

# ============================================================
#  TELA DE RESULTADO — fim da corrida.
#  Mostra a posição, tempos e a classificação; botões para
#  correr de novo ou voltar ao menu.
# ============================================================

@onready var som_fanfarra: AudioStreamPlayer = $Fanfarra


func _ready() -> void:
	Jogo.estado = Jogo.Estado.RESULTADO

	var pos := Jogo.resultado_posicao
	var total := Jogo.resultado_total_corredores
	$Centro/Titulo.text = "VOCÊ VENCEU!" if pos == 1 else "VOCÊ FICOU EM %dº" % pos
	$Centro/Subtitulo.text = "de %d corredores" % total

	# Tempos.
	var txt := "Tempo total: %s\n" % _formatar(Jogo.resultado_tempo_total)
	txt += "Melhor volta: %s" % _formatar(Jogo.resultado_melhor_volta)
	if Jogo.resultado_bateu_recorde:
		txt += "  ⭐ NOVO RECORDE!"
	# Tempos por volta.
	if not Jogo.resultado_tempos_voltas.is_empty():
		txt += "\n\nVoltas:"
		for i in Jogo.resultado_tempos_voltas.size():
			txt += "\n  %d: %s" % [i + 1, _formatar(Jogo.resultado_tempos_voltas[i])]
	$Centro/Tempos.text = txt

	# Classificação (1º, 2º, ...).
	if not Jogo.resultado_classificacao.is_empty():
		var cl := "Classificação:"
		for i in Jogo.resultado_classificacao.size():
			cl += "\n  %dº  %s" % [i + 1, Jogo.resultado_classificacao[i]]
		$Centro/Classificacao.text = cl

	# Botões.
	$Centro/Botoes/Reiniciar.pressed.connect(func(): Transicao.trocar_cena(Jogo.CENA_CORRIDA))
	$Centro/Botoes/Menu.pressed.connect(func(): Transicao.trocar_cena(Jogo.CENA_MENU))
	$Centro/Botoes/Reiniciar.grab_focus()

	# Som de vitória.
	if pos == 1 and som_fanfarra:
		som_fanfarra.play()


# Formata segundos como "m:ss.cc" ou "s.cc s".
func _formatar(s: float) -> String:
	if s < 0.0:
		return "--"
	if s >= 60.0:
		var m := int(s) / 60
		var seg := s - m * 60.0
		return "%d:%05.2f" % [m, seg]
	return "%.2f s" % s
