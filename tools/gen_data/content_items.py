# -*- coding: utf-8 -*-
"""Itens, receitas, nós de recurso e construções."""
from content_monsters import L


def item(name_pt, name_en, cat, color, icon, desc_pt="", desc_en="", stack=99, value=1, **kw):
    d = {"name": L(name_pt, name_en), "cat": cat, "color": color, "icon": icon,
         "desc": L(desc_pt, desc_en), "stack": stack, "value": value}
    d.update(kw)
    return d


ITEMS = {
    # ---------- recursos
    "madeira": item("Madeira", "Wood", "recurso", "#a0703c", "log", "Material básico de construção.", "Basic building material.", value=1),
    "pedra": item("Pedra", "Stone", "recurso", "#9a9a9a", "rock", "Sólida e confiável.", "Solid and reliable.", value=1),
    "fibra": item("Fibra", "Fiber", "recurso", "#b9d77a", "fiber", "Trançada vira corda, tecido e muito mais.", "Braided into rope, cloth and more.", value=1),
    "baga": item("Baga Doce", "Sweetberry", "comida", "#e0405a", "berry", "Mata um pouco a fome.", "Eases hunger a little.", value=2, food={"hunger": 12, "hp": 3}),
    "minerio_ferro": item("Minério de Ferro", "Iron Ore", "recurso", "#b07a5a", "ore", "Derreta na fornalha.", "Smelt it in a furnace.", value=3),
    "carvao": item("Carvão", "Coal", "recurso", "#333338", "coal", "Queima por muito tempo.", "Burns for a long time.", value=2),
    "cristal": item("Cristal Eco", "Echo Crystal", "recurso", "#7ff0ff", "crystal", "Vibra com a memória do mundo.", "Hums with the world's memory.", value=8),
    "areia": item("Areia", "Sand", "recurso", "#e8d29a", "sand", "Vira vidro no fogo.", "Becomes glass in fire.", value=1),
    "gelo": item("Bloco de Gelo", "Ice Block", "recurso", "#c8f0ff", "ice", "Frio que não derrete fácil.", "Cold that won't melt easily.", value=2),
    "pele": item("Pele", "Hide", "recurso", "#c49a6a", "hide", "Deixada por Ecos derrotados.", "Left behind by defeated Echoes.", value=3),
    "carne_crua": item("Carne Crua", "Raw Meat", "comida", "#e07a7a", "meat", "Melhor assar antes.", "Better roast it first.", value=2, food={"hunger": 8, "hp": -2}),
    "seiva": item("Seiva", "Sap", "recurso", "#e8a83a", "drop", "Grudenta e preciosa.", "Sticky and precious.", value=4),
    "cogumelo": item("Cogumelo", "Mushroom", "comida", "#c24d6b", "mushroom", "Nutritivo, se for o certo.", "Nutritious, if it's the right one.", value=2, food={"hunger": 10, "hp": 5}),
    "polpa_cacto": item("Polpa de Cacto", "Cactus Pulp", "comida", "#7ad66a", "drop", "Hidrata no deserto.", "Hydrates in the desert.", value=2, food={"hunger": 6, "hp": 8}),
    "po_eco": item("Pó de Eco", "Echo Dust", "recurso", "#d8b8ff", "dust", "Resíduo brilhante de batalhas.", "Glowing residue from battles.", value=3),
    "lodo": item("Lodo Fértil", "Rich Mud", "recurso", "#5a6a3a", "drop", "Fertiliza qualquer horta.", "Fertilizes any garden.", value=3),
    "obsidiana": item("Obsidiana", "Obsidian", "recurso", "#2a1a3a", "crystal", "Vidro vulcânico afiadíssimo.", "Razor-sharp volcanic glass.", value=6),
    "pena": item("Pena Tempestuosa", "Storm Feather", "recurso", "#8fa0ff", "feather", "Estala com eletricidade.", "Crackles with electricity.", value=5),
    # ---------- processados
    "lingote_ferro": item("Lingote de Ferro", "Iron Ingot", "material", "#c8ccd4", "ingot", "Base de ferramentas avançadas.", "Base of advanced tools.", value=8),
    "vidro": item("Vidro", "Glass", "material", "#bfefff", "glass", "Transparente e frágil.", "Clear and fragile.", value=5),
    "corda": item("Corda", "Rope", "material", "#d8c08a", "rope", "Amarra quase tudo.", "Ties almost anything.", value=3),
    "tabua": item("Tábua", "Plank", "material", "#c89058", "plank", "Madeira trabalhada.", "Worked lumber.", value=3),
    "tijolo": item("Tijolo", "Brick", "material", "#b85a3a", "brick", "Para construções duráveis.", "For lasting buildings.", value=4),
    "circuito": item("Circuito Eco", "Echo Circuit", "material", "#5fd0ff", "chip", "Tecnologia lumariana restaurada.", "Restored Lumarian technology.", value=15),
    "liga_obsidiana": item("Liga de Obsidiana", "Obsidian Alloy", "material", "#6a3a8a", "ingot", "Metal forjado com vidro vulcânico.", "Metal forged with volcanic glass.", value=20),
    # ---------- comida preparada
    "carne_assada": item("Carne Assada", "Roast Meat", "comida", "#b8603a", "meat", "Restaura bastante fome.", "Restores plenty of hunger.", value=5, food={"hunger": 35, "hp": 15}),
    "ensopado": item("Ensopado da Aurora", "Aurora Stew", "comida", "#e8a050", "bowl", "Esquenta a alma.", "Warms the soul.", value=12, food={"hunger": 70, "hp": 40}),
    "suco_baga": item("Suco de Baga", "Berry Juice", "comida", "#ff5a7a", "bottle", "Refrescante.", "Refreshing.", value=6, food={"hunger": 20, "hp": 20}),
    # ---------- ferramentas e armas (stack 1)
    "machado_pedra": item("Machado de Pedra", "Stone Axe", "ferramenta", "#9a9a9a", "axe", "Corta árvores mais rápido.", "Chops trees faster.", stack=1, value=6, tool={"kind": "axe", "tier": 1, "power": 2.5}),
    "picareta_pedra": item("Picareta de Pedra", "Stone Pickaxe", "ferramenta", "#9a9a9a", "pick", "Quebra pedras e minério.", "Breaks rocks and ore.", stack=1, value=6, tool={"kind": "pick", "tier": 1, "power": 2.5}),
    "machado_ferro": item("Machado de Ferro", "Iron Axe", "ferramenta", "#c8ccd4", "axe", "Derruba árvores num instante.", "Fells trees in an instant.", stack=1, value=25, tool={"kind": "axe", "tier": 2, "power": 5.0}),
    "picareta_ferro": item("Picareta de Ferro", "Iron Pickaxe", "ferramenta", "#c8ccd4", "pick", "Quebra até gelo eterno.", "Breaks even eternal ice.", stack=1, value=25, tool={"kind": "pick", "tier": 2, "power": 5.0}),
    "picareta_obsidiana": item("Picareta de Obsidiana", "Obsidian Pickaxe", "ferramenta", "#6a3a8a", "pick", "Corta rocha vulcânica.", "Cuts volcanic rock.", stack=1, value=60, tool={"kind": "pick", "tier": 3, "power": 8.0}),
    "lanca_pedra": item("Lança de Pedra", "Stone Spear", "arma", "#9a9a9a", "spear", "Ajuda seus Ecos na luta.", "Helps your Echoes fight.", stack=1, value=8, weapon={"dmg": 8}),
    "espada_ferro": item("Espada de Ferro", "Iron Sword", "arma", "#c8ccd4", "sword", "Corte firme.", "A firm cut.", stack=1, value=30, weapon={"dmg": 16}),
    "lamina_obsidiana": item("Lâmina de Obsidiana", "Obsidian Blade", "arma", "#6a3a8a", "sword", "Lâmina que canta.", "A blade that sings.", stack=1, value=70, weapon={"dmg": 28}),
    "tocha": item("Tocha", "Torch", "ferramenta", "#ffb84a", "torch", "Ilumina e queima espinhos.", "Lights the way and burns thorns.", stack=1, value=3, tool={"kind": "torch", "tier": 1, "power": 1.0}),
    "pe_de_cabra": item("Pé de Cabra", "Crowbar", "ferramenta", "#c8ccd4", "crowbar", "Abre jaulas e portões.", "Opens cages and gates.", stack=1, value=20, tool={"kind": "crowbar", "tier": 1, "power": 1.0}),
    "planador": item("Planador de Fibra", "Fiber Glider", "ferramenta", "#ffd8a0", "glider", "Plane de lugares altos (segure Pular no ar).", "Glide from heights (hold Jump in the air).", stack=1, value=40, tool={"kind": "glider", "tier": 1, "power": 1.0}),
    # ---------- equipamentos de proteção
    "cantil": item("Cantil de Couro", "Leather Canteen", "equipamento", "#c49a6a", "canteen", "Protege do calor das Dunas.", "Protects from the Dunes' heat.", stack=1, value=15, gear={"protect": "calor"}),
    "casaco_pele": item("Casaco de Pele", "Fur Coat", "equipamento", "#e8d8c0", "coat", "Protege do frio dos Picos.", "Protects from the Peaks' cold.", stack=1, value=20, gear={"protect": "frio"}),
    "mascara_filtro": item("Máscara de Filtro", "Filter Mask", "equipamento", "#7a9a6a", "mask", "Protege dos gases do Pântano.", "Protects from Marsh gases.", stack=1, value=35, gear={"protect": "veneno"}),
    "traje_ignifugo": item("Traje Ignífugo", "Fireproof Suit", "equipamento", "#d86a3a", "coat", "Resiste ao calor do Cânion.", "Withstands the Canyon's heat.", stack=1, value=45, gear={"protect": "lava"}),
    "para_raios": item("Para-raios Portátil", "Pocket Lightning Rod", "equipamento", "#8fa0ff", "rod", "Desvia raios das Ilhas.", "Deflects the Isles' lightning.", stack=1, value=45, gear={"protect": "tempestade"}),
    # ---------- esferas e cuidados com Ecos
    "esfera": item("Esfera de Vínculo", "Bond Sphere", "esfera", "#ff5a5a", "orb", "Recruta Ecos enfraquecidos.", "Recruits weakened Echoes.", value=5, orb={"mult": 1.0}),
    "esfera_grande": item("Esfera Grande", "Great Sphere", "esfera", "#3a8aff", "orb", "Chance de vínculo 1,6x.", "Bond chance x1.6.", value=15, orb={"mult": 1.6}),
    "esfera_aurora": item("Esfera Aurora", "Aurora Sphere", "esfera", "#ffd84a", "orb", "Chance de vínculo 2,5x.", "Bond chance x2.5.", value=40, orb={"mult": 2.5}),
    "tonico": item("Tônico Eco", "Echo Tonic", "cuidado", "#7aff9a", "bottle", "Cura 50 PV do Eco ativo.", "Heals 50 HP of your active Echo.", value=6, heal_monster={"hp": 50, "revive": False}),
    "tonico_forte": item("Tônico Forte", "Strong Tonic", "cuidado", "#3aff7a", "bottle", "Cura 150 PV do Eco ativo.", "Heals 150 HP of your active Echo.", value=15, heal_monster={"hp": 150, "revive": False}),
    "reviver": item("Semente Reviver", "Revive Seed", "cuidado", "#ffef7a", "seed", "Reanima um Eco desmaiado.", "Revives a fainted Echo.", value=20, heal_monster={"hp": 0.5, "revive": True}),
    # ---------- itens únicos de história
    "seiva_ancestral": item("Seiva Ancestral", "Ancient Sap", "chave", "#ffb83a", "relic", "Pulsa como um coração verde.", "Beats like a green heart.", stack=1, value=0),
    "olho_ambar": item("Olho de Âmbar", "Amber Eye", "chave", "#ffd04a", "relic", "Guarda a luz de um sol antigo.", "Holds the light of an ancient sun.", stack=1, value=0),
    "lagrima_glacial": item("Lágrima Glacial", "Glacial Tear", "chave", "#aef0ff", "relic", "Uma memória congelada.", "A frozen memory.", stack=1, value=0),
    "nucleo_ponte": item("Núcleo da Ponte", "Bridge Core", "chave", "#ff9aff", "core", "Desperta a Ponte Lumariana.", "Awakens the Lumarian Bridge.", stack=1, value=0),
    "lente_solar": item("Lente Solar", "Sun Lens", "chave", "#ffe08a", "lens", "Abre o Templo Solar.", "Opens the Sun Temple.", stack=1, value=0),
    "raiz_negra": item("Raiz Negra", "Black Root", "chave", "#3a2a4a", "relic", "Absorve toda a luz ao redor.", "Drinks all light around it.", stack=1, value=0),
    "brasa_eterna": item("Brasa Eterna", "Eternal Ember", "chave", "#ff6a1a", "relic", "Nunca se apaga.", "Never goes out.", stack=1, value=0),
    "pena_trovao": item("Pena-Trovão", "Thunder Plume", "chave", "#5a6aff", "relic", "Carrega uma tempestade inteira.", "Carries a whole storm.", stack=1, value=0),
    "chave_sombria": item("Chave Sombria", "Shadow Key", "chave", "#8a5cd6", "core", "Abre os portões de Alta Cinza.", "Opens the gates of Ashspire.", stack=1, value=0),
}

# station: mao | bancada | fornalha | fogueira | arcana | forja
RECIPES = {
    # mão
    "r_corda": {"out": "corda", "n": 1, "in": {"fibra": 3}, "station": "mao", "lvl": 1},
    "r_tocha": {"out": "tocha", "n": 1, "in": {"madeira": 2, "fibra": 2}, "station": "mao", "lvl": 1},
    "r_machado_pedra": {"out": "machado_pedra", "n": 1, "in": {"madeira": 3, "pedra": 3, "fibra": 2}, "station": "mao", "lvl": 1},
    "r_picareta_pedra": {"out": "picareta_pedra", "n": 1, "in": {"madeira": 3, "pedra": 4, "fibra": 2}, "station": "mao", "lvl": 1},
    "r_esfera": {"out": "esfera", "n": 2, "in": {"pedra": 2, "fibra": 1, "baga": 1}, "station": "mao", "lvl": 1},
    "r_lanca_pedra": {"out": "lanca_pedra", "n": 1, "in": {"madeira": 4, "pedra": 2, "corda": 1}, "station": "mao", "lvl": 2},
    # bancada
    "r_tabua": {"out": "tabua", "n": 2, "in": {"madeira": 3}, "station": "bancada", "lvl": 2},
    "r_tonico": {"out": "tonico", "n": 2, "in": {"baga": 3, "fibra": 1}, "station": "bancada", "lvl": 2},
    "r_cantil": {"out": "cantil", "n": 1, "in": {"pele": 3, "corda": 2, "seiva": 1}, "station": "bancada", "lvl": 3},
    "r_casaco": {"out": "casaco_pele", "n": 1, "in": {"pele": 6, "corda": 3, "fibra": 5}, "station": "bancada", "lvl": 5},
    "r_esfera_grande": {"out": "esfera_grande", "n": 2, "in": {"lingote_ferro": 1, "cristal": 1, "pedra": 2}, "station": "bancada", "lvl": 7},
    "r_pe_de_cabra": {"out": "pe_de_cabra", "n": 1, "in": {"lingote_ferro": 3}, "station": "bancada", "lvl": 9},
    "r_planador": {"out": "planador", "n": 1, "in": {"tabua": 4, "corda": 6, "pele": 4}, "station": "bancada", "lvl": 6},
    "r_reviver": {"out": "reviver", "n": 1, "in": {"seiva": 2, "baga": 4, "po_eco": 2}, "station": "bancada", "lvl": 6},
    "r_tonico_forte": {"out": "tonico_forte", "n": 2, "in": {"tonico": 2, "po_eco": 2, "cogumelo": 1}, "station": "bancada", "lvl": 10},
    "r_mascara": {"out": "mascara_filtro", "n": 1, "in": {"vidro": 2, "pele": 4, "lodo": 3, "corda": 2}, "station": "bancada", "lvl": 20},
    "r_para_raios": {"out": "para_raios", "n": 1, "in": {"lingote_ferro": 4, "circuito": 1, "pena": 4}, "station": "bancada", "lvl": 24},
    # fornalha
    "r_lingote": {"out": "lingote_ferro", "n": 1, "in": {"minerio_ferro": 2, "carvao": 1}, "station": "fornalha", "lvl": 4},
    "r_vidro": {"out": "vidro", "n": 1, "in": {"areia": 3, "carvao": 1}, "station": "fornalha", "lvl": 4},
    "r_tijolo": {"out": "tijolo", "n": 2, "in": {"pedra": 2, "areia": 1, "carvao": 1}, "station": "fornalha", "lvl": 5},
    "r_circuito": {"out": "circuito", "n": 1, "in": {"lingote_ferro": 2, "cristal": 2, "vidro": 1}, "station": "fornalha", "lvl": 12},
    "r_liga_obsidiana": {"out": "liga_obsidiana", "n": 1, "in": {"obsidiana": 2, "lingote_ferro": 2, "carvao": 2}, "station": "fornalha", "lvl": 22},
    # forja (armas e ferramentas de metal)
    "r_machado_ferro": {"out": "machado_ferro", "n": 1, "in": {"lingote_ferro": 3, "tabua": 2}, "station": "forja", "lvl": 6},
    "r_picareta_ferro": {"out": "picareta_ferro", "n": 1, "in": {"lingote_ferro": 3, "tabua": 2}, "station": "forja", "lvl": 6},
    "r_espada_ferro": {"out": "espada_ferro", "n": 1, "in": {"lingote_ferro": 4, "tabua": 1, "pele": 1}, "station": "forja", "lvl": 8},
    "r_traje": {"out": "traje_ignifugo", "n": 1, "in": {"liga_obsidiana": 2, "pele": 6, "corda": 3}, "station": "forja", "lvl": 22},
    "r_picareta_obsidiana": {"out": "picareta_obsidiana", "n": 1, "in": {"liga_obsidiana": 3, "tabua": 2}, "station": "forja", "lvl": 22},
    "r_lamina_obsidiana": {"out": "lamina_obsidiana", "n": 1, "in": {"liga_obsidiana": 4, "circuito": 1}, "station": "forja", "lvl": 25},
    # fogueira
    "r_carne_assada": {"out": "carne_assada", "n": 1, "in": {"carne_crua": 1}, "station": "fogueira", "lvl": 1},
    "r_suco": {"out": "suco_baga", "n": 1, "in": {"baga": 4}, "station": "fogueira", "lvl": 2},
    "r_ensopado": {"out": "ensopado", "n": 1, "in": {"carne_crua": 2, "cogumelo": 2, "baga": 2}, "station": "fogueira", "lvl": 4},
    # arcana (história)
    "r_lente_solar": {"out": "lente_solar", "n": 1, "in": {"vidro": 3, "cristal": 2, "lingote_ferro": 1}, "station": "arcana", "lvl": 5},
    "r_nucleo_ponte": {"out": "nucleo_ponte", "n": 1, "in": {"seiva_ancestral": 1, "olho_ambar": 1, "lagrima_glacial": 1, "cristal": 5, "lingote_ferro": 5}, "station": "arcana", "lvl": 8},
    "r_esfera_aurora": {"out": "esfera_aurora", "n": 1, "in": {"esfera_grande": 2, "cristal": 3, "po_eco": 5}, "station": "arcana", "lvl": 12},
    "r_chave_sombria": {"out": "chave_sombria", "n": 1, "in": {"raiz_negra": 1, "brasa_eterna": 1, "pena_trovao": 1, "circuito": 3, "liga_obsidiana": 2}, "station": "arcana", "lvl": 26},
}

# Nós de recurso coletáveis no mundo
NODES = {
    "arvore": {"hp": 6, "tool": "axe", "min_tier": 0, "drops": {"madeira": [2, 4]}, "bonus": {"seiva": 0.12, "fibra": 0.3}, "respawn": 240, "xp": 2},
    "pinheiro": {"hp": 7, "tool": "axe", "min_tier": 0, "drops": {"madeira": [3, 4]}, "bonus": {"seiva": 0.15}, "respawn": 240, "xp": 2},
    "palmeira": {"hp": 5, "tool": "axe", "min_tier": 0, "drops": {"madeira": [2, 3]}, "bonus": {"fibra": 0.5}, "respawn": 240, "xp": 2},
    "arvore_morta": {"hp": 5, "tool": "axe", "min_tier": 0, "drops": {"madeira": [1, 3]}, "bonus": {"carvao": 0.3}, "respawn": 240, "xp": 2},
    "rocha": {"hp": 7, "tool": "pick", "min_tier": 0, "drops": {"pedra": [2, 4]}, "bonus": {"carvao": 0.25}, "respawn": 300, "xp": 2},
    "minerio": {"hp": 9, "tool": "pick", "min_tier": 1, "drops": {"minerio_ferro": [1, 3]}, "bonus": {"pedra": 0.5}, "respawn": 360, "xp": 4},
    "carvao_veio": {"hp": 8, "tool": "pick", "min_tier": 1, "drops": {"carvao": [2, 3]}, "bonus": {"pedra": 0.5}, "respawn": 360, "xp": 3},
    "cristal": {"hp": 10, "tool": "pick", "min_tier": 2, "drops": {"cristal": [1, 2]}, "bonus": {"po_eco": 0.3}, "respawn": 600, "xp": 8},
    "arbusto": {"hp": 2, "tool": "any", "min_tier": 0, "drops": {"baga": [1, 3], "fibra": [1, 2]}, "bonus": {}, "respawn": 180, "xp": 1},
    "capim": {"hp": 1, "tool": "any", "min_tier": 0, "drops": {"fibra": [1, 3]}, "bonus": {}, "respawn": 120, "xp": 1},
    "cogumelos": {"hp": 1, "tool": "any", "min_tier": 0, "drops": {"cogumelo": [1, 2]}, "bonus": {}, "respawn": 240, "xp": 1},
    "cacto": {"hp": 3, "tool": "any", "min_tier": 0, "drops": {"polpa_cacto": [1, 2], "fibra": [1, 2]}, "bonus": {}, "respawn": 200, "xp": 1},
    "monte_areia": {"hp": 2, "tool": "any", "min_tier": 0, "drops": {"areia": [2, 4]}, "bonus": {}, "respawn": 150, "xp": 1},
    "bloco_gelo": {"hp": 6, "tool": "pick", "min_tier": 1, "drops": {"gelo": [1, 3]}, "bonus": {"cristal": 0.08}, "respawn": 300, "xp": 3},
    "lodo_poca": {"hp": 2, "tool": "any", "min_tier": 0, "drops": {"lodo": [1, 3]}, "bonus": {}, "respawn": 200, "xp": 1},
    "obsidiana_veio": {"hp": 14, "tool": "pick", "min_tier": 2, "drops": {"obsidiana": [1, 2]}, "bonus": {"carvao": 0.5}, "respawn": 480, "xp": 8},
    "ninho_pena": {"hp": 2, "tool": "any", "min_tier": 0, "drops": {"pena": [1, 2]}, "bonus": {}, "respawn": 300, "xp": 2},
    # barreiras de progressão (não renascem)
    "espinhos": {"hp": 3, "tool": "torch", "min_tier": 1, "drops": {}, "bonus": {}, "respawn": -1, "xp": 10, "barrier": True},
    "muro_gelo": {"hp": 12, "tool": "pick", "min_tier": 2, "drops": {"gelo": [3, 5]}, "bonus": {}, "respawn": -1, "xp": 15, "barrier": True},
    "porta_solar": {"hp": 1, "tool": "item:lente_solar", "min_tier": 0, "drops": {}, "bonus": {}, "respawn": -1, "xp": 20, "barrier": True},
    "jaula": {"hp": 1, "tool": "crowbar", "min_tier": 1, "drops": {}, "bonus": {}, "respawn": -1, "xp": 20, "barrier": True, "cage": True},
}

# Construções. kind: piece | station | machine | deco | special
# Peças estruturais ocupam 1 célula (2 m). Estações e máquinas também.
BUILDINGS = {
    "fundacao": {"name": L("Fundação", "Foundation"), "kind": "piece", "cost": {"madeira": 4, "pedra": 2}, "lvl": 1, "shape": "foundation", "mat": "wood"},
    "parede": {"name": L("Parede", "Wall"), "kind": "piece", "cost": {"madeira": 4}, "lvl": 1, "shape": "wall", "mat": "wood"},
    "porta": {"name": L("Porta", "Door"), "kind": "piece", "cost": {"madeira": 5, "fibra": 2}, "lvl": 1, "shape": "door", "mat": "wood"},
    "janela": {"name": L("Janela", "Window"), "kind": "piece", "cost": {"madeira": 4, "vidro": 1}, "lvl": 5, "shape": "window", "mat": "wood"},
    "telhado": {"name": L("Telhado", "Roof"), "kind": "piece", "cost": {"madeira": 4, "fibra": 3}, "lvl": 1, "shape": "roof", "mat": "thatch"},
    "parede_pedra": {"name": L("Parede de Pedra", "Stone Wall"), "kind": "piece", "cost": {"pedra": 6, "tijolo": 1}, "lvl": 6, "shape": "wall", "mat": "stone"},
    "fundacao_pedra": {"name": L("Fundação de Pedra", "Stone Foundation"), "kind": "piece", "cost": {"pedra": 6, "tijolo": 1}, "lvl": 6, "shape": "foundation", "mat": "stone"},
    "cerca": {"name": L("Cerca", "Fence"), "kind": "piece", "cost": {"madeira": 2}, "lvl": 1, "shape": "fence", "mat": "wood"},
    "tocha_poste": {"name": L("Poste de Tocha", "Torch Post"), "kind": "deco", "cost": {"madeira": 1, "carvao": 1}, "lvl": 2, "shape": "torchpost", "mat": "wood", "light": True},
    "fogueira": {"name": L("Fogueira", "Campfire"), "kind": "station", "cost": {"madeira": 5, "pedra": 3}, "lvl": 1, "shape": "campfire", "station": "fogueira", "light": True},
    "bancada": {"name": L("Bancada", "Workbench"), "kind": "station", "cost": {"madeira": 8, "pedra": 4}, "lvl": 1, "shape": "bench", "station": "bancada"},
    "fornalha": {"name": L("Fornalha", "Furnace"), "kind": "station", "cost": {"pedra": 12, "madeira": 4}, "lvl": 3, "shape": "furnace", "station": "fornalha", "light": True},
    "forja": {"name": L("Forja", "Forge"), "kind": "station", "cost": {"pedra": 10, "lingote_ferro": 3, "tijolo": 4}, "lvl": 6, "shape": "forge", "station": "forja", "light": True},
    "bancada_arcana": {"name": L("Bancada Arcana", "Arcane Bench"), "kind": "station", "cost": {"tabua": 6, "cristal": 3, "lingote_ferro": 2}, "lvl": 5, "shape": "arcane", "station": "arcana", "light": True},
    "cama": {"name": L("Cama", "Bed"), "kind": "special", "cost": {"madeira": 6, "fibra": 6, "pele": 2}, "lvl": 2, "shape": "bed", "special": "bed"},
    "bau": {"name": L("Baú", "Chest"), "kind": "special", "cost": {"madeira": 8}, "lvl": 2, "shape": "chest", "special": "chest"},
    "fonte_cura": {"name": L("Fonte de Cura", "Healing Spring"), "kind": "machine", "cost": {"pedra": 10, "cristal": 2, "baga": 6}, "lvl": 4, "shape": "spring", "special": "heal", "light": True},
    # Estações de trabalho de Ecos (Palworld-like): aloque um Eco e ele produz
    "serraria": {"name": L("Serraria Eco", "Echo Lumberyard"), "kind": "machine", "cost": {"madeira": 15, "pedra": 5, "corda": 2}, "lvl": 3, "shape": "sawmill",
                 "work": "corte", "output": {"madeira": 1.0, "seiva": 0.08, "tabua": 0.15}, "rate": 30},
    "pedreira": {"name": L("Pedreira Eco", "Echo Quarry"), "kind": "machine", "cost": {"madeira": 10, "pedra": 15}, "lvl": 3, "shape": "quarry",
                 "work": "mineracao", "output": {"pedra": 1.0, "carvao": 0.25}, "rate": 30},
    "horta": {"name": L("Horta Eco", "Echo Garden"), "kind": "machine", "cost": {"madeira": 8, "fibra": 10, "baga": 5}, "lvl": 2, "shape": "garden",
              "work": "coleta", "alt_work": "irrigacao", "output": {"baga": 1.0, "fibra": 0.6, "cogumelo": 0.15}, "rate": 30},
    "mina": {"name": L("Mina Eco", "Echo Mine"), "kind": "machine", "cost": {"tabua": 10, "pedra": 20, "lingote_ferro": 2}, "lvl": 7, "shape": "mine",
             "work": "mineracao", "output": {"minerio_ferro": 1.0, "carvao": 0.4, "cristal": 0.05}, "rate": 18},
    "fundicao_eco": {"name": L("Fundição Eco", "Echo Smelter"), "kind": "machine", "cost": {"tijolo": 10, "lingote_ferro": 4, "pedra": 10}, "lvl": 9, "shape": "smelter",
                     "work": "chama", "output": {"lingote_ferro": 1.0, "vidro": 0.3}, "rate": 8},
    "rancho": {"name": L("Rancho de Ecos", "Echo Ranch"), "kind": "machine", "cost": {"madeira": 20, "fibra": 10, "baga": 10}, "lvl": 4, "shape": "ranch",
               "work": "any", "output": {"pele": 0.6, "carne_crua": 0.6, "po_eco": 0.3}, "rate": 10},
}
