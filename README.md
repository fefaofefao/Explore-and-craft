# Ecoterra: Despertar

Jogo de **sobrevivência com monstros** para Android, em **3D estilizado**, com **mundo aberto e progressão linear**, mais um **modo Sandbox**. A base está pronta para **AdMob** (rewarded, intersticial e banner) e **Firebase** (Analytics, Remote Config, Crashlytics e Messaging).

> Você acorda num Berço lumariano depois de 300 anos. O mundo é Ecoterra, onde as criaturas, os **Ecos**, nascem da memória do planeta. Cinco Regentes acorrentaram os Ecos com as Coleiras de Silêncio. E quem projetou as coleiras... foi você.

APK pronto para instalar: [`dist/ecoterra-v1.0.0.apk`](dist/ecoterra-v1.0.0.apk) (arm64-v8a e armeabi-v7a, Android 7+).

## O que tem no jogo

| Pilar | Conteúdo |
|---|---|
| Mundo | 8 mapas 3D gerados por código (ilhas de 240 m): Bosque do Berço, Dunas de Âmbar, Picos de Geada, Porto Ferrugem (cidade 1), Pântano Lúgubre, Cânion Brasa, Ilhas Tempestade e Alta Cinza (cidade 2). Relevo com platôs e penhascos de rocha em estratos, terreno pintado (pinceladas, sombras frias, névoa de distância, sombras de nuvens), rochedos de paisagem, **capim alto** que se corta com golpes e volta a crescer, **vento global que muda de direção** (ondas de rajada correndo pela grama, árvores, rastros de ar e folhas voando) e grama que se abre quando você, seu Eco ou os selvagens passam. Ciclo dia/noite, água animada, partículas por bioma. |
| Progressão linear | 35 missões em 2 atos. No começo há 3 mapas; cada um guarda uma relíquia protegida por um Alfa e por uma barreira que exige um item construído (tocha, lente solar, picareta de ferro). As 3 relíquias formam o **Núcleo da Ponte**, que leva à **cidade 1**. Lá você liberta 5 jaulas, vence 3 capitães e o **Barão Vorn**. O Ato 2 repete a estrutura com perigos novos. Os Atos 3 a 5 já estão anunciados no jogo. |
| Ecos | 31 espécies e 8 chefes, 8 tipos com tabela de vantagens, 31 habilidades com **visual próprio** (lâminas de folha, bolas de fogo, jatos d'água, estilhaços, raios do céu, pedras em arco, chicote de vinha, investida, presas, pancada sísmica, garras, esporos, espinhos que brotam, anel de fogo, erupção, onda, nevasca, tempestade, terremoto, pesadelo, pilares de luz…) e animações de golpe com antecipação → impacto → recuperação para cada formato de corpo, evolução, talento, **Variante Aurora** (1/400), vínculo (carinho e comida) e Harmonia de equipe. |
| Sobrevivência fácil | Fome que nunca mata, perigos por bioma (calor, frio, gás, lava, raios) com equipamento de proteção, cama como ponto de retorno, dormir pula a noite. |
| Construção | 23 peças em grade (fundação, parede, porta, janela, telhado...), estações de criação (bancada, fornalha, forja, fogueira, bancada arcana), **Fonte de Cura** e **estações de trabalho**: você aloca um Eco e ele produz recursos, **inclusive offline**. |
| Combate | Em tempo real: o parceiro luta, você usa as 2 habilidades mais fortes (ou o modo Auto) e também golpeia em **combo de 3 golpes**. Ecos selvagens focam o seu Eco e derrubam o treinador com facilidade; hordas de 3–4. Barra da equipe na tela para trocar o companheiro com um toque. Captura com **Redes de Vínculo** (3 tipos). |
| Equipamento | Uma ferramenta/arma de cada por vez, uso automático perto do recurso, **durabilidade** e **reparo** (metade dos materiais da receita, proporcional ao desgaste) pela mochila ou pela tela de criação. |
| Retenção | Presente diário de 7 dias, 3 missões diárias com bônus, Trilha (passe) de 30 níveis, marcos do Bestiário, expedições idle, produção offline com resumo, 24 fragmentos de memória colecionáveis e lembretes de retorno. |
| Monetização | Rewarded opcional (8 pontos, com recarga e teto), intersticial com regras rígidas (nunca nos primeiros 10 min, nunca para pagantes), 7 produtos IAP (Sem Anúncios, Pacote do Desperto em 72 h, gemas, Trilha Premium). Detalhes e projeção em [docs/MONETIZACAO.md](docs/MONETIZACAO.md). |
| Sandbox | Recursos infinitos, tudo liberado, sem fome, modo pacífico opcional. |
| Idiomas | Português (BR) e inglês, com detecção automática. |

Telas: [docs/screenshots/](docs/screenshots/). História completa e design: [docs/GDD.md](docs/GDD.md).

## Tecnologia

- **Godot 4.5.1** (GDScript), renderer **GL Compatibility**, que roda na grande maioria dos Android com OpenGL ES 3.
- Malhas, monstros, terreno e efeitos são **100% procedurais**. Não há modelos 3D de terceiros, o que mantém o APK leve e o visual consistente.
- Shaders próprios (`assets/shaders/`):
  - **terreno:** mistura grama, terra, areia molhada, rocha estratificada e neve por altura, inclinação e ruído;
  - **água:** profundidade lida do relevo, espuma na costa, cáusticas e reflexo do céu, além de lava;
  - **folhagem:** vento por vértice;
  - **grama:** tufos densos com a cor do chão, em blocos com alcance de visibilidade;
  - **toon:** usado nos Ecos e nos personagens, com sombras frias, brilho anime e luz de borda;
  - **minimapa.**
- Ecos com olhos anime (íris, pupila, dois brilhos, cílios), piscar, bochechas, boca e sombra no chão. Personagens humanos em proporção chibi, com cabelo em camadas e cachecol animado.
- Interface com painéis e botões texturizados, ícones vetoriais, minimapa giratório, vinheta e logo (`tools/gen_textures.py`).
- Ícones (`tools/gen_icons.py`) e áudio (`tools/gen_audio.py`) são gerados por script. Fontes: Nunito (OFL) e DejaVu (licença livre).
- Conteúdo e balanceamento ficam em `data/*.json`, gerados por `tools/gen_data/` com validação de referências cruzadas.

```
data/               conteúdo (gerado): espécies, itens, receitas, mapas, missões, diálogos, economia, anúncios, remote config
src/core            GameData (dados), Loc (idiomas)
src/logic           regras puras e testáveis: GameState, Inventory, Craft/Build/Work/Quest/Retention/AdPolicy/Expedition/Survival/Combat/Monster, SaveSystem
src/world           WorldGen (relevo determinístico), TerrainBuilder, SkyEnv, MeshLib, ResourceNode, Structure, World (orquestra o mapa)
src/actors          Player, CameraRig, MonsterActor (IA), MonsterModel (modelo 3D procedural), HumanoidModel, Npc
src/ui              Hud, GameMenu, TouchControls, Portrait, UiTheme, Widgets
src/services        Game (estado/autosave/eventos), Ads (AdMob), Firebase, Billing (Google Play), Audio, Notifications
src/debug           Autopilot: screenshots, smoke test e medição de desempenho dentro do jogo real
tests/              110 testes unitários (2.500+ asserções)
tools/              geradores (dados, ícones, áudio), verificação de scripts, testes
```

## Rodar, testar e exportar

```bash
godot --path .                                        # jogar no PC (WASD, mouse direito gira, E ação, Q esfera, 1/2 habilidades, B construir, I menu)
./tools/check_scripts.sh                              # erros de parse em todos os scripts
./tools/run_tests.sh                                  # testes unitários (falha também em SCRIPT ERROR)
godot --headless --path . -- --autopilot smoke        # integração: joga história, captura, constrói, viaja, vence capitã, abre jaulas, salva
xvfb-run godot --path . --rendering-driver opengl3 -- --autopilot shots docs/screenshots   # screenshots
python3 tools/gen_data/gen_data.py                    # regenera data/*.json (valida referências)
python3 tools/gen_icons.py && python3 tools/gen_audio.py

# APK (template pronto, sem gradle)
godot --headless --path . --export-release "Android APK (release)" build/ecoterra-release.apk
```

Para publicar na **Google Play** (AAB com gradle, AdMob e Firebase reais, keystore de produção), siga [docs/PUBLICACAO.md](docs/PUBLICACAO.md). O que ainda depende de você (contas, IDs e chaves) está em [PENDENCIAS.md](PENDENCIAS.md).
