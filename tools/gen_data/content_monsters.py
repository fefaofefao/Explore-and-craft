# -*- coding: utf-8 -*-
"""Tipos, habilidades e espécies de Ecos (monstros)."""


def L(pt, en):
    return {"pt": pt, "en": en}


TYPES = {
    "order": ["flora", "brasa", "mare", "gelo", "volt", "terra", "sombra", "luz"],
    "names": {
        "flora": L("Flora", "Flora"), "brasa": L("Brasa", "Ember"), "mare": L("Maré", "Tide"),
        "gelo": L("Gelo", "Frost"), "volt": L("Volt", "Volt"), "terra": L("Terra", "Earth"),
        "sombra": L("Sombra", "Shade"), "luz": L("Luz", "Light"),
    },
    "colors": {
        "flora": "#5fbf4a", "brasa": "#ff7a2f", "mare": "#3a9cff", "gelo": "#9fe6ff",
        "volt": "#ffd93a", "terra": "#b8864b", "sombra": "#8a5cd6", "luz": "#fff3a8",
    },
    # atacante -> lista de tipos contra os quais é super efetivo (x1.5)
    "strong": {
        "flora": ["mare", "terra"], "brasa": ["flora", "gelo"], "mare": ["brasa", "terra"],
        "gelo": ["flora", "volt"], "volt": ["mare", "luz"], "terra": ["volt", "brasa"],
        "sombra": ["luz", "flora"], "luz": ["sombra", "gelo"],
    },
    "super": 1.5,
    "weak": 0.67,
}

# kind: melee | projectile | aoe | heal | buff
SKILLS = {
    # Flora
    "folha_navalha": {"name": L("Folha Navalha", "Razor Leaf"), "type": "flora", "power": 40, "cd": 3.0, "kind": "projectile", "range": 10},
    "chicote_vinha": {"name": L("Chicote de Vinha", "Vine Whip"), "type": "flora", "power": 65, "cd": 6.0, "kind": "melee", "range": 3.5},
    "esporos": {"name": L("Nuvem de Esporos", "Spore Cloud"), "type": "flora", "power": 55, "cd": 9.0, "kind": "aoe", "range": 6},
    "fotossintese": {"name": L("Fotossíntese", "Photosynthesis"), "type": "flora", "power": 35, "cd": 14.0, "kind": "heal", "range": 0},
    "floresta_furia": {"name": L("Fúria da Floresta", "Forest Fury"), "type": "flora", "power": 110, "cd": 16.0, "kind": "aoe", "range": 8},
    # Brasa
    "fagulha": {"name": L("Fagulha", "Ember Spark"), "type": "brasa", "power": 40, "cd": 3.0, "kind": "projectile", "range": 10},
    "investida_chama": {"name": L("Investida em Chamas", "Flame Rush"), "type": "brasa", "power": 70, "cd": 6.5, "kind": "melee", "range": 4},
    "anel_fogo": {"name": L("Anel de Fogo", "Fire Ring"), "type": "brasa", "power": 60, "cd": 9.0, "kind": "aoe", "range": 6},
    "erupcao": {"name": L("Erupção", "Eruption"), "type": "brasa", "power": 115, "cd": 16.0, "kind": "aoe", "range": 8},
    # Maré
    "jato_agua": {"name": L("Jato d'Água", "Water Jet"), "type": "mare", "power": 40, "cd": 3.0, "kind": "projectile", "range": 10},
    "onda": {"name": L("Onda", "Surf Wave"), "type": "mare", "power": 60, "cd": 8.0, "kind": "aoe", "range": 6},
    "bolha_cura": {"name": L("Bolha Curativa", "Healing Bubble"), "type": "mare", "power": 40, "cd": 14.0, "kind": "heal", "range": 0},
    "maremoto": {"name": L("Maremoto", "Tidal Crash"), "type": "mare", "power": 115, "cd": 16.0, "kind": "aoe", "range": 8},
    # Gelo
    "estilhaco": {"name": L("Estilhaço de Gelo", "Ice Shard"), "type": "gelo", "power": 40, "cd": 3.0, "kind": "projectile", "range": 10},
    "presa_gelida": {"name": L("Presa Gélida", "Frost Fang"), "type": "gelo", "power": 68, "cd": 6.0, "kind": "melee", "range": 3.5},
    "nevasca": {"name": L("Nevasca", "Blizzard"), "type": "gelo", "power": 105, "cd": 15.0, "kind": "aoe", "range": 8},
    # Volt
    "faisca": {"name": L("Faísca", "Spark"), "type": "volt", "power": 42, "cd": 3.0, "kind": "projectile", "range": 11},
    "raio": {"name": L("Raio", "Thunderbolt"), "type": "volt", "power": 75, "cd": 7.0, "kind": "projectile", "range": 12},
    "sobrecarga": {"name": L("Sobrecarga", "Overcharge"), "type": "volt", "power": 0, "cd": 18.0, "kind": "buff", "range": 0},
    "tempestade": {"name": L("Tempestade", "Thunderstorm"), "type": "volt", "power": 112, "cd": 16.0, "kind": "aoe", "range": 9},
    # Terra
    "pedrada": {"name": L("Pedrada", "Rock Throw"), "type": "terra", "power": 45, "cd": 3.5, "kind": "projectile", "range": 9},
    "pancada": {"name": L("Pancada Sísmica", "Seismic Slam"), "type": "terra", "power": 72, "cd": 6.5, "kind": "melee", "range": 3.5},
    "terremoto": {"name": L("Terremoto", "Earthquake"), "type": "terra", "power": 110, "cd": 16.0, "kind": "aoe", "range": 9},
    "carapaca": {"name": L("Carapaça", "Stone Shell"), "type": "terra", "power": 0, "cd": 18.0, "kind": "buff", "range": 0},
    # Sombra
    "garra_sombria": {"name": L("Garra Sombria", "Shadow Claw"), "type": "sombra", "power": 48, "cd": 3.5, "kind": "melee", "range": 3.5},
    "esfera_sombra": {"name": L("Esfera Sombria", "Shadow Orb"), "type": "sombra", "power": 72, "cd": 7.0, "kind": "projectile", "range": 11},
    "pesadelo": {"name": L("Pesadelo", "Nightmare"), "type": "sombra", "power": 112, "cd": 16.0, "kind": "aoe", "range": 8},
    # Luz
    "lampejo": {"name": L("Lampejo", "Flash"), "type": "luz", "power": 42, "cd": 3.0, "kind": "projectile", "range": 11},
    "prisma": {"name": L("Prisma", "Prism Beam"), "type": "luz", "power": 74, "cd": 7.0, "kind": "projectile", "range": 12},
    "aurora_cura": {"name": L("Aurora Curativa", "Aurora Mend"), "type": "luz", "power": 50, "cd": 15.0, "kind": "heal", "range": 0},
    "julgamento": {"name": L("Julgamento", "Judgement"), "type": "luz", "power": 118, "cd": 16.0, "kind": "aoe", "range": 9},
}

TYPE_SKILLS = {
    "flora": ["folha_navalha", "chicote_vinha", "esporos", "fotossintese", "floresta_furia"],
    "brasa": ["fagulha", "investida_chama", "anel_fogo", "erupcao"],
    "mare": ["jato_agua", "onda", "bolha_cura", "maremoto"],
    "gelo": ["estilhaco", "presa_gelida", "nevasca"],
    "volt": ["faisca", "raio", "sobrecarga", "tempestade"],
    "terra": ["pedrada", "pancada", "carapaca", "terremoto"],
    "sombra": ["garra_sombria", "esfera_sombra", "pesadelo"],
    "luz": ["lampejo", "prisma", "aurora_cura", "julgamento"],
}


def learnset(t1, t2=None):
    """Habilidades aprendidas por nível: básica do tipo 1 no 1, segunda no 7, etc."""
    s1 = TYPE_SKILLS[t1]
    out = [[1, s1[0]], [7, s1[1]]]
    if t2:
        s2 = TYPE_SKILLS[t2]
        out += [[12, s2[0]], [18, s1[2]], [26, s2[1]], [34, s1[-1]]]
    else:
        out += [[14, s1[2]], [24, s1[3] if len(s1) > 3 else s1[-1]], [34, s1[-1]]]
    # remove duplicados mantendo ordem
    seen, res = set(), []
    for lv, sk in out:
        if sk not in seen:
            seen.add(sk)
            res.append([lv, sk])
    return res


# body: shape (round|quad|bird|serpent|golem|biped), size, color, color2, ears, horns, tail, wings, eyes, extras
def body(shape, size, color, color2, ears="none", horns="none", tail="none", wings=False, eyes="round", extra="none"):
    return {"shape": shape, "size": size, "color": color, "color2": color2, "ears": ears, "horns": horns,
            "tail": tail, "wings": wings, "eyes": eyes, "extra": extra}


# work skills: corte, mineracao, coleta, chama, irrigacao, cura (0-4)
SPECIES_RAW = [
    # id, nome, tipo1, tipo2, raridade, base hp/atk/def/spd, taxa captura, trabalho, corpo, temperamento, lore pt, lore en, evolui
    ("folhito", "Folhito", "flora", None, "comum", (45, 49, 49, 45), 0.55, {"corte": 1, "coleta": 2},
     body("round", 0.55, "#7cd65a", "#3f8f2e", ears="leaf", tail="leaf", extra="sprout"), "dócil",
     "Brota onde alguém chorou de alegria. Segue quem cuida das plantas.",
     "Sprouts wherever someone cried with joy. Follows those who tend plants.", ("folhagrao", 16)),
    ("folhagrao", "Folhagrão", "flora", "terra", "incomum", (70, 72, 78, 55), 0.25, {"corte": 3, "coleta": 3},
     body("quad", 1.0, "#5fae47", "#7a5530", ears="leaf", tail="leaf", extra="sprout"), "dócil",
     "Carrega um pequeno bosque nas costas. Lembra de cada árvore que já existiu.",
     "Carries a small grove on its back. Remembers every tree that ever lived.", None),
    ("brasito", "Brasito", "brasa", None, "comum", (39, 55, 43, 65), 0.55, {"chama": 2, "mineracao": 1},
     body("quad", 0.55, "#ff8a3d", "#ffd34d", ears="small", tail="flame", eyes="happy"), "brincalhão",
     "Sua cauda arde mais forte quando ouve risadas.",
     "Its tail burns brighter whenever it hears laughter.", ("brasaurus", 16)),
    ("brasaurus", "Brasaurus", "brasa", "terra", "incomum", (68, 84, 66, 75), 0.25, {"chama": 4, "mineracao": 2},
     body("quad", 1.1, "#e8642a", "#5a3a2a", horns="twin", tail="flame"), "valente",
     "Forja metal com o próprio hálito. Os ferreiros de Ferrugem o temiam e o veneravam.",
     "Forges metal with its breath. Rustport's smiths both feared and revered it.", None),
    ("marolo", "Marolo", "mare", None, "comum", (50, 44, 56, 43), 0.55, {"irrigacao": 2, "coleta": 1},
     body("round", 0.6, "#5bb6ff", "#e8f6ff", ears="fin", tail="fish", eyes="happy"), "dócil",
     "Canta baixinho antes de chover. Ninguém sabe para quem.",
     "Hums softly before it rains. Nobody knows who it sings to.", ("marujao", 16)),
    ("marujao", "Marujão", "mare", "gelo", "incomum", (82, 70, 80, 58), 0.25, {"irrigacao": 4, "coleta": 2},
     body("quad", 1.1, "#3f8fe0", "#d8f2ff", ears="fin", tail="fish", horns="tusk"), "calmo",
     "Guarda os náufragos até o amanhecer. Depois finge que não viu nada.",
     "Guards castaways until dawn, then pretends it saw nothing.", None),
    ("espinhoz", "Espinhoz", "flora", None, "comum", (40, 52, 60, 40), 0.6, {"corte": 2},
     body("quad", 0.5, "#8f6b3e", "#6cc24a", ears="small", extra="spikes"), "tímido",
     "Enrola-se numa bola de espinhos quando sente medo. Sente medo com frequência.",
     "Curls into a spiky ball when scared. It is scared often.", None),
    ("cogulume", "Cogulume", "flora", "sombra", "comum", (48, 50, 45, 38), 0.6, {"coleta": 2, "cura": 1},
     body("round", 0.5, "#c24d6b", "#fff0e0", extra="mushroom", eyes="sleepy"), "sonolento",
     "Brilha à noite. Seus esporos causam sonhos com lugares que não existem mais.",
     "Glows at night. Its spores bring dreams of places that no longer exist.", None),
    ("pedrisco", "Pedrisco", "terra", None, "comum", (40, 60, 80, 25), 0.6, {"mineracao": 2},
     body("round", 0.5, "#9a8d80", "#6f6358", eyes="angry", extra="rocks"), "teimoso",
     "Come cascalho e arrota faíscas. Teimoso como uma montanha.",
     "Eats gravel and burps sparks. Stubborn as a mountain.", ("rochedo", 18)),
    ("rochedo", "Rochedo", "terra", None, "incomum", (80, 95, 115, 30), 0.25, {"mineracao": 4},
     body("golem", 1.3, "#8a7d70", "#c9a86a", eyes="angry", extra="rocks"), "teimoso",
     "Dorme por décadas. Algumas aldeias foram construídas em cima de um sem saber.",
     "Sleeps for decades. Some villages were built on top of one without knowing.", None),
    ("lumeflor", "Lumeflor", "luz", "flora", "raro", (55, 50, 55, 80), 0.3, {"coleta": 2, "cura": 3},
     body("bird", 0.45, "#fff2a8", "#ff9ed1", wings=True, extra="petals"), "gentil",
     "Fadas-flor que seguem a luz da Aurora. Dizem que guiam os perdidos para casa.",
     "Flower-sprites that follow the Aurora's light. They say it guides the lost home.", None),
    ("sombrino", "Sombrino", "sombra", None, "incomum", (45, 60, 45, 85), 0.4, {"coleta": 1},
     body("round", 0.5, "#4b3a78", "#b48cff", ears="horn", tail="wisp", eyes="glow"), "travesso",
     "Só aparece à noite. Rouba sombras dos outros por diversão — e devolve.",
     "Only appears at night. Steals others' shadows for fun — then gives them back.", None),
    ("areiao", "Areião", "terra", None, "comum", (50, 62, 50, 70), 0.5, {"mineracao": 2, "coleta": 1},
     body("quad", 0.65, "#e0b66a", "#fff1cf", ears="big", tail="fluffy"), "curioso",
     "Raposa das dunas. Escuta água correndo a quilômetros debaixo da areia.",
     "Dune fox. Hears water running miles beneath the sand.", None),
    ("escarabrilho", "Escarabrilho", "luz", "terra", "comum", (48, 55, 70, 50), 0.5, {"mineracao": 1, "cura": 1},
     body("quad", 0.45, "#3fd0b0", "#ffe27a", horns="single", extra="shell"), "trabalhador",
     "Rola esferas de âmbar e as polia até brilharem como pequenos sóis.",
     "Rolls amber spheres and polishes them until they shine like tiny suns.", None),
    ("serpenduna", "Serpenduna", "terra", "brasa", "incomum", (60, 75, 55, 72), 0.35, {"mineracao": 3},
     body("serpent", 1.0, "#d49a4a", "#7a3b1e", horns="single", eyes="angry"), "agressivo",
     "Nada sob a areia quente. Quando emerge, o chão treme.",
     "Swims beneath hot sand. When it surfaces, the ground trembles.", None),
    ("cactuto", "Cactuto", "flora", None, "comum", (55, 55, 65, 30), 0.55, {"irrigacao": 2, "coleta": 2},
     body("golem", 0.6, "#4fae5a", "#ff7ab0", extra="cactus", eyes="happy"), "dócil",
     "Guarda água para viajantes perdidos. Abraços doem, mas são sinceros.",
     "Stores water for lost travelers. Its hugs hurt, but they're sincere.", None),
    ("flocolino", "Flocolino", "gelo", None, "comum", (44, 48, 50, 70), 0.55, {"coleta": 2},
     body("round", 0.5, "#f4fbff", "#9fd8ff", ears="bunny", tail="fluffy"), "dócil",
     "Coelho de neve. Seu pelo nunca derrete, nem dentro de uma fornalha.",
     "Snow bunny. Its fur never melts, not even inside a furnace.", None),
    ("pinguelo", "Pinguelo", "gelo", "mare", "comum", (52, 52, 55, 45), 0.5, {"irrigacao": 2, "coleta": 1},
     body("biped", 0.55, "#2d3e5a", "#ffffff", tail="small", eyes="happy"), "brincalhão",
     "Desliza de barriga pelas encostas. Organiza corridas com os amigos.",
     "Slides belly-first down slopes. Organizes races with its friends.", None),
    ("lupigelo", "Lupigelo", "gelo", None, "incomum", (65, 80, 60, 85), 0.35, {"corte": 2, "coleta": 2},
     body("quad", 0.9, "#cfe9ff", "#5b7fa8", ears="pointy", tail="fluffy", eyes="angry"), "leal",
     "Lobo da geada. Uiva para a Aurora em noites claras e nunca abandona a matilha.",
     "Frost wolf. Howls at the Aurora on clear nights and never abandons its pack.", None),
    ("faiscaro", "Faíscaro", "volt", None, "incomum", (50, 65, 45, 100), 0.4, {"chama": 1, "mineracao": 1},
     body("bird", 0.55, "#ffe14a", "#2f2f3a", wings=True, tail="bolt", eyes="angry"), "agitado",
     "Pássaro-raio. Carrega energia estática suficiente para acender uma vila.",
     "Lightning bird. Carries enough static to light up a village.", None),
    ("mamutundra", "Mamutundra", "gelo", "terra", "raro", (100, 90, 95, 30), 0.2, {"mineracao": 3, "corte": 3},
     body("quad", 1.6, "#8a6a52", "#e8f4ff", horns="tusk", ears="big", tail="small"), "calmo",
     "Gigante gentil das tundras. Lembra rotas de migração de mil anos atrás.",
     "Gentle tundra giant. Remembers migration routes from a thousand years ago.", None),
    ("fagulhas", "Fagulhas", "brasa", None, "comum", (45, 58, 40, 80), 0.5, {"chama": 3},
     body("bird", 0.5, "#ff5a2a", "#ffcf3a", wings=True, tail="flame"), "alegre",
     "Pássaro-brasa. Acende fogueiras para viajantes com frio — às vezes sem pedir.",
     "Ember bird. Lights campfires for cold travelers — sometimes uninvited.", None),
    ("corvoleta", "Corvoleta", "sombra", None, "comum", (48, 62, 42, 88), 0.45, {"coleta": 2},
     body("bird", 0.55, "#2a2440", "#8a5cd6", wings=True, eyes="glow"), "esperto",
     "Coleciona objetos brilhantes e segredos. Troca os dois por comida.",
     "Collects shiny things and secrets. Trades both for food.", None),
    ("ferrugente", "Ferrugente", "volt", "terra", "incomum", (70, 78, 90, 40), 0.3, {"mineracao": 3, "chama": 2},
     body("golem", 1.0, "#9a5a3a", "#5fd0ff", horns="antenna", eyes="visor", extra="collar"), "confuso",
     "Eco de metal vivo, nascido nas fundições de Ferrugem. A coleira o faz esquecer quem é.",
     "Living-metal Echo born in Rustport's foundries. The collar makes it forget who it is.", None),
    # ---- Ato 2
    ("lodolfo", "Lodolfo", "mare", "sombra", "comum", (65, 68, 60, 50), 0.45, {"irrigacao": 3},
     body("serpent", 0.9, "#4b6b4a", "#a8d86a", eyes="sleepy", horns="none"), "preguiçoso",
     "Dorme no lodo e sonha alto: o pântano inteiro ouve.",
     "Sleeps in the mud and dreams out loud: the whole swamp hears it.", None),
    ("pantanossauro", "Pantanossauro", "mare", "flora", "incomum", (90, 80, 85, 40), 0.3, {"irrigacao": 3, "corte": 3},
     body("quad", 1.4, "#3d7a5a", "#d8c06a", horns="twin", tail="long", extra="moss"), "calmo",
     "Ilhas inteiras de musgo crescem sobre ele. Pássaros fazem ninho em suas costas.",
     "Whole islands of moss grow on it. Birds nest on its back.", None),
    ("magmarujo", "Magmarujo", "brasa", "terra", "incomum", (85, 92, 88, 35), 0.3, {"chama": 4, "mineracao": 3},
     body("golem", 1.2, "#3a2a2a", "#ff6a1a", eyes="glow", extra="lava"), "valente",
     "Sangra lava quando está feliz. Os ferreiros chamam isso de bênção.",
     "Bleeds lava when happy. Smiths call it a blessing.", None),
    ("vulcanix", "Vulcanix", "brasa", None, "raro", (75, 100, 70, 95), 0.2, {"chama": 4},
     body("quad", 1.0, "#c22a1a", "#ffb83a", ears="pointy", tail="flame", horns="twin", eyes="angry"), "orgulhoso",
     "Raposa vulcânica de nove brasas. Só obedece a quem a encara sem piscar.",
     "Nine-ember volcanic fox. Only obeys those who meet its gaze unblinking.", None),
    ("tempestor", "Tempestor", "volt", "luz", "incomum", (70, 85, 60, 105), 0.3, {"chama": 2, "coleta": 2},
     body("bird", 0.9, "#4a5aff", "#ffe14a", wings=True, tail="bolt", horns="crest"), "agitado",
     "Nasce dentro de nuvens carregadas. Seu grito antecede o trovão.",
     "Born inside storm clouds. Its cry comes before the thunder.", None),
    ("coralume", "Coralume", "mare", "luz", "raro", (70, 60, 75, 70), 0.25, {"irrigacao": 3, "cura": 4},
     body("round", 0.7, "#ff8fb0", "#7ff0ff", extra="coral", eyes="happy"), "gentil",
     "Recife vivo. Sua luz cura feridas e acalma tempestades.",
     "A living reef. Its light heals wounds and calms storms.", None),
    ("nevoeiro", "Nevoeiro", "sombra", "mare", "incomum", (60, 75, 55, 90), 0.35, {"coleta": 2},
     body("serpent", 0.8, "#7a8a9a", "#c8f0ff", eyes="glow", tail="wisp"), "misterioso",
     "Ninguém viu seu corpo inteiro. Talvez ele seja a própria névoa.",
     "Nobody has seen its whole body. Perhaps it is the fog itself.", None),
]

# Guardiões (Alfas), chefes e Ecos dos ditadores: variações maiores com atributos próprios
BOSSES_RAW = [
    ("anciao_musgoso", "Ancião Musgoso", "flora", "terra", (120, 85, 95, 30), {"corte": 4},
     body("golem", 2.4, "#4e7d3a", "#8a6a3a", eyes="glow", extra="moss"),
     "Guardião do Bosque do Berço. Protege a Seiva Ancestral há trezentos anos.",
     "Guardian of the Cradle Grove. Has protected the Ancient Sap for three hundred years."),
    ("ambarraque", "Ambarraque", "terra", "luz", (115, 95, 100, 55), {"mineracao": 4},
     body("quad", 2.2, "#d99a2a", "#fff1a0", horns="twin", tail="stinger", eyes="glow", extra="shell"),
     "Escorpião colossal do Templo Solar. Seu olho guarda a luz de um sol antigo.",
     "Colossal scorpion of the Sun Temple. Its eye holds the light of an ancient sun."),
    ("serpegelo", "Serpegelo", "gelo", "mare", (125, 95, 90, 60), {"irrigacao": 4},
     body("serpent", 2.6, "#aee8ff", "#3a6ab0", horns="crest", eyes="glow"),
     "Wyrm glacial que chora cristais. Cada lágrima é uma memória congelada.",
     "A glacial wyrm that weeps crystals. Every tear is a frozen memory."),
    ("ferro_colosso", "Ferro-Colosso", "volt", "terra", (150, 110, 120, 40), {"mineracao": 4, "chama": 4},
     body("golem", 2.4, "#6a4a3a", "#ff4a2a", horns="antenna", eyes="visor", extra="collar"),
     "O Eco que o Barão Vorn acorrentou ao coração da fundição. Ele grita sem som.",
     "The Echo Baron Vorn chained to the foundry's heart. It screams without sound."),
    ("lodorei", "Lodorei", "mare", "sombra", (140, 100, 105, 45), {"irrigacao": 4},
     body("serpent", 2.6, "#2d4a2d", "#c8ff6a", horns="crest", eyes="glow", extra="moss"),
     "Rei do Pântano Lúgubre. Engoliu a Raiz Negra para que ninguém a usasse.",
     "King of the Gloom Marsh. Swallowed the Black Root so no one could use it."),
    ("magmarca", "Magmarca", "brasa", "terra", (145, 115, 105, 40), {"chama": 4},
     body("golem", 2.5, "#2a1a1a", "#ff8a1a", eyes="glow", extra="lava"),
     "Coração vivo do Cânion Brasa. A Brasa Eterna pulsa em seu peito.",
     "Living heart of Ember Canyon. The Eternal Ember beats in its chest."),
    ("trovaguia", "Trovaguia", "volt", "luz", (130, 120, 85, 110), {"chama": 3},
     body("bird", 2.2, "#3a3aff", "#ffe14a", wings=True, tail="bolt", horns="crest", eyes="glow"),
     "Águia-trovão que ninguém jamais tocou. Suas penas atraem raios.",
     "A thunder-eagle no one has ever touched. Its feathers draw lightning."),
    ("umbra_sable", "Umbra", "sombra", "luz", (160, 120, 110, 95), {"coleta": 4},
     body("quad", 2.3, "#1a1028", "#c890ff", ears="pointy", tail="wisp", horns="crest", eyes="glow"),
     "A pantera de sombra da Imperatriz Sable. Ela vê através dos olhos dela.",
     "Empress Sable's shadow panther. She sees through its eyes."),
]

RARITY_ORDER = ["comum", "incomum", "raro", "lendario"]


def build_species():
    sp = {}
    for (sid, name, t1, t2, rar, base, cap, work, bd, temper, lpt, len_, evo) in SPECIES_RAW:
        sp[sid] = {
            "name": L(name, name), "types": [t1] + ([t2] if t2 else []), "rarity": rar,
            "base": {"hp": base[0], "atk": base[1], "def": base[2], "spd": base[3]},
            "capture": cap, "work": work, "body": bd, "temper": temper,
            "lore": L(lpt, len_), "learnset": learnset(t1, t2),
            "evolves": {"to": evo[0], "level": evo[1]} if evo else None, "boss": False,
        }
    for (sid, name, t1, t2, base, work, bd, lpt, len_) in BOSSES_RAW:
        sp[sid] = {
            "name": L(name, name), "types": [t1, t2], "rarity": "lendario",
            "base": {"hp": base[0], "atk": base[1], "def": base[2], "spd": base[3]},
            "capture": 0.08, "work": work, "body": bd, "temper": "alfa",
            "lore": L(lpt, len_), "learnset": learnset(t1, t2), "evolves": None, "boss": True,
        }
    return sp
