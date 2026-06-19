#!/usr/bin/env python3
# ============================================================
#  Gera a TEXTURA DA PISTA (asfalto de corrida), sem depender de
#  downloads. Escreve assets/asfalto.png + o .import do Godot.
#
#  O asfalto é feito por "ruído de valor periódico" (que dá a textura
#  granulada do asfalto e fecha nas bordas, então repete sem emendas
#  visíveis), com alguns grãos claros de brita por cima.
# ============================================================
import os, hashlib
import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(RAIZ, "assets")
TAM = 512


def ruido_periodico(tam, freq, rng):
    """Ruído de valor que REPETE (tileable): a grade aleatória dá a volta
    no índice (módulo freq), então as bordas casam perfeitamente."""
    g = rng.random((freq, freq)).astype(np.float64)
    eixo = np.linspace(0.0, freq, tam, endpoint=False)
    i0 = np.floor(eixo).astype(int) % freq
    i1 = (i0 + 1) % freq
    f = eixo - np.floor(eixo)
    f = f * f * (3.0 - 2.0 * f)        # smoothstep (interpolação suave)

    # bilinear com wrap, usando produto externo dos eixos x e y
    gx0 = g[np.ix_(i0, i0)]; gx1 = g[np.ix_(i0, i1)]
    gy0 = g[np.ix_(i1, i0)]; gy1 = g[np.ix_(i1, i1)]
    fx = f[None, :]; fy = f[:, None]
    topo = gx0 * (1 - fx) + gx1 * fx
    base = gy0 * (1 - fx) + gy1 * fx
    return topo * (1 - fy) + base * fy


def gerar_asfalto():
    rng = np.random.default_rng(20240619)

    # Várias "oitavas" de ruído: manchas grandes + grão fino do asfalto.
    val = np.zeros((TAM, TAM))
    for freq, peso in [(4, 0.42), (8, 0.24), (32, 0.16), (128, 0.12), (256, 0.06)]:
        val += ruido_periodico(TAM, freq, rng) * peso
    val = (val - val.min()) / (val.max() - val.min() + 1e-9)

    # Mapeia para um cinza escuro de asfalto (azulado), com leve contraste.
    base = 0.10 + 0.16 * val                      # ~0.10 .. 0.26
    r = base * 0.95
    g = base * 1.00
    b = base * 1.08 + 0.01                         # leve tom azul-frio
    img = np.stack([r, g, b], axis=-1)

    # Grãos claros de brita (pequenos pontos espalhados).
    n_graos = 2600
    ys = rng.integers(0, TAM, n_graos)
    xs = rng.integers(0, TAM, n_graos)
    brilho = rng.uniform(0.18, 0.4, n_graos)
    for x, y, brl in zip(xs, ys, brilho):
        img[y, x] += brl
        # um vizinho para o grão não ficar de 1px só
        img[y, (x + 1) % TAM] += brl * 0.5

    img = np.clip(img, 0.0, 1.0)
    out = (img * 255.0).astype(np.uint8)
    caminho = os.path.join(ASSETS, "asfalto.png")
    Image.fromarray(out, "RGB").save(caminho)
    return caminho


def _uid(path):
    n = int(hashlib.md5((path + "uid").encode()).hexdigest()[:12], 16)
    alf = "abcdefghijklmnopqrstuvwxyz0123456789"
    s = ""
    for _ in range(12):
        s += alf[n % len(alf)]; n //= len(alf)
    return s


def escrever_import(nome):
    res = "res://assets/%s" % nome
    h = hashlib.md5(res.encode()).hexdigest()
    conteudo = (
        "[remap]\n\n"
        'importer="texture"\n'
        'type="CompressedTexture2D"\n'
        'uid="uid://%s"\n'
        'path="res://.godot/imported/%s-%s.ctex"\n'
        "metadata={\n\"vram_texture\": false\n}\n\n"
        "[deps]\n\n"
        'source_file="%s"\n'
        'dest_files=["res://.godot/imported/%s-%s.ctex"]\n\n'
        "[params]\n\n"
        "compress/mode=0\n"
        "compress/high_quality=false\n"
        "compress/lossy_quality=0.7\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=true\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/hdr_as_srgb=false\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n"
    ) % (_uid(res), nome, h, res, nome, h)
    open(os.path.join(ASSETS, nome + ".import"), "w").write(conteudo)


if __name__ == "__main__":
    gerar_asfalto()
    escrever_import("asfalto.png")
    print("Textura gerada: assets/asfalto.png (asfalto de corrida, tileable).")
