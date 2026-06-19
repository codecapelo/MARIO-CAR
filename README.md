# MarioCard 🏎️

Jogo de kart **3D** feito em **Godot 4.6**, no estilo Mario Kart: uma **ponte de pedra sobre o oceano**, montanhas nevadas ao fundo, rivais, turbo e **drift**.

> Projeto de estudo do Raul (médico, iniciante em programação). Código e comentários em **português**.

## ✨ O que tem

- 🧭 **Fluxo completo de jogo**: Menu → Corrida → Resultado, com **menu de pausa** e **transições com fade**.
- 🏁 **Corrida de verdade**: número de voltas configurável, **posição em tempo real** (1º/Nº), **vencedor** e **tela de resultado** com tempos por volta e **recorde salvo em disco**.
- 🏎️ **Física de kart arcade**: aceleração com "peso", direção que afina em alta velocidade, **inércia lateral** e — o destaque — **DRIFT/derrapagem com mini-turbo** (segura o drift na curva, acumula carga e ganha um turbinho ao soltar).
- 🤖 **4 rivais** com IA "elástica" (rubber-banding): aceleram quando ficam para trás e aliviam quando estão na frente — a corrida fica sempre disputada. Cada rival tem **nome e cor**, **bate e sai da trajetória** (a trombada empurra de verdade) e **usa itens**.
- 🎁 **Itens estilo Mario Kart**: as caixas "?" dão um item **aleatório, pesado pela posição** (quem está atrás ganha itens melhores). Você **segura** e usa quando quiser (tecla **E**): **turbo, estrela, raio, banana** (solta atrás) e **casco** (atira pra frente). Os rivais também usam.
- 🛣️ **3 pistas** com climas diferentes (Ponte do Oceano, Baía do Pôr do Sol, Ilha da Lua), **asfalto de corrida**, **linha central** e **zebras** vermelho/branco nas curvas.
- ⚙️ **Menu de opções**: voltas, **dificuldade** (Fácil/Normal/Difícil), **escolha da pista**, **cor do kart** e tela "como jogar".
- 🏆 **Acabamento de corrida**: contagem **3-2-1** com "pulo", aviso de **ÚLTIMA VOLTA**, alerta de **CONTRAMÃO** e **classificação ao vivo** com os nomes.
- 🎥 **Câmera viva**: persegue o kart, **abre o campo de visão** com a velocidade e **treme** no turbo.
- ✨ **VFX**: chamas de turbo, fumaça do escapamento, **poeira/faíscas no drift** (mudam de cor com a carga), flash ao pegar item, **rodas girando**, corpo inclinando nas curvas, **SSAO + glow + névoa** e sombras de qualidade.
- 🔊 **Áudio completo**: **música** em loop, barramentos (Master/Música/Efeitos) com volumes ajustáveis, motor dinâmico (varia com a aceleração), sons de turbo, drift, largada e **fanfarra** de vitória; rival e caixas com **áudio espacial 3D**.
- 🗺️ **HUD profissional**: velocímetro, voltas X/Y, posição, cronômetro + recorde, **barra de turbo** e **minimapa** desenhado a partir da pista.
- 🌊🏔️☁️ Oceano, montanhas e céu por shader; dirigível ao fundo; 🛫 rampa de salto; 🟧 caixas de turbo.

## 🎮 Controles

| Ação | Teclado | Controle (gamepad) |
|------|---------|--------------------|
| Acelerar | ↑ / **W** | A / gatilho direito (R2) |
| Ré / freio | ↓ / **S** | B / gatilho esquerdo (L2) |
| Virar | ← → / **A D** | analógico esquerdo |
| **Drift** | **Shift** | R1 (ombro direito) |
| Freio de mão | **Espaço** | X |
| **Usar item** | **E** | L1 (ombro esquerdo) |
| Pausar | **Esc** | Start |
| Reiniciar | **R** | Y |

O kart só vira em movimento. Caiu no mar? **Renasce** no último ponto seguro com uma pequena penalidade.

## ▶️ Como rodar

Abra o projeto no **Godot 4.6** e aperte **F5**. O jogo começa no **menu** (`menu.tscn`).

## 🛠️ Regenerar as cenas e os sons

As cenas 3D e os áudios procedurais são **gerados por scripts Python** (para acertar a matemática e não depender de downloads). Os caminhos agora são **relativos** (funcionam em qualquer pasta):

```bash
python3 tools/gen_texturas.py # gera assets/asfalto.png (textura da pista)
python3 tools/gen_kart.py     # gera kart_3d.tscn e kart_npc.tscn
python3 tools/gen_main3d.py   # gera main_3d.tscn, pista2.tscn e pista3.tscn
python3 tools/gen_audio.py    # gera assets/musica_corrida.wav, whoosh, drift, fanfarra
```

> ⚠️ **Não** são gerados por Python (edite à mão / pela UI do Godot): `project.godot` (autoloads, mapa de entrada, áudio), `menu.tscn`, `resultado.tscn`, `tema.tres` e `item_box.tscn`.

As texturas (céu, pedra, água, etc.) ficam em `assets/`.

## 🧩 Como o código se organiza

- **Autoloads** (nós globais que vivem entre as cenas): `jogo.gd` (estado do jogo, voltas, recorde, volumes) e `transicao.gd` (fade).
- `pista.gd` (no nó **Main**): o "juiz" — largada, contagem de voltas pela curva, posição e fim da corrida.
- `kart_3d.gd`: a física e o drift do kart do jogador. `npc.gd`: a IA dos rivais.
- `hud.gd`: tela da corrida + pausa. `camera_perseguidora.gd`: a câmera. `minimapa.gd`: o minimapa.
- `menu.gd` / `resultado.gd`: as telas. `item_box.gd`: as caixas de turbo.

## 📌 Pendências / ideias futuras

- **Loop‑the‑loop**: a física cinemática ainda não segura bem uma curva invertida a alta velocidade.
- **Áudio**: os sons ainda são gerados por script (`tools/gen_audio.py`). Trocar por samples reais elevaria bastante a qualidade — ainda na lista.
- **Casco que persegue** (vermelho), mais pistas e modelos 3D importados (.glb) no lugar dos montados por script.
