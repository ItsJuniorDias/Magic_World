#!/usr/bin/env python3
"""
make_plan.py — monta o plano das 50 histórias.

Roda uma vez por alteração no plano e regrava scripts/plan.md. As datas
são calculadas a partir do último publishedAt já escrito, uma por quarta-
feira, então elas nunca colidem nem pulam por engano.

    python3 scripts/make_plan.py
"""

import collections
import datetime
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTENT = ROOT / "Magic World" / "Content" / "Stories"
OUT = ROOT / "scripts" / "plan.md"

# 44 contos por escrever. Ordem = ordem de publicação e de escrita.
# Alternada entre habitats de propósito: assim a prateleira "Just arrived"
# nunca fica com três do mesmo bicho seguidos.
#
# (id, título, criatura, habitat, premissa numa linha)
PLAN = [
    ("the-boar-who-remembered-roads", "The Boar Who Remembered Roads",
     "A boar who has walked every path that ever existed", "forest",
     "The lane to the mill was closed in 1890. The boar still uses it."),
    ("the-seal-who-waits", "The Seal Who Waits",
     "A seal who surfaces only for someone about to give up", "tides",
     "Every fisherman in the bay has seen her once. None of them twice."),
    ("the-swift-that-never-landed", "The Swift That Never Landed",
     "A swift eleven years in the air", "skies",
     "Ada works out that the bird outside her window has not touched ground since she was born."),
    ("the-cat-who-walks-you-home", "The Cat Who Walks You Home",
     "A cat who appears at the far end of a dark street", "nightfall",
     "It never comes when you call it and it is always there when you are frightened."),
    ("the-hare-that-turns-first", "The Hare That Turns First",
     "A hare who goes white a week before the snow", "frost",
     "The village plants by the hare, not by the calendar, and this year the hare turned in October."),

    ("the-weather-stag", "The Weather Stag",
     "A stag whose antlers grow the shape of the coming season", "forest",
     "Petra learns to read the new points before the first frost does the telling."),
    ("what-the-gull-brought-back", "What the Gull Brought Back",
     "A gull who returns what the sea took", "tides",
     "It leaves things on the harbour wall. Nobody has ever claimed the small blue shoe."),
    ("the-kestrel-over-the-lost-thing", "The Kestrel Over the Lost Thing",
     "A kestrel who hangs still above whatever is missing", "skies",
     "It held its place over the same field for four days before anyone thought to go and look."),
    ("the-hedgehog-and-the-last-hour", "The Hedgehog and the Last Hour",
     "A hedgehog who collects the last hour of the day", "nightfall",
     "Rui finds a shoebox under the hedge with eleven evenings in it."),
    ("the-ermine-with-the-thaw", "The Ermine With the Thaw",
     "An ermine who carries the thaw in her mouth", "frost",
     "She will not put it down until somebody in the valley asks her to, properly."),

    ("the-fox-only-the-lost-can-see", "The Fox Only the Lost Can See",
     "A fox visible only to someone who has lost their way", "forest",
     "Tam sees it constantly, which worries him more than the wood does."),
    ("the-eel-who-maps-the-drowned-lane", "The Eel Who Maps the Drowned Lane",
     "An eel who knows the streets under the reservoir", "tides",
     "The village is eleven metres down. Someone still has to remember the way to the church."),
    ("the-geese-with-the-winters-post", "The Geese With the Winter's Post",
     "Geese who carry a season of letters at once", "skies",
     "They go over on one night in October and everything unsaid goes with them."),
    ("the-owl-who-knows-your-middle-name", "The Owl Who Knows Your Middle Name",
     "An owl who knows the name nobody uses", "nightfall",
     "It says hers out loud on the landing, and she has not told a single person at that school."),
    ("the-ptarmigan-that-hid-a-village", "The Ptarmigan That Hid a Village",
     "A ptarmigan who hides what the storm is looking for", "frost",
     "For two days in 1953 the pass could not find the houses, and the houses were fine."),

    ("the-badgers-lost-property", "The Badger's Lost Property",
     "A badger who runs a lost-property office under a root", "forest",
     "Everything left in the wood since 1911, catalogued, and the catalogue is the problem."),
    ("the-octopus-and-the-net-library", "The Octopus and the Net Library",
     "An octopus who keeps what the nets bring up", "tides",
     "Eight shelves, arranged by what the object was for, not by what it is."),
    ("the-bat-who-draws-the-dark", "The Bat Who Draws the Dark",
     "A bat who can describe a room she has never seen lit", "skies",
     "Joaquim is going blind and the bat is the first thing that does not talk around it."),
    ("the-donkey-carrying-sleep", "The Donkey Carrying Sleep",
     "A donkey who takes sleep up the hill each evening", "nightfall",
     "The top houses always get it last, and this week the donkey is lame."),
    ("the-musk-ox-where-wind-starts", "The Musk Ox Where the Wind Starts",
     "A musk ox who stands at the place the wind begins", "frost",
     "Kenna walks north to ask him to stand somewhere else, which is not how it works."),

    ("the-clock-toad", "The Clock Toad",
     "A toad who keeps the only clock the wood agrees on", "forest",
     "He has been seven minutes slow since the war and nobody wants to be the one to mention it."),
    ("the-salmon-carrying-a-name", "The Salmon Carrying a Name",
     "A salmon who takes a name upriver", "tides",
     "You give it a name at the mouth and it takes the name to the source, and that is all it does."),
    ("the-lark-holding-morning-open", "The Lark Holding Morning Open",
     "A lark whose song keeps the morning from closing", "skies",
     "On the day she does not sing, the village discovers what the song was for."),
    ("the-glow-worms-of-the-waiting-place", "The Glow-Worms of the Waiting Place",
     "Glow-worms who mark where somebody waited", "nightfall",
     "There is a bright patch by the bus stop that has been bright for forty years."),
    ("the-goose-under-the-ice", "The Goose Under the Ice",
     "A goose in the lake ice who is not dead", "frost",
     "Every child in the village has been told not to look. Sanna looks."),

    ("the-web-that-catches-sound", "The Web That Catches Sound",
     "A spider whose web catches what was said", "forest",
     "It is full by August, and in September it has to be emptied somewhere."),
    ("the-turtle-older-than-the-wall", "The Turtle Older Than the Wall",
     "A turtle who was there before the harbour", "tides",
     "The engineers want to move the wall. Someone should probably ask her first."),
    ("the-starling-map", "The Starling Map",
     "Starlings who murmurate into a map of somewhere", "skies",
     "Every evening for a week they draw the same coastline, and it is not this one."),
    ("the-mouse-who-lights-the-stairs", "The Mouse Who Lights the Stairs",
     "A mouse who carries a light up ahead of you", "nightfall",
     "The bulb on the second landing has been out since March and nobody has fixed it, on purpose."),
    ("the-wolves-who-keep-the-ice-honest", "The Wolves Who Keep the Ice Honest",
     "Wolves who will not cross ice that will not hold", "frost",
     "The safest route across the lake is wherever they walked yesterday."),

    ("the-woodpeckers-doors", "The Woodpecker's Doors",
     "A woodpecker who opens doors in trees", "forest",
     "Nils gets in easily. Getting out is a separate arrangement."),
    ("the-stork-of-apologies", "The Stork of Apologies",
     "A stork who delivers the apology you could not say", "skies",
     "You write it, you do not sign it, and you never find out whether it landed."),
    ("the-nightingale-of-forgotten-parts", "The Nightingale of Forgotten Parts",
     "A nightingale who sings the parts of a story people drop", "nightfall",
     "Every family tells the same story about the fire. The bird sings the rest of it."),
    ("the-fox-who-hid-warm-things", "The Fox Who Hid Warm Things",
     "An arctic fox who buries anything warm", "frost",
     "The lost gloves are all in one place, and it is not a hiding place, it is a store."),

    ("the-ants-who-carry-arguments", "The Ants Who Carry Arguments",
     "Ants who take away what a house has been arguing about", "forest",
     "Leaving the window open is how you ask, and asking has a cost nobody mentions."),
    ("the-shoal-that-writes-the-tide", "The Shoal That Writes the Tide",
     "A shoal who spell out the water to come", "tides",
     "The harbour used to read them. Now there is an app, and the app was wrong on the Tuesday."),
    ("the-dragonfly-in-two-summers", "The Dragonfly in Two Summers",
     "A dragonfly who is in this summer and one other", "skies",
     "Elin sees it land on the same reed twice, thirty years apart, and both times she is eleven."),
    ("the-marten-who-trades", "The Marten Who Trades",
     "A marten who leaves something better than what she takes", "nightfall",
     "The rule is that you may not choose what she takes, and everyone tries anyway."),
    ("the-reindeer-with-the-first-snow", "The Reindeer With the First Snow",
     "A reindeer who brings the first snow down", "frost",
     "He has been late three years running and the herders have stopped pretending not to notice."),

    ("the-wolf-on-the-boundary", "The Wolf on the Boundary",
     "A wolf who walks the line between two villages", "forest",
     "Neither village has spoken to the other since 1974. The wolf goes to both."),
    ("the-cormorants-count", "The Cormorant's Count",
     "A cormorant who counts the boats out and in", "tides",
     "Twenty-two out. She waits on the post until twenty-two come back, however long that takes."),
    ("the-weathercock-that-turns-early", "The Weathercock That Turns Early",
     "A weathervane bird who turns before the wind does", "skies",
     "It moved on a still Thursday and the whole town watched it move."),
    ("the-firefly-bridge", "The Firefly Bridge",
     "Fireflies who light a crossing one night a year", "nightfall",
     "The bridge fell in 1998. For one night in June you can still get across."),
    ("the-snow-leopard-nobody-photographed", "The Snow Leopard Nobody Photographed",
     "A snow leopard who has never been in a picture", "frost",
     "Sixty-one people have seen her. There are sixty-one photographs of an empty slope."),
]

# Que contos ficam grátis. Padrão do Grimoire: 3 de 50.
# Dois já estão escritos (the-glass-heron, where-the-moths-sleep).
FREE_EXTRA = {"the-cat-who-walks-you-home"}


def existing():
    ids = json.loads((CONTENT / "stories.json").read_text())["stories"]
    out = []
    for sid in ids:
        s = json.loads((CONTENT / f"{sid}.json").read_text())
        out.append((sid, s["title"], s["creature"], s["realm"],
                    s["isFree"], s["publishedAt"]))
    return out


def main():
    done = existing()
    written = {e[0] for e in done}
    last = max(datetime.date.fromisoformat(e[5]) for e in done)

    # Conto que ja saiu do plano e virou arquivo nao entra na fila de novo,
    # senao ele conta duas vezes no balanco e empurra todas as datas.
    pending = [e for e in PLAN if e[0] not in written]

    rows = []
    for i, (sid, title, creature, realm, premise) in enumerate(pending, start=1):
        rows.append({
            "id": sid, "title": title, "creature": creature, "realm": realm,
            "isFree": sid in FREE_EXTRA,
            "publishedAt": (last + datetime.timedelta(weeks=i)).isoformat(),
            "premise": premise,
        })

    balance = collections.Counter(e[3] for e in done)
    balance.update(r["realm"] for r in rows)
    free_total = sum(1 for e in done if e[4]) + sum(1 for r in rows if r["isFree"])

    lines = [
        "# Plano — 50 contos",
        "",
        f"Gerado por `scripts/make_plan.py`. {len(done)} escritos, {len(rows)} por escrever.",
        "",
        "Datas são quartas-feiras consecutivas a partir do último conto escrito, ",
        "calculadas pelo script — não edite à mão.",
        "",
        "## Balanço",
        "",
        "| habitat | total |",
        "| --- | --- |",
    ]
    for realm in ["forest", "tides", "skies", "nightfall", "frost"]:
        lines.append(f"| {realm} | {balance[realm]} |")
    lines += ["", f"Grátis: {free_total} de 50.", "",
              "## Escritos", "",
              "| # | id | criatura | habitat | publica |",
              "| --- | --- | --- | --- | --- |"]
    for n, (sid, _t, creature, realm, _f, date) in enumerate(done, start=1):
        lines.append(f"| {n} | `{sid}` | {creature} | {realm} | {date} |")

    lines += ["", "## Por escrever", "",
              "| # | id | criatura | habitat | publica | premissa |",
              "| --- | --- | --- | --- | --- | --- |"]
    for n, r in enumerate(rows, start=len(done) + 1):
        free = " ·grátis" if r["isFree"] else ""
        lines.append(f"| {n} | `{r['id']}`{free} | {r['creature']} | "
                     f"{r['realm']} | {r['publishedAt']} | {r['premise']} |")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"{OUT.relative_to(ROOT)}")
    print(f"  {len(done)} escritos, {len(rows)} por escrever")
    print(f"  balanço: {dict(balance)}")
    print(f"  grátis: {free_total}")
    if rows:
        print(f"  última publicação: {rows[-1]['publishedAt']}")
    else:
        print("  acervo completo — nada na fila")
    bad = [r for r in balance.values() if r != 10]
    if bad:
        print(f"  ! habitats fora de 10: {dict(balance)}")


if __name__ == "__main__":
    main()
