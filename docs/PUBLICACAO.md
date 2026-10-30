# Publicação na Google Play (AdMob + Firebase)

O APK em `dist/` foi exportado com o **template pronto** do Godot, sem gradle. Neste ambiente o `dl.google.com` (Android SDK) estava bloqueado. Ele roda o jogo inteiro; anúncios e compras usam o **modo simulado** (tela "[Anúncio de teste]"; compras só são simuladas em build de depuração). Para publicar com anúncios e analytics reais:

## 1. Ferramentas

1. Instale o **Godot 4.5.1** e os *export templates* da mesma versão.
2. Instale o **Android Studio** (SDK Platform 35, Build-Tools 35, Platform-Tools) e um **JDK 17**.
3. Godot → Editor Settings → Export → Android: informe o SDK e o JDK.
4. Projeto → **Instalar Template de Build Android** (cria `android/build`).

## 2. Keystore de produção (upload key)

```bash
keytool -genkeypair -v -keystore ecoterra-upload.keystore -alias ecoterra -keyalg RSA -keysize 2048 -validity 10000
```

Guarde o arquivo e as senhas fora do repositório. Ative o **Play App Signing** no Console: assim, se a chave de upload for perdida, você pode redefini-la. No preset **"Android AAB (Play Store, gradle)"**, preencha `keystore/release*` ou use as variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` e `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.

## 3. AdMob

1. Crie o app no AdMob e 3 blocos: **Banner**, **Intersticial** e **Premiado** (rewarded).
2. Troque os IDs **de teste** em `tools/gen_data/content_meta.py` (`ADS`), rode `python3 tools/gen_data/gen_data.py` e mantenha `test_mode` falso na produção. Esse é o **único** lugar com IDs.
3. Instale um plugin Android de AdMob para Godot 4 (por exemplo, [godot-android-admob-plugin](https://github.com/cengiz-pz/godot-android-admob-plugin) ou o da Poing Studios) e ative-o no preset gradle. O adaptador `src/services/ads.gd` procura o singleton **`AdmobPlugin`** e chama `initialize`, `load_rewarded_ad`, `show_rewarded_ad`, `load_interstitial_ad` e `show_interstitial_ad`. Se o plugin escolhido usar outros nomes, ajuste **só esse arquivo**.
4. Inclua o **App ID** no `AndroidManifest` (o plugin faz isso via configuração) e a permissão `com.google.android.gms.permission.AD_ID`.
5. **Consentimento (UMP/GDPR/LGPD):** configure a mensagem de privacidade no AdMob. O jogo mostra o aviso de privacidade antes de inicializar os anúncios (`main.gd → _ask_consent`).
6. Publique o `app-ads.txt` no site do desenvolvedor.

## 4. Firebase

1. Crie o projeto no console do Firebase e adicione o app Android `com.ecoterra.despertar`, com o SHA-1/SHA-256 da chave de upload e da chave de assinatura do Play.
2. Baixe o `google-services.json` para `android/build/`.
3. Ative **Analytics**, **Crashlytics**, **Remote Config** (importe `data/remote_config_defaults.json` como valores padrão) e **Cloud Messaging**.
4. Instale um plugin Firebase para Godot 4 (Android). O adaptador `src/services/firebase.gd` procura o singleton **`GodotFirebaseAndroid`** e chama `analytics_log_event`, `analytics_set_user_property`, `crashlytics_log`, `remote_config_set_defaults`, `remote_config_fetch_and_activate` e `remote_config_get_string`. Se os nomes forem outros, ajuste só esse arquivo.
5. Os 30 eventos do funil estão em `data/analytics_events.json`. Marque `tutorial_complete`, `city_liberated` e `iap_purchase` como conversões.

## 5. Compras (Google Play Billing)

1. Ative o plugin oficial **GodotGooglePlayBilling** no preset gradle (`src/services/billing.gd` já usa `startConnection`, `queryProductDetails`, `purchase`, `acknowledgePurchase` e `consumePurchase`).
2. No Play Console → Monetizar → Produtos, crie com **os mesmos IDs**: `remove_ads`, `starter_pack`, `season_pass` (não consumíveis) e `gems_80`, `gems_500`, `gems_1200`, `gems_2600` (consumíveis).
3. Recomendado: validar recibos no servidor (Cloud Functions + Play Developer API) antes de escalar.

## 6. Exportar o AAB

```bash
godot --headless --path . --export-release "Android AAB (Play Store, gradle)" build/ecoterra-release.aab
```

`min_sdk` 24 e `target_sdk` 35 (exigência atual da Play). A cada atualização, incremente `version/code` nos 3 presets.

## 7. Ficha da Play Store

- **Ícone 512×512:** `assets/icon_square.png`. **Arte de destaque 1024×500:** `docs/play_store/feature_graphic.png`.
- **Capturas de tela:** `docs/screenshots/*.png` (1280×720, paisagem).
- **Classificação indicativa:** fantasia leve, sem sangue (questionário IARC → Livre/10+).
- **Segurança dos dados:** coleta de identificadores de dispositivo e dados de uso (AdMob e Firebase Analytics) para publicidade e análise; compras pelo Google Play. Nenhum dado pessoal é coletado pelo jogo em si; os saves ficam no aparelho.
- **Política de privacidade:** obrigatória (anúncios + analytics). Publique uma página com o conteúdo do aviso de privacidade do jogo.
- **Anúncios:** marque "Contém anúncios". Público-alvo: 13+ (para não entrar nas regras de "Famílias"; se quiser 10+, use anúncios certificados para famílias).

**Descrição curta (PT):** Acorde num mundo de monstros, recrute Ecos, construa sua base e liberte as cidades!
**Descrição curta (EN):** Wake in a world of monsters, bond with Echoes, build your base and free the cities!
