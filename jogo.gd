extends Node

# ============================================================
#  AUTOLOAD "Jogo" — O CÉREBRO GLOBAL DO JOGO
#
#  Um autoload (singleton) é um nó que o Godot cria sozinho ao abrir
#  o jogo e que QUALQUER script alcança pelo nome global "Jogo".
#  Ele sobrevive às trocas de cena (menu -> corrida -> resultado),
#  então é o lugar certo para guardar:
#    - em que ESTADO o jogo está;
#    - as regras da corrida (quantas voltas);
#    - os dados da última corrida (para a tela de resultado);
#    - as configurações (volume) e o recorde, salvos em disco.
# ============================================================

# Os estados possíveis do jogo. Um enum é só uma lista de nomes
# legíveis (MENU = 0, CONTAGEM = 1, ...).
enum Estado { MENU, CONTAGEM, CORRENDO, PAUSADO, RESULTADO }

# Onde ficam as cenas — constantes evitam erro de digitação espalhado.
const CENA_MENU: String = "res://menu.tscn"
const CENA_CORRIDA: String = "res://main_3d.tscn"
const CENA_RESULTADO: String = "res://resultado.tscn"

# As pistas disponíveis (escolhidas no menu). Cada uma é uma cena própria,
# gerada por tools/gen_main3d.py com um traçado e clima diferentes.
const PISTAS: Array = [
	{"nome": "Ponte do Oceano", "cena": "res://main_3d.tscn"},
	{"nome": "Baía do Pôr do Sol", "cena": "res://pista2.tscn"},
	{"nome": "Ilha da Lua", "cena": "res://pista3.tscn"},
]

# Cores que o jogador pode escolher para o seu kart.
# (é var, não const, porque guarda Color() — evita qualquer dúvida de
#  avaliação em tempo de compilação; na prática funciona como constante.)
var CORES_KART: Array = [
	{"nome": "Vermelho", "cor": Color(0.85, 0.13, 0.11)},
	{"nome": "Azul", "cor": Color(0.15, 0.4, 0.85)},
	{"nome": "Verde", "cor": Color(0.16, 0.62, 0.2)},
	{"nome": "Roxo", "cor": Color(0.62, 0.24, 0.72)},
	{"nome": "Laranja", "cor": Color(0.95, 0.5, 0.1)},
]

# Níveis de dificuldade (afetam a velocidade e a "borracha" dos rivais).
const DIFICULDADES: Array = ["Fácil", "Normal", "Difícil"]

# Onde gravamos as configurações/recorde (user:// é uma pasta segura
# do sistema do jogador, fora do projeto — não vai para o git).
const CAMINHO_SAVE: String = "user://config.cfg"

# --- estado atual ---
var estado: Estado = Estado.MENU

# --- regras da corrida (configuráveis no menu) ---
var total_voltas: int = 3
var dificuldade: int = 1        # índice em DIFICULDADES (0 Fácil .. 2 Difícil)
var pista_idx: int = 0          # índice em PISTAS (qual circuito correr)
var cor_kart_idx: int = 0       # índice em CORES_KART (cor do kart do jogador)

# --- configurações de áudio (0.0 a 1.0), salvas em disco ---
var vol_master: float = 0.9
var vol_musica: float = 0.7
var vol_sfx: float = 1.0

# --- recorde de melhor volta (segundos). -1 = ainda não há recorde ---
var recorde_volta: float = -1.0

# --- dados preenchidos quando a corrida acaba (lidos pela tela de resultado) ---
var resultado_posicao: int = 1          # 1 = venceu
var resultado_total_corredores: int = 1
var resultado_tempo_total: float = 0.0
var resultado_melhor_volta: float = -1.0
var resultado_tempos_voltas: Array[float] = []
var resultado_classificacao: Array[String] = []   # nomes em ordem (1º, 2º, ...)
var resultado_bateu_recorde: bool = false


func _ready() -> void:
	# Carrega as preferências salvas e aplica os volumes assim que o jogo abre.
	_carregar()
	aplicar_volumes()


# ------------------------------------------------------------
#  OPÇÕES escolhidas no menu (lidas pela corrida e pelos rivais).
# ------------------------------------------------------------
# Caminho da cena da pista escolhida (usado para começar/reiniciar a corrida).
func cena_corrida_atual() -> String:
	return String(PISTAS[clampi(pista_idx, 0, PISTAS.size() - 1)]["cena"])

func nome_pista() -> String:
	return String(PISTAS[clampi(pista_idx, 0, PISTAS.size() - 1)]["nome"])

# Cor escolhida para o kart do jogador (aplicada em kart_3d.gd no _ready).
func cor_kart() -> Color:
	return CORES_KART[clampi(cor_kart_idx, 0, CORES_KART.size() - 1)]["cor"]

func nome_cor_kart() -> String:
	return String(CORES_KART[clampi(cor_kart_idx, 0, CORES_KART.size() - 1)]["nome"])

func nome_dificuldade() -> String:
	return String(DIFICULDADES[clampi(dificuldade, 0, DIFICULDADES.size() - 1)])

# Quanto a dificuldade multiplica a velocidade dos rivais.
func fator_vel_rival() -> float:
	return [0.9, 1.0, 1.1][clampi(dificuldade, 0, 2)]

# Quão forte os rivais reagem à distância (rubber-banding) por dificuldade.
func fator_borracha() -> float:
	return [0.55, 1.0, 1.5][clampi(dificuldade, 0, 2)]


# Zera os dados de corrida antes de começar uma nova partida.
func reiniciar_dados_corrida() -> void:
	resultado_posicao = 1
	resultado_total_corredores = 1
	resultado_tempo_total = 0.0
	resultado_melhor_volta = -1.0
	resultado_tempos_voltas.clear()
	resultado_classificacao.clear()
	resultado_bateu_recorde = false


# Tenta registrar um novo recorde de volta. Devolve true se bateu o anterior.
func registrar_recorde(tempo: float) -> bool:
	if tempo <= 0.0:
		return false
	if recorde_volta < 0.0 or tempo < recorde_volta:
		recorde_volta = tempo
		salvar()
		return true
	return false


# ------------------------------------------------------------
#  ÁUDIO: converte 0..1 em decibéis e aplica em cada barramento.
# ------------------------------------------------------------
func aplicar_volumes() -> void:
	_set_bus_volume("Master", vol_master)
	_set_bus_volume("Musica", vol_musica)
	_set_bus_volume("SFX", vol_sfx)


func _set_bus_volume(nome: String, fracao: float) -> void:
	var idx := AudioServer.get_bus_index(nome)
	if idx < 0:
		return  # o barramento ainda não existe (tudo bem, vai para o Master)
	# linear_to_db transforma 0..1 numa curva de volume natural ao ouvido.
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(fracao, 0.0001, 1.0)))
	AudioServer.set_bus_mute(idx, fracao <= 0.001)


# ------------------------------------------------------------
#  PERSISTÊNCIA: grava/lê um arquivo .cfg simples em user://.
# ------------------------------------------------------------
func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("corrida", "total_voltas", total_voltas)
	cfg.set_value("corrida", "dificuldade", dificuldade)
	cfg.set_value("corrida", "pista_idx", pista_idx)
	cfg.set_value("corrida", "cor_kart_idx", cor_kart_idx)
	cfg.set_value("corrida", "recorde_volta", recorde_volta)
	cfg.set_value("audio", "vol_master", vol_master)
	cfg.set_value("audio", "vol_musica", vol_musica)
	cfg.set_value("audio", "vol_sfx", vol_sfx)
	var err := cfg.save(CAMINHO_SAVE)
	if err != OK:
		push_warning("Jogo: não consegui salvar a configuração (erro %d)." % err)


func _carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO_SAVE) != OK:
		return  # primeira vez rodando: mantém os valores padrão
	total_voltas = int(cfg.get_value("corrida", "total_voltas", total_voltas))
	dificuldade = clampi(int(cfg.get_value("corrida", "dificuldade", dificuldade)), 0, DIFICULDADES.size() - 1)
	pista_idx = clampi(int(cfg.get_value("corrida", "pista_idx", pista_idx)), 0, PISTAS.size() - 1)
	cor_kart_idx = clampi(int(cfg.get_value("corrida", "cor_kart_idx", cor_kart_idx)), 0, CORES_KART.size() - 1)
	recorde_volta = float(cfg.get_value("corrida", "recorde_volta", recorde_volta))
	vol_master = float(cfg.get_value("audio", "vol_master", vol_master))
	vol_musica = float(cfg.get_value("audio", "vol_musica", vol_musica))
	vol_sfx = float(cfg.get_value("audio", "vol_sfx", vol_sfx))
