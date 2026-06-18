#!/usr/bin/env python3
# ============================================================
#  Gera os sons que faltavam, SEM bibliotecas externas (só a
#  biblioteca padrão do Python). Escreve WAVs 16-bit mono em assets/
#  e também o arquivo .import de cada um (com loop quando preciso),
#  para o Godot importar com as opções certas no primeiro F5.
#
#  Sons gerados:
#    musica_corrida.wav  — trilha alegre em loop (arpejo + baixo)
#    whoosh.wav          — "fwoosh" do turbo (ruído com decaimento)
#    drift.wav           — chiado de derrapagem (loop)
#    fanfarra.wav        — 3 notas subindo (vitória)
# ============================================================
import wave, struct, math, random, hashlib, os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(RAIZ, "assets")
SR = 22050

random.seed(7)   # determinístico: o mesmo som toda vez que rodar


def freq(semi):
	# Frequência de uma nota a 'semi' semitons do Dó central (~261.63 Hz).
	return 261.63 * (2.0 ** (semi / 12.0))


def escrever_wav(nome, amostras):
	# 'amostras' é uma lista de floats -1..1.
	caminho = os.path.join(ASSETS, nome)
	frames = bytearray()
	for s in amostras:
		v = int(max(-1.0, min(1.0, s)) * 30000)
		frames += struct.pack("<h", v)
	w = wave.open(caminho, "w")
	w.setnchannels(1)
	w.setsampwidth(2)
	w.setframerate(SR)
	w.writeframes(frames)
	w.close()
	return caminho


def escrever_import(nome, loop):
	# Cria o .import para o Godot saber importar (PCM 16-bit; loop se preciso).
	res = "res://assets/%s" % nome
	h = hashlib.md5(res.encode()).hexdigest()
	uid_seed = int(hashlib.md5((res + "uid").encode()).hexdigest()[:12], 16)
	conteudo = (
		"[remap]\n\n"
		'importer="wav"\n'
		'type="AudioStreamWAV"\n'
		'uid="uid://%s"\n'
		'path="res://.godot/imported/%s-%s.sample"\n\n'
		"[deps]\n\n"
		'source_file="%s"\n'
		'dest_files=["res://.godot/imported/%s-%s.sample"]\n\n'
		"[params]\n\n"
		"force/8_bit=false\n"
		"force/mono=false\n"
		"force/max_rate=false\n"
		"force/max_rate_hz=44100\n"
		"edit/trim=false\n"
		"edit/normalize=false\n"
		"edit/loop_mode=%d\n"
		"edit/loop_begin=0\n"
		"edit/loop_end=-1\n"
		"compress/mode=0\n"
	) % (_uid_str(uid_seed), nome, h, res, nome, h, (1 if loop else 0))
	open(os.path.join(ASSETS, nome + ".import"), "w").write(conteudo)


def _uid_str(n):
	# Converte um número em uma string curta estilo uid do Godot (base 36-ish).
	alfabeto = "abcdefghijklmnopqrstuvwxyz0123456789"
	s = ""
	n = abs(n)
	for _ in range(12):
		s += alfabeto[n % len(alfabeto)]
		n //= len(alfabeto)
	return s


# ---------------- MÚSICA (loop ~8s) ----------------
def gerar_musica():
	bpm = 132.0
	dur = 8.0
	n = int(SR * dur)
	# padrão de arpejo (semitons) — uma volta alegre em Dó maior
	notas = [0, 4, 7, 12, 7, 4, 7, 12, 0, 4, 7, 16, 12, 7, 4, 0]
	passo_por_seg = (bpm / 60.0) * 2.0   # colcheias
	out = []
	for i in range(n):
		t = i / SR
		idx = int(t * passo_por_seg) % len(notas)
		f = freq(notas[idx])
		# arpejo em onda triangular (suave)
		tri = 2.0 * abs(2.0 * ((t * f) % 1.0) - 1.0) - 1.0
		# baixo uma oitava abaixo, onda quadrada fraca, troca mais devagar
		idxb = int(t * passo_por_seg * 0.5) % len(notas)
		fb = freq(notas[idxb] - 12)
		sq = 1.0 if (t * fb) % 1.0 < 0.5 else -1.0
		s = 0.34 * tri + 0.16 * sq
		# pequeno "ataque" rítmico para dar pulso
		batida = (t * passo_por_seg) % 1.0
		s *= 0.7 + 0.3 * (1.0 - batida)
		# fade bem curto nas pontas para não estalar no loop
		env = min(1.0, t / 0.01, (dur - t) / 0.01)
		out.append(s * env * 0.85)
	escrever_wav("musica_corrida.wav", out)
	escrever_import("musica_corrida.wav", loop=True)


# ---------------- WHOOSH (turbo) ----------------
def gerar_whoosh():
	n = int(SR * 0.5)
	prev = 0.0
	out = []
	for i in range(n):
		r = random.uniform(-1.0, 1.0)
		prev = prev * 0.86 + r * 0.14         # passa-baixa = sopro grave
		env = (1.0 - i / n) ** 2               # decai rápido
		# leve subida de tom (varredura)
		sweep = math.sin(2.0 * math.pi * (200.0 + 600.0 * i / n) * i / SR) * 0.2
		out.append((prev + sweep) * env * 0.7)
	escrever_wav("whoosh.wav", out)
	escrever_import("whoosh.wav", loop=False)


# ---------------- DRIFT (chiado em loop) ----------------
def gerar_drift():
	n = int(SR * 0.4)
	prev = 0.0
	out = []
	for i in range(n):
		r = random.uniform(-1.0, 1.0)
		# passa-alta simples: ruído menos a sua média -> chiado agudo
		prev = prev * 0.5 + r * 0.5
		agudo = r - prev
		out.append(agudo * 0.5)
	# casa o fim com o começo para o loop não estalar (crossfade curto)
	cf = int(SR * 0.02)
	for i in range(cf):
		a = i / cf
		out[i] = out[i] * a + out[n - cf + i] * (1.0 - a)
	escrever_wav("drift.wav", out)
	escrever_import("drift.wav", loop=True)


# ---------------- FANFARRA (vitória) ----------------
def gerar_fanfarra():
	notas = [0, 4, 7, 12]      # Dó - Mi - Sol - Dó (sobe)
	dur_nota = 0.18
	out = []
	for k, semi in enumerate(notas):
		f = freq(semi + 12)
		nn = int(SR * (dur_nota if k < len(notas) - 1 else dur_nota * 2.5))
		for i in range(nn):
			t = i / SR
			# onda quadrada brilhante + um pouco de senoide
			sq = 1.0 if (t * f) % 1.0 < 0.5 else -1.0
			sn = math.sin(2.0 * math.pi * f * t)
			env = min(1.0, (nn - i) / (SR * 0.05))
			out.append((0.5 * sq + 0.3 * sn) * env * 0.7)
	escrever_wav("fanfarra.wav", out)
	escrever_import("fanfarra.wav", loop=False)


if __name__ == "__main__":
	gerar_musica()
	gerar_whoosh()
	gerar_drift()
	gerar_fanfarra()
	print("Áudio gerado em assets/: musica_corrida.wav, whoosh.wav, drift.wav, fanfarra.wav")
