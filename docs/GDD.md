# Ecoterra: Despertar — Documento de Design

## 1. Visão

**Gênero:** sobrevivência e coleção de monstros em mundo aberto, com progressão linear por cidades.
**Referências que comprovadamente funcionam no mercado** (e o que aproveitamos de cada uma):

| Referência | O que adotamos |
|---|---|
| Palworld | Monstros que **trabalham** em estações da base e produzem recursos; captura com esferas em combate de ação. |
| Minecraft | Coleta de blocos/recursos, construção em grade livre, ciclo dia/noite, cama como ponto de retorno, **modo Sandbox**. |
| Pokémon | Escolha do parceiro inicial, tipos com vantagens, evolução por nível, bestiário, desafio a "líderes" (capitães e ditadores). |
| ARK | Biomas com **perigos ambientais** que exigem equipamento, chefes guardiões com relíquias, tecnologia por nível. |
| Jogos idle / gacha mobile | Produção offline, expedições, presente diário, passe de temporada, missões diárias. |

**Público:** 10+ anos, jogadores casuais e mid-core de mobile. **Sessões:** 5–20 min, com metas curtas (missão atual sempre visível, com bússola).

## 2. Diferenciais (mecânicas próprias)

1. **Libertação, não captura.** O tema central é tirar coleiras. Ecos de cidades dominadas (*acorrentados*) têm +50 % de chance de vínculo. Jaulas abertas com pé de cabra liberam Ecos que se juntam a você. Cada ditador derrotado tem a coleira de seu Eco principal quebrada, e esse Eco vira **seu** (Ferro-Colosso, Umbra).
2. **Fogo que se espalha.** Queimar um espinho da Clareira Antiga queima toda a muralha: barreiras viram pequenos quebra-cabeças de ferramenta.
3. **O parceiro ajuda a coletar.** Um Eco com Corte, Mineração ou Coleta perto do jogador acelera a coleta (habilidade de trabalho × 0,5).
4. **Harmonia de equipe.** 3 ou mais tipos diferentes na equipe dão +10 % de dano: o jogador é incentivado a diversificar a coleção.
5. **Vínculo diário.** Carinho uma vez por dia e comida aumentam o vínculo (até +20 % de atributos). Cria um hábito diário sem punir quem falta.
6. **Variante Aurora (1/400).** Cores alternativas com brilho e +10 % de atributos: o "shiny" que mantém a caça interessante.
7. **Memórias.** 24 fragmentos escondidos pelos mapas contam a história de trás para frente. Coletar dá gemas e revela a reviravolta antes do diálogo oficial.
8. **Perigo como progressão.** Cada bioma tem um perigo (calor, frio, gás, lava, raios) e um item de proteção. O jogador pode visitar cedo para coletar, mas só explora de verdade depois de construir o equipamento.

## 3. História

**Ecoterra** é um planeta cuja vida nasce da memória do **Coração-Aurora**. As criaturas, os **Ecos**, são lembranças do mundo que ganharam corpo.

Há 300 anos, seis engenheiros lumarianos (a **Regência**) enfrentaram a **Fúria Cinza**: Ecos perto das cidades enlouqueciam. A **Sexta Regente** (o jogador) projetou um ressonador para acalmá-los: a **Coleira de Silêncio**, que deveria ser temporária. As coleiras funcionaram bem demais. Os outros Regentes as usaram para escravizar os Ecos, transformá-los em mão de obra e exército, e dividiram o mundo em cinco cidades.

A Sexta descobriu a verdade (fragmento f07): **a Fúria é a dor do Coração**, que a Regência drena toda noite para alimentar as cidades. Sem poder lutar sozinha, escondeu a **chave mestra das coleiras** na única mente que ninguém poderia ler, a sua própria, **apagada**. Selou-se no **Berço** e deixou **Lume**, uma IA feita das próprias memórias, para guiá-la no despertar.

| Ato | Região / Cidade | Ditador | Tema |
|---|---|---|---|
| 1 | Vale do Despertar → **Porto Ferrugem** | Barão Vorn (indústria, Ecos de metal) | Ganância, trabalho forçado |
| 2 | Terras Cinzentas → **Alta Cinza** | Imperatriz Sable (sombra, vigilância) | Medo, silêncio imposto |
| 3 | **Talassa**, a Cidade Submersa | Almirante Corin | Isolamento |
| 4 | **Fornalha Rubra** | Duquesa Ignis | Guerra |
| 5 | **Cidadela Aurora** | Grão-Regente Tessár (mentor da Sexta) | Controle "por amor" |

**Reviravoltas:**
- **Ato 1:** Vorn reconhece o jogador: *"Foi VOCÊ quem projetou as coleiras."*
- **Ato 2:** Sable revela que a Fúria é o grito do Coração e que a Sexta descobriu como abafá-lo.
- **Fim do Ato 2:** Lume revela que é a parte apagada da Sexta, *"sua culpa, sua coragem"*.
- **Ato 5 (planejado):** Tessár guarda a última memória. Para curar o Coração, a chave precisa voltar a ele, e o jogador escolhe entre manter as lembranças e libertar o mundo.

Os capitães têm arcos curtos de redenção: Rasha abre o mar, Brutus admite a culpa e Lin, ex-aluna da Sexta, entrega o código mestre. Assim as lutas têm peso emocional, não só números.

## 4. Laço de jogo

```
Coletar → Criar ferramentas → Construir base → Recrutar Ecos → Alocar Ecos no trabalho (produção offline)
   ↑                                                                              ↓
Novas receitas por nível ← XP ← Derrotar Alfas / Capitães ← Equipe mais forte ← Recursos melhores
```

- **Sessão curta (5 min):** recolher produção offline (com "dobrar por vídeo"), presente diário, uma missão diária, carinho nos Ecos.
- **Sessão média (20 min):** avançar uma missão da história (o objetivo sempre aparece no topo com bússola e distância).
- **Meta longa:** bestiário (31 espécies + variantes), 24 memórias, Trilha de 30 níveis, cidades.

## 5. Balanceamento (resumo, em `data/config.json`)

- XP do jogador: `25 × nível^1.45`. A história sozinha leva ao nível ~19, e coleta e combate completam até ~30 no fim do Ato 2.
- Atributos dos Ecos no estilo clássico: `((base×2 + talento×31) × nível/100 + 5) × vínculo × variante`.
- Dano: `((2L/5+2) × poder × A/D)/50 + 2`, com STAB ×1,2, tipo ×1,5/×0,67, crítico 8 % ×1,5 e Harmonia +10 %.
- Captura: `taxa × esfera × (1 − 0,8 × vida%) × fator de nível`, limitada a 3–97 %. Alfas ×0,35, acorrentados ×1,5.
- Estações: `taxa × (1 + 0,5 × (habilidade−1)) × (1 + 1,5 % × nível) × (1 + 3 % × vínculo)` por hora. Capacidade de 60 e teto offline de 8 h (motiva voltar).
- Modo fácil: a fome nunca mata (vida mínima 10). Desmaio não tira itens. Ecos desmaiados se recuperam sozinhos em 2 min.

Tudo é verificado por testes (`tests/unit/`), entre eles uma simulação completa da história (`test_full_story_simulation`) e a duração das lutas por nível (`test_fight_length_reasonable`).
