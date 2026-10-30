# -*- coding: utf-8 -*-
"""Balanceamento, economia, anúncios, compras, retenção (diário, passe, missões diárias) e Remote Config."""
from content_monsters import L

CONFIG = {
    "version": 1,
    "player": {"base_hp": 100, "hp_per_level": 6, "hunger_max": 100, "hunger_drain_per_min": 1.1,
               "starve_dps": 0.5, "starve_min_hp": 10, "regen_per_sec_fed": 0.6, "fed_threshold": 50,
               "move_speed": 6.5, "sprint_mult": 1.55, "jump": 7.0, "attack_cd": 0.55, "attack_base": 4,
               "gather_base": 1.0, "interact_range": 3.2, "max_level": 60},
    "xp": {"player_base": 25, "player_exp": 1.45, "player_kill_share": 0.35, "monster_base": 12, "monster_exp": 1.7,
           "kill_xp_mult": 6, "share_reserve": 0.5, "capture_xp_mult": 4},
    "world": {"day_seconds": 840, "night_seconds": 360, "night_aggro_mult": 1.5, "night_level_bonus": 2,
              "respawn_wild_sec": 45, "aggro_range": 11, "leash_range": 32, "despawn_range": 90},
    "combat": {"crit_chance": 0.08, "crit_mult": 1.5, "stab": 1.2, "harmony_bonus": 0.10, "harmony_min_types": 3,
               "basic_power": 25, "basic_cd": 1.2, "player_vs_monster_mult": 0.6, "boss_hp_mult": 3.0, "trainer_hp_mult": 1.2,
               "monster_contact_dmg": 0.35, "faint_rest_sec": 120},
    "capture": {"min_chance": 0.03, "max_chance": 0.97, "hp_weight": 0.8, "level_penalty": 0.025, "boss_mult": 0.35,
                "aurora_variant_chance": 0.0025, "collar_bonus": 1.5, "max_party": 5, "box_start": 40, "box_max": 200},
    "bond": {"max_level": 10, "xp_per_level": 100, "pet_xp": 25, "feed_xp": 15, "battle_xp": 4, "stat_bonus_per_level": 0.02},
    "work": {"skill_mult": 0.5, "level_mult": 0.015, "offline_cap_hours": 8, "station_capacity": 60, "bond_mult": 0.03},
    "expedition": {"durations": [3600, 14400, 28800], "base_rolls": [3, 9, 18], "fragment_chance": [0.0, 0.05, 0.12],
                   "gem_chance": [0.1, 0.3, 0.6], "slots": 2, "slots_max": 4},
    "build": {"cell": 2.0, "max_pieces": 400, "max_slope": 1.4, "refund": 0.5},
    "save": {"autosave_sec": 30},
    "sandbox": {"start_items": 999, "no_hunger": True, "all_recipes": True, "all_maps": True, "peaceful_toggle": True},
}

ECONOMY = {
    "start": {"coins": 50, "gems": 20},
    # Loja (moedas = soft, gemas = premium)
    "shop": [
        {"id": "s_esfera5", "item": "esfera", "n": 5, "price": {"coins": 40}},
        {"id": "s_esfera_g3", "item": "esfera_grande", "n": 3, "price": {"coins": 140}, "lvl": 6},
        {"id": "s_tonico5", "item": "tonico", "n": 5, "price": {"coins": 50}},
        {"id": "s_reviver", "item": "reviver", "n": 1, "price": {"coins": 90}},
        {"id": "s_carne5", "item": "carne_assada", "n": 5, "price": {"coins": 40}},
        {"id": "s_aurora", "item": "esfera_aurora", "n": 1, "price": {"gems": 30}},
        {"id": "s_aurora5", "item": "esfera_aurora", "n": 5, "price": {"gems": 130}},
        {"id": "s_tonico_f10", "item": "tonico_forte", "n": 10, "price": {"gems": 25}},
        {"id": "s_box10", "special": "box_slots", "n": 10, "price": {"gems": 40}},
        {"id": "s_exp_slot", "special": "expedition_slot", "n": 1, "price": {"gems": 120}},
        {"id": "s_boost_xp", "special": "xp_boost", "n": 1800, "price": {"gems": 15}},
        {"id": "s_harvest", "special": "instant_harvest", "n": 7200, "price": {"gems": 10}},
    ],
    # preço de venda = value do item; compra de recursos básicos no mercado da cidade
    "market_buy_mult": 3,
    "sell_mult": 1,
}

IAP = {
    "products": [
        {"id": "remove_ads", "type": "nonconsumable", "price_usd": 3.99, "name": L("Sem Anúncios", "No Ads"),
         "desc": L("Remove intersticiais e banners para sempre. Recompensas de vídeo continuam opcionais (e passam a ser instantâneas).",
                   "Removes interstitials and banners forever. Video rewards stay optional (and become instant)."),
         "grants": {"no_ads": True, "gems": 50}},
        {"id": "starter_pack", "type": "nonconsumable", "price_usd": 1.99, "name": L("Pacote do Desperto", "Awakened Pack"),
         "desc": L("300 gemas, 10 Esferas Grandes, 3 Sementes Reviver e Lumeflor Variante Aurora. Só nas primeiras 72 h!",
                   "300 gems, 10 Great Spheres, 3 Revive Seeds and an Aurora Variant Lumeflor. First 72 h only!"),
         "grants": {"gems": 300, "items": {"esfera_grande": 10, "reviver": 3}, "monster": ["lumeflor", 8, True]}, "window_hours": 72},
        {"id": "gems_80", "type": "consumable", "price_usd": 0.99, "name": L("Punhado de Gemas", "Handful of Gems"), "desc": L("80 gemas", "80 gems"), "grants": {"gems": 80}},
        {"id": "gems_500", "type": "consumable", "price_usd": 4.99, "name": L("Bolsa de Gemas", "Pouch of Gems"), "desc": L("500 gemas (+25%)", "500 gems (+25%)"), "grants": {"gems": 500}},
        {"id": "gems_1200", "type": "consumable", "price_usd": 9.99, "name": L("Baú de Gemas", "Chest of Gems"), "desc": L("1200 gemas (+50%)", "1200 gems (+50%)"), "grants": {"gems": 1200}},
        {"id": "gems_2600", "type": "consumable", "price_usd": 19.99, "name": L("Tesouro de Gemas", "Gem Hoard"), "desc": L("2600 gemas (+62%)", "2600 gems (+62%)"), "grants": {"gems": 2600}},
        {"id": "season_pass", "type": "nonconsumable", "price_usd": 4.99, "name": L("Trilha Premium", "Premium Trail"),
         "desc": L("Libera a trilha premium da temporada: gemas, Esferas Aurora, skins e Ecos raros.",
                   "Unlocks the season's premium trail: gems, Aurora Spheres, skins and rare Echoes."),
         "grants": {"premium_pass": True}},
    ],
}

ADS = {
    # IDs de TESTE oficiais do Google. Troque pelos seus em data/ads.json antes de publicar (ver docs/PUBLICACAO.md)
    "app_id": "ca-app-pub-3940256099942544~3347511713",
    "units": {"banner": "ca-app-pub-3940256099942544/6300978111",
              "interstitial": "ca-app-pub-3940256099942544/1033173712",
              "rewarded": "ca-app-pub-3940256099942544/5224354917"},
    "test_mode": True,
}

# Política de anúncios (padrões; sobrescritos pelo Remote Config)
AD_POLICY = {
    "interstitial_enabled": True, "interstitial_first_after_sec": 600, "interstitial_min_interval_sec": 300,
    "interstitial_daily_cap": 6, "interstitial_skip_payers": True,
    "banner_in_menus": False,
    "rewarded_daily_cap": 25,
    "rewarded": {
        "offline_double": {"cooldown": 0},
        "revive_here": {"cooldown": 0},
        "free_spheres": {"cooldown": 14400, "items": {"esfera": 3}},
        "free_gems": {"cooldown": 21600, "gems": 5},
        "xp_boost": {"cooldown": 3600, "seconds": 1800},
        "daily_bonus": {"cooldown": 0},
        "instant_harvest": {"cooldown": 7200, "seconds": 3600},
        "expedition_rush": {"cooldown": 3600},
    },
}

DAILY_LOGIN = [
    {"coins": 100}, {"items": {"esfera": 5}}, {"gems": 10}, {"items": {"tonico": 5}},
    {"coins": 300}, {"items": {"esfera_grande": 3}}, {"gems": 30, "items": {"esfera_aurora": 1}},
]

# Missões diárias (3 por dia sorteadas por data)
DAILY_QUESTS = [
    {"id": "dq_wood", "type": "gather", "target": "madeira", "count": 40, "title": L("Lenhador", "Lumberjack"), "desc": L("Colete 40 madeira", "Gather 40 wood")},
    {"id": "dq_stone", "type": "gather", "target": "pedra", "count": 40, "title": L("Pedreiro", "Mason"), "desc": L("Colete 40 pedra", "Gather 40 stone")},
    {"id": "dq_fiber", "type": "gather", "target": "fibra", "count": 30, "title": L("Tecelão", "Weaver"), "desc": L("Colete 30 fibra", "Gather 30 fiber")},
    {"id": "dq_capture", "type": "capture", "target": None, "count": 2, "title": L("Novos Vínculos", "New Bonds"), "desc": L("Recrute 2 Ecos", "Recruit 2 Echoes")},
    {"id": "dq_defeat", "type": "defeat", "target": None, "count": 8, "title": L("Defensor", "Defender"), "desc": L("Derrote 8 Ecos selvagens", "Defeat 8 wild Echoes")},
    {"id": "dq_craft", "type": "craft", "target": None, "count": 10, "title": L("Artesão", "Artisan"), "desc": L("Crie 10 itens", "Craft 10 items")},
    {"id": "dq_build", "type": "build", "target": None, "count": 5, "title": L("Arquiteto", "Architect"), "desc": L("Construa 5 peças", "Build 5 pieces")},
    {"id": "dq_collect", "type": "harvest", "target": None, "count": 30, "title": L("Colheita", "Harvest"), "desc": L("Recolha 30 itens das estações", "Collect 30 items from stations")},
    {"id": "dq_pet", "type": "pet", "target": None, "count": 3, "title": L("Carinho", "Affection"), "desc": L("Faça carinho em 3 Ecos", "Pet 3 Echoes")},
    {"id": "dq_cook", "type": "craft_cat", "target": "comida", "count": 3, "title": L("Cozinheiro", "Cook"), "desc": L("Prepare 3 comidas", "Cook 3 meals")},
    {"id": "dq_expedition", "type": "expedition", "target": None, "count": 1, "title": L("Explorador", "Explorer"), "desc": L("Conclua 1 expedição", "Complete 1 expedition")},
]
DAILY_QUEST_REWARD = {"coins": 60, "pass_xp": 100}
DAILY_ALL_BONUS = {"gems": 10, "pass_xp": 150}

# Passe de temporada (30 níveis). XP por nível
PASS = {"season": 1, "name": L("Temporada 1: Ecos de Ferro", "Season 1: Iron Echoes"), "tiers": 30, "xp_per_tier": 250, "days": 42}


def pass_rewards():
    free, prem = [], []
    for t in range(1, 31):
        if t % 10 == 0:
            free.append({"gems": 20})
            prem.append({"monster": ["vulcanix" if t == 30 else ("coralume" if t == 20 else "lumeflor"), 10, True]})
        elif t % 5 == 0:
            free.append({"items": {"esfera_grande": 2}})
            prem.append({"gems": 40, "items": {"esfera_aurora": 1}})
        elif t % 2 == 0:
            free.append({"coins": 150})
            prem.append({"items": {"esfera_aurora": 1}})
        else:
            free.append({"items": {"esfera": 3}})
            prem.append({"gems": 15})
    return {"free": free, "premium": prem}


# Marcos do Bestiário (retenção por coleção)
DEX_MILESTONES = [
    {"count": 3, "reward": {"gems": 10}}, {"count": 6, "reward": {"items": {"esfera_grande": 3}}},
    {"count": 10, "reward": {"gems": 25}}, {"count": 15, "reward": {"items": {"esfera_aurora": 2}}},
    {"count": 20, "reward": {"gems": 50}}, {"count": 25, "reward": {"gems": 80}}, {"count": 31, "reward": {"gems": 150}},
]

REMOTE_CONFIG_DEFAULTS = {
    "xp_mult": 1.0, "drop_mult": 1.0, "work_mult": 1.0,
    "interstitial_enabled": True, "interstitial_first_after_sec": 600, "interstitial_min_interval_sec": 300,
    "interstitial_daily_cap": 6, "banner_in_menus": False, "rewarded_daily_cap": 25,
    "starter_pack_hours": 72, "event_name": "", "event_xp_mult": 1.0, "season_active": True,
    "min_supported_version": 1,
}

# Eventos de Analytics (Firebase) — catálogo usado pelo jogo e documentado em docs/MONETIZACAO.md
ANALYTICS_EVENTS = [
    "tutorial_begin", "tutorial_complete", "starter_chosen", "quest_complete", "level_up", "map_enter",
    "boss_defeated", "trainer_defeated", "city_liberated", "capture_attempt", "capture_success", "aurora_variant",
    "craft", "build", "assign_worker", "harvest", "expedition_start", "expedition_complete",
    "fragment_found", "daily_login", "daily_quest_complete", "pass_tier", "ad_rewarded_offer", "ad_rewarded_complete",
    "ad_interstitial_show", "iap_view", "iap_purchase", "player_death", "session_start", "sandbox_start",
]
