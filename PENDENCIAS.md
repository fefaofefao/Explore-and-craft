# Pendências (dependem de contas, chaves ou de um ambiente com Android SDK)

| # | Item | Por quê | Como |
|---|---|---|---|
| 1 | IDs reais do AdMob | O jogo usa os IDs **de teste** oficiais do Google | `docs/PUBLICACAO.md` §3 |
| 2 | Plugins AdMob, Firebase e Billing no build gradle | O APK atual foi feito sem gradle (`dl.google.com` estava bloqueado aqui), então anúncios e compras são **simulados** | §3–5. Os adaptadores já estão prontos em `src/services/` |
| 3 | `google-services.json` | Precisa do seu projeto Firebase | §4 |
| 4 | Keystore de produção e AAB | O APK de `dist/` está assinado com chave de **depuração** (só para testes/sideload) | §2 e §6 |
| 5 | Produtos IAP no Play Console | IDs já definidos no código | §5 |
| 6 | Política de privacidade (URL) | Exigida pela Play e pelo AdMob | §7 |
| 7 | Teste em aparelhos reais | Aqui só houve testes no PC (headless e renderizado); em aparelho, conferir desempenho em celulares de entrada (qualidade "Desempenho") | instalar `dist/ecoterra-v1.0.0.apk` |
| 8 | Revisão nativa do inglês | Textos EN escritos junto com o PT | `tools/gen_data/content_*.py` |
| 9 | Atos 3–5 | Anunciados no jogo (live ops); a estrutura de dados permite adicionar mapas, cidades e missões só em `tools/gen_data/` | `content_world.py` |
| 10 | Validação de recibos no servidor | Recomendado antes de escalar a monetização | Cloud Functions + Play Developer API |

Observações honestas:
- Os nomes dos métodos dos plugins AdMob e Firebase variam entre autores. Os adaptadores seguem a API mais comum, mas confira com a versão que instalar (ajuste só `ads.gd` / `firebase.gd`).
- Sem o plugin de Billing, compras em build **release** mostram "Loja indisponível" (não dão itens grátis). Em build de **depuração** elas são simuladas para testar o fluxo.
