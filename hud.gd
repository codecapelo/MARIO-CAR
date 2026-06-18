extends CanvasLayer

# ============================================================
#  HUD: velocímetro + CONTAGEM DE LARGADA (3, 2, 1, VAI!)
#  Durante a contagem o kart fica travado; no "VAI!" ele libera.
# ============================================================

@export var kart_path: NodePath
@export var label_velocidade_path: NodePath
@export var label_largada_path: NodePath
@export var beep_path: NodePath
@export var go_path: NodePath

var kart: Node
var lbl_vel: Label
var lbl_largada: Label
var beep: AudioStreamPlayer
var go: AudioStreamPlayer

var contando: bool = true
var fase: float = 3.99          # conta de 3 até 0
var ultimo_numero: int = 99


func _ready() -> void:
	kart = get_node_or_null(kart_path)
	lbl_vel = get_node_or_null(label_velocidade_path) as Label
	lbl_largada = get_node_or_null(label_largada_path) as Label
	beep = get_node_or_null(beep_path) as AudioStreamPlayer
	go = get_node_or_null(go_path) as AudioStreamPlayer
	if kart:
		kart.travado = true            # segura o kart até o "VAI!"


func _process(delta: float) -> void:
	# Velocímetro (sempre).
	if kart and lbl_vel:
		lbl_vel.text = "%d km/h" % int(round(absf(kart.velocidade_atual) * 3.6))

	if not contando:
		return

	fase -= delta
	if fase > 0.0:
		# Mostra 3, 2, 1 e dá um bipe a cada número novo.
		var n := int(ceil(fase))
		if n != ultimo_numero:
			ultimo_numero = n
			if lbl_largada:
				lbl_largada.text = str(n)
			if beep:
				beep.play()
	else:
		# Acabou a contagem: libera o kart e mostra "VAI!".
		contando = false
		if lbl_largada:
			lbl_largada.text = "VAI!"
		if go:
			go.play()
		if kart:
			kart.travado = false
		await get_tree().create_timer(1.0).timeout
		if lbl_largada:
			lbl_largada.text = ""
