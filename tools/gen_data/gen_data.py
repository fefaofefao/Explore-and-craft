# -*- coding: utf-8 -*-
"""Gera data/*.json a partir dos módulos de conteúdo e valida referências cruzadas.

Uso: python3 tools/gen_data/gen_data.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "data")

import content_monsters as cm  # noqa: E402
import content_items as ci  # noqa: E402
import content_world as cw  # noqa: E402
import content_meta as cmeta  # noqa: E402
import content_strings as cs  # noqa: E402


def validate(species, errors):
    items, recipes, nodes, builds = ci.ITEMS, ci.RECIPES, ci.NODES, ci.BUILDINGS
    for rid, r in recipes.items():
        if r["out"] not in items:
            errors.append(f"receita {rid}: saída desconhecida {r['out']}")
        for k in r["in"]:
            if k not in items:
                errors.append(f"receita {rid}: ingrediente desconhecido {k}")
    for nid, n in nodes.items():
        for k in list(n["drops"]) + list(n["bonus"]):
            if k not in items:
                errors.append(f"nó {nid}: drop desconhecido {k}")
        t = n["tool"]
        if t.startswith("item:") and t[5:] not in items:
            errors.append(f"nó {nid}: item-chave desconhecido {t}")
    for bid, b in builds.items():
        for k in b["cost"]:
            if k not in items:
                errors.append(f"construção {bid}: custo desconhecido {k}")
        for k in b.get("output", {}):
            if k not in items:
                errors.append(f"construção {bid}: saída desconhecida {k}")
    for sid, s in species.items():
        for lv, sk in s["learnset"]:
            if sk not in cm.SKILLS:
                errors.append(f"espécie {sid}: habilidade {sk}")
        if s["evolves"] and s["evolves"]["to"] not in species:
            errors.append(f"espécie {sid}: evolução {s['evolves']['to']}")
        for t in s["types"]:
            if t not in cm.TYPES["order"]:
                errors.append(f"espécie {sid}: tipo {t}")
    for mid, m in cw.MAPS.items():
        for sp in m["spawns"]:
            if sp[0] not in species:
                errors.append(f"mapa {mid}: spawn {sp[0]}")
        for k in list(m["trees"]) + list(m["nodes"]):
            if k not in nodes:
                errors.append(f"mapa {mid}: nó {k}")
        for p in m["portals"]:
            if p["to"] not in cw.MAPS:
                errors.append(f"mapa {mid}: portal {p['to']}")
        lair = m["pois"].get("lair")
        if lair:
            if lair["boss"] not in species:
                errors.append(f"mapa {mid}: chefe {lair['boss']}")
            if lair["drop"] not in items:
                errors.append(f"mapa {mid}: drop {lair['drop']}")
            if lair.get("barrier") and lair["barrier"] not in nodes:
                errors.append(f"mapa {mid}: barreira {lair['barrier']}")
        for f in m["fragments"]:
            if f not in cw.FRAGMENTS:
                errors.append(f"mapa {mid}: fragmento {f}")
        if m.get("city"):
            for t in m["city"]["trainers"]:
                if t not in cw.TRAINERS:
                    errors.append(f"mapa {mid}: treinador {t}")
    for tid, t in cw.TRAINERS.items():
        for sp, lv in t["team"]:
            if sp not in species:
                errors.append(f"treinador {tid}: {sp}")
        for d in (t["intro"], t["defeat"]):
            if d not in cw.DIALOGS:
                errors.append(f"treinador {tid}: diálogo {d}")
        for k in t["reward"].get("items", {}):
            if k not in items:
                errors.append(f"treinador {tid}: item {k}")
    for q in cw.QUESTS:
        for d in (q["dialog"], q["done_dialog"]):
            if d and d not in cw.DIALOGS:
                errors.append(f"missão {q['id']}: diálogo {d}")
        if q["type"] in ("collect", "craft") and isinstance(q["target"], dict):
            for k in q["target"]:
                if k not in items:
                    errors.append(f"missão {q['id']}: item {k}")
        if q["type"] == "build" or q["type"] == "assign":
            for k in q["target"]:
                if k not in builds:
                    errors.append(f"missão {q['id']}: construção {k}")
        if q["type"] == "boss" and q["target"] not in species:
            errors.append(f"missão {q['id']}: chefe {q['target']}")
        if q["type"] == "trainer":
            for t in q["target"]:
                if t not in cw.TRAINERS:
                    errors.append(f"missão {q['id']}: treinador {t}")
        if q["type"] == "visit" and q["target"] not in cw.MAPS:
            errors.append(f"missão {q['id']}: mapa {q['target']}")
        for k in q["reward"].get("items", {}):
            if k not in items:
                errors.append(f"missão {q['id']}: recompensa {k}")
    for d in cw.DIALOGS.values():
        for line in d:
            if line["who"] not in cw.SPEAKERS:
                errors.append(f"diálogo: falante {line['who']}")
    for s in cmeta.ECONOMY["shop"]:
        if "item" in s and s["item"] not in items:
            errors.append(f"loja: {s['item']}")
    for dq in cmeta.DAILY_QUESTS:
        if dq["type"] == "gather" and dq["target"] not in items:
            errors.append(f"diária: {dq['target']}")


def main():
    os.makedirs(OUT, exist_ok=True)
    species = cm.build_species()
    errors = []
    validate(species, errors)
    if errors:
        print("ERROS DE VALIDAÇÃO:")
        for e in errors:
            print(" -", e)
        sys.exit(1)

    files = {
        "types.json": cm.TYPES,
        "skills.json": cm.SKILLS,
        "species.json": species,
        "items.json": ci.ITEMS,
        "recipes.json": ci.RECIPES,
        "nodes.json": ci.NODES,
        "buildings.json": ci.BUILDINGS,
        "maps.json": {"maps": cw.MAPS, "future_acts": cw.FUTURE_ACTS},
        "trainers.json": cw.TRAINERS,
        "quests.json": cw.QUESTS,
        "dialogs.json": {"speakers": cw.SPEAKERS, "dialogs": cw.DIALOGS},
        "fragments.json": cw.FRAGMENTS,
        "config.json": cmeta.CONFIG,
        "economy.json": {"economy": cmeta.ECONOMY, "iap": cmeta.IAP, "daily_login": cmeta.DAILY_LOGIN,
                         "daily_quests": cmeta.DAILY_QUESTS, "daily_quest_reward": cmeta.DAILY_QUEST_REWARD,
                         "daily_all_bonus": cmeta.DAILY_ALL_BONUS, "pass": dict(cmeta.PASS, **cmeta.pass_rewards()),
                         "dex_milestones": cmeta.DEX_MILESTONES},
        "ads.json": cmeta.ADS,
        "ad_policy.json": cmeta.AD_POLICY,
        "remote_config_defaults.json": cmeta.REMOTE_CONFIG_DEFAULTS,
        "analytics_events.json": cmeta.ANALYTICS_EVENTS,
        "strings.json": cs.build_strings(),
    }
    for name, obj in files.items():
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=False)
    n_sp = len([s for s in species.values() if not s["boss"]])
    print(f"OK: {len(files)} arquivos | {n_sp} espécies + {len(species) - n_sp} chefes | {len(ci.ITEMS)} itens | "
          f"{len(ci.RECIPES)} receitas | {len(ci.BUILDINGS)} construções | {len(cw.MAPS)} mapas | {len(cw.QUESTS)} missões | "
          f"{len(cw.DIALOGS)} diálogos | {len(cw.FRAGMENTS)} fragmentos | {len(cs.S)} textos")


if __name__ == "__main__":
    main()
