# MarioCard 🏎️

Jogo de kart **3D top-down/perseguição** feito em **Godot 4.6**, ambientado numa **ponte de pedra sobre o oceano** com montanhas nevadas ao fundo — no estilo das pistas do Mario Kart.

> Projeto de estudo do Raul (médico, iniciante em programação). Código e comentários em **português**.

## ✨ O que tem

- 🏁 **Circuito** de pedra (CSG) sobre o oceano, com torres vermelhas (arco + treliça em X).
- 🚗 **Kart do jogador** refinado (chassi, bico, asas, sidepods, escapes, rodas com aro) e **piloto** com capacete, viseira, braços e volante.
- 🤖 **Rival verde** com IA simples seguindo a pista.
- 🚦 **Largada 3‑2‑1‑VAI!**, **cronômetro de volta** e **velocímetro** (HUD).
- 🟧 **Caixas de turbo** (boost) espalhadas pela pista.
- 🛫 **Rampa de salto**.
- 🌊 **Oceano** com ondas + normal map animado e espuma nas cristas (shader).
- 🏔️ **Montanhas** com relevo iluminado e neve no topo (shader por altura).
- ☁️ **Céu** panorâmico com nuvens; 🛩️ dirigível ao fundo.
- 🔊 **Som**: motor (varia com a velocidade), bipes da largada, power‑up.

## 🎮 Controles

| Ação | Teclas |
|------|--------|
| Acelerar | ↑ ou **W** |
| Ré | ↓ ou **S** |
| Virar | ← → ou **A** **D** |

O kart só vira em movimento. Se cair no mar, **renasce na largada**.

## ▶️ Como rodar

Abra o projeto no **Godot 4.6** e aperte **F5** (cena principal: `main_3d.tscn`).

## 🛠️ Regenerar as cenas

`main_3d.tscn`, `kart_3d.tscn` e `kart_npc.tscn` são **gerados por scripts Python** (para acertar a matemática das transformações, curvas e cores). Para alterar a pista ou os karts, edite os geradores e rode:

```bash
python3 tools/gen_kart.py     # gera kart_3d.tscn e kart_npc.tscn
python3 tools/gen_main3d.py   # gera main_3d.tscn
```

As texturas (céu, pedra, água, etc.) ficam em `assets/` e foram geradas com PIL/numpy.

## 📌 Pendências

- **Loop‑the‑loop**: ainda não — a física cinemática do kart não segue bem uma curva invertida a alta velocidade. Fica para uma próxima.
