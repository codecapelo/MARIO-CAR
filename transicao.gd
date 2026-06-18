extends CanvasLayer

# ============================================================
#  AUTOLOAD "Transicao" — TROCA DE CENA COM FADE PRETO
#
#  Trocar de cena com get_tree().change_scene_to_file() "corta seco".
#  Aqui escurecemos a tela, trocamos a cena por baixo e clareamos de
#  novo — um detalhe simples que dá acabamento profissional.
#
#  Como é autoload e fica acima de tudo (layer alta) e sempre processa
#  (mesmo com o jogo pausado), serve a qualquer cena do jogo.
# ============================================================

var _tela: ColorRect
var _ocupado: bool = false


func _ready() -> void:
	# Fica por cima de toda a interface.
	layer = 128
	# Mesmo com o jogo pausado, o fade precisa continuar animando.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Cria o retângulo preto que cobre a tela inteira (começa invisível).
	_tela = ColorRect.new()
	_tela.color = Color(0, 0, 0, 0)
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Deixa o clique passar direto (não bloqueia botões dos menus).
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela)


# Escurece, troca de cena e clareia. Use sempre isto em vez de
# change_scene_to_file() direto.
func trocar_cena(caminho: String) -> void:
	if _ocupado:
		return
	_ocupado = true
	# Garante que o jogo não fica pausado durante a troca.
	get_tree().paused = false

	var t1 := create_tween()
	t1.tween_property(_tela, "color:a", 1.0, 0.3)   # escurece
	await t1.finished

	var err := get_tree().change_scene_to_file(caminho)
	if err != OK:
		push_error("Transicao: falha ao abrir a cena '%s' (erro %d)." % [caminho, err])

	var t2 := create_tween()
	t2.tween_property(_tela, "color:a", 0.0, 0.3)   # clareia
	await t2.finished
	_ocupado = false
