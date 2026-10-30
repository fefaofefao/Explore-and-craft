# Monetização, retenção e projeção de receita

## 1. Princípios

1. **Anúncio é escolha, não punição.** O formato principal é o *rewarded* (o jogador pede o vídeo em troca de algo). Dados de mercado associam quem assiste rewarded na primeira semana a uma retenção D30 muito maior[^playio].
2. **Intersticial só em pausas naturais** (após batalha de capitão e ao viajar entre mapas), **nunca** nos primeiros 10 min de jogo, com intervalo mínimo de 5 min, teto de 6 por dia e **nunca para quem já comprou qualquer coisa**.
3. **Sem paywall de progresso.** Toda a história pode ser concluída sem gastar. Dinheiro acelera, dá conforto e cosméticos.
4. **Tudo ajustável remotamente.** Intervalos, tetos e multiplicadores estão no **Firebase Remote Config** (`data/remote_config_defaults.json`) para testes A/B sem atualizar o app.

## 2. Pontos de anúncio (AdMob)

| Placement | Recompensa | Recarga |
|---|---|---|
| `offline_double` | Dobra a produção offline das estações | a cada retorno |
| `revive_here` | Revive no local, sem voltar à cama | — |
| `daily_bonus` | Presente diário ×2 | 1×/dia |
| `free_spheres` | 3 Esferas de Vínculo | 4 h |
| `free_gems` | 5 gemas | 6 h |
| `xp_boost` | XP ×2 por 30 min | 1 h |
| `instant_harvest` | 1 h de produção instantânea | 2 h |
| `expedition_rush` | Conclui a expedição na hora | 1 h |

Intersticial: `trainer` (após vencer capitão) e `travel` (ao trocar de mapa). Banner: desligado por padrão (`banner_in_menus=false`); pode ser ligado nos menus via Remote Config.

## 3. Compras (Google Play Billing)

| Produto | Preço | Conteúdo |
|---|---|---|
| `starter_pack` | US$ 1,99 | 300 gemas, 10 Esferas Grandes, 3 Sementes Reviver, Lumeflor Variante Aurora. **Só nas primeiras 72 h** (urgência). |
| `remove_ads` | US$ 3,99 | Remove intersticial e banner, **rewarded vira instantâneo** e +50 gemas. |
| `season_pass` | US$ 4,99 | Trilha Premium: gemas, Esferas Aurora e Ecos raros variantes (Lumeflor, Coralume, Vulcanix). |
| `gems_80/500/1200/2600` | 0,99 / 4,99 / 9,99 / 19,99 | Bônus crescente (+25 %, +50 %, +62 %). |

Gastos com gemas: Esfera Aurora, +10 vagas na reserva, +1 vaga de expedição, XP ×2, colheita instantânea, tônicos fortes.

## 4. Sistemas de retenção

| Sistema | Gancho | Frequência |
|---|---|---|
| Produção offline + resumo "Enquanto você estava fora" | Teto de 8 h e armazém de 60 itens: voltar 2–3× por dia | horas |
| Expedições (Ecos da reserva) | 1 h / 4 h / 8 h, voltam com recursos e às vezes gemas | horas |
| Presente diário (7 dias) | Dia 7 com Esfera Aurora + 30 gemas; o ciclo não reseta ao faltar (sem frustração) | diária |
| 3 missões diárias + bônus de todas | Sorteadas por data, alimentam a Trilha | diária |
| Carinho nos Ecos | Vínculo +20 % de atributos | diária |
| Trilha (passe) de 30 níveis | Temporadas de 42 dias | semanal |
| Bestiário com marcos | 7 marcos de 3 a 31 espécies | contínua |
| Variante Aurora 1/400 | Caça | contínua |
| Memórias (24) | História revelada aos poucos | contínua |
| História por atos | Cliffhangers e "Atos 3–5 em breve" no mapa | atualizações |
| Lembretes locais | Produção cheia, expedição pronta, presente do dia seguinte (`Notifications.plan`) | — |

Funil mapeado no **Firebase Analytics** com 30 eventos (`data/analytics_events.json`): `tutorial_begin → starter_chosen → quest_complete(q01..q09) → tutorial_complete → ... → city_liberated`, além de `ad_*`, `iap_*`, `capture_*`, `daily_*`, `pass_tier`, `player_death` etc.

## 5. Benchmarks de mercado

- Mediana de D1 ≈ 22 % e D7 ≈ 4 %; o top 10 % chega a D1 ≈ 40 % e D7 ≈ 12 % (GameAnalytics, dados de 2025)[^ga].
- RPG: D1 ≈ 30,5 %, D7 ≈ 9,9 %, D30 ≈ 3,5 %[^seg].
- Em 2025, RPGs de sobrevivência foram o subgênero de RPG mobile que mais cresceu (+81 %, US$ 159 mi), e títulos de "sobrevivência" lideram o faturamento geral[^st]. O gênero de coleção de monstros tem lançamentos recentes de sucesso, como *Monster Taming: STAR DIVE*, top 5 em faturamento na Google Play em 5 dias[^inven].
- eCPM de rewarded em torno de US$ 16–20 em média global (bem menor em LATAM/Ásia)[^playio2].

## 6. Projeção (cenário base, a validar em *soft launch*)

Premissas (conservadoras para Brasil + global, mix de tráfego Tier 2/3):

| Métrica | Valor |
|---|---|
| Instalações/mês | 100.000 (≈ 3.300/dia) |
| Retenção-alvo | D1 35 %, D7 12 %, D30 5 % → ~6,5 dias ativos por instalação |
| DAU em regime | ≈ 3.300 × 6,5 ≈ **21.500** |
| Rewarded | 2,0 vídeos/DAU × eCPM US$ 6 = US$ 0,012/DAU |
| Intersticial | 0,8 imp/DAU × eCPM US$ 3 = US$ 0,0024/DAU |
| IAP | 2 % dos usuários mensais pagam, ARPPU US$ 7 → ≈ US$ 0,018/DAU |
| **ARPDAU total** | **≈ US$ 0,032** |
| **Receita bruta/mês** | ≈ 21.500 × 30 × 0,032 ≈ **US$ 20.600** |
| Líquido (taxa Google de 15 % sobre IAP, AdMob já líquido) | ≈ **US$ 18.000/mês** |
| **LTV por instalação** | ≈ 0,032 × 6,5 ≈ **US$ 0,21** |

**Rentabilidade:** com tráfego orgânico (ASO, comunidade, redes sociais), a margem é quase toda lucro. Com mídia paga, o jogo é rentável se o **CPI ficar abaixo do LTV** (≈ US$ 0,21 no cenário base, até ≈ US$ 0,45 no cenário otimista, com D7 de 15 % e 3 % de pagantes). Plano:

1. *Soft launch* em 1–2 países de CPI baixo (ex.: Filipinas e Brasil) por 2–4 semanas.
2. Metas para escalar: D1 ≥ 35 %, D7 ≥ 12 %, ARPDAU ≥ US$ 0,03.
3. Ajustar via Remote Config: frequência de intersticial, recompensas de vídeo, duração da janela da oferta inicial e multiplicadores de XP/drop em eventos.
4. Lançar o Ato 3 em 6–8 semanas (conteúdo procedural barato: novos biomas e cidades a partir de `data/`).

[^ga]: GameAnalytics — Mobile gaming benchmarks: https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks
[^seg]: Segwise — Mobile Game Retention Benchmarks by Genre: https://segwise.ai/blog/mobile-gaming-app-user-retention-strategies.md
[^st]: Spieltimes — Mobile RPGs 2025: https://www.spieltimes.io/gaming/why-mobile-rpgs-still-dominate-gaming-after-generating-usd9-8-billion-in-2025/ · Sensor Tower via Outlook Respawn: https://respawn.outlookindia.com/gaming/gaming-news/mobile-games-82-billion-revenue-2025-sensor-tower-report
[^inven]: Inven Global — Monster Taming: STAR DIVE: https://www.invenglobal.com/articles/21095/monster-taming-star-dive-hits-no-5-in-google-play-revenue-within-5-days-of-launch
[^playio]: Playio — Impact of rewarded ads on user retention: https://blog.playio.co/impact-of-rewarded-ads-on-user-retention
[^playio2]: Playio — Rewarded ad benchmarks 2026: https://blog.playio.co/rewarded-ad-benchmarks-2026
