#!/usr/bin/env python3
"""
add_settings.py — escreve o campo `setting:` no frontmatter dos 50 contos.

Motivo: o gerador de capas vinha montando o cenario a partir do HABITAT,
com cinco descricoes fixas. Isso funcionava com seis contos porque calhava
de bater. Com cinquenta, briga: the-bat-who-draws-the-dark e `skies` e se
passa inteiro num sotao, e the-cat-who-walks-you-home e `nightfall` e e uma
rua, nao o sotao das mariposas.

O cenario e uma propriedade da historia, nao do habitat, entao mora aqui.
Uma linha por conto, descrevendo o LUGAR FISICO que a capa mostra — nao o
enredo, nao o clima, o lugar.

Roda uma vez. Depois disso o campo e editado a mao no .md como qualquer
outro.
"""

import pathlib
import re

STORIES = pathlib.Path(__file__).resolve().parent / "stories"

SETTINGS = {
 "the-glass-heron":
   "A flooded village lane at first light. Water up to the gate tops between "
   "two rows of houses, fence posts breaking the surface, wet slate roofs.",
 "where-the-moths-sleep":
   "The inside of an attic at night. Rafters and roof slates close overhead, "
   "one bare bulb, dust in the air, pale shapes folded flat against the beams.",
 "the-bear-who-kept-winter":
   "A hollow under a leaning rock high on a mountain in late spring. Old snow "
   "with a clean edge, thin birch, frost standing in the grass.",
 "the-cartographer-hare":
   "The floor of a beech wood. Grey trunks, deep bracken, a bank of exposed "
   "roots, hard slanted bars of light between the stems.",
 "the-kite-crows":
   "A flat empty field under an enormous sky. A telephone wire across the "
   "frame, a low horizon, a distant church tower, a paper kite very high.",
 "the-lantern-otter":
   "Under a wooden pier at night. Barnacled pilings going down into black "
   "water, weed, the underside of the decking, one small warm light below.",

 "the-boar-who-remembered-roads":
   "A walled kitchen garden at night, seen from above. Vegetable beds, a "
   "shed, two apple trees, a thick blackthorn hedge, a stone wall.",
 "the-seal-who-waits":
   "A small open rowing boat on flat grey bay water under a low sky. Creel "
   "ropes and buoys, a rocky headland far off.",
 "the-swift-that-never-landed":
   "A council estate yard at dusk. Four telephone wires, a bin store, one "
   "tree, brick flats, an orange sky and birds very high above the roofs.",
 "the-cat-who-walks-you-home":
   "A narrow unlit street at night between a high wall and the blank back of "
   "a warehouse. One recessed doorway. Light returning only at the far corner.",
 "the-hare-that-turns-first":
   "A bare northern hillside above a small village in October. Cut grass, "
   "stone walls, birch, the roofs and one lit window far below.",

 "the-weather-stag":
   "The edge of a birch wood seen across a hill field in late summer. Pale "
   "trunks in ranks, long shadows, an animal standing well back in the trees.",
 "what-the-gull-brought-back":
   "A stone harbour wall at dawn. A line of cast iron bollards, wet steps "
   "going down, moored boats, a small object left on the third bollard.",
 "the-kestrel-over-the-lost-thing":
   "A neglected stubble field in autumn. Thistle, a cracked concrete pad, a "
   "wire fence and a road along one edge, wide flat country beyond.",
 "the-hedgehog-and-the-last-hour":
   "The bottom of a small back yard at dusk. A dense hedge, wet ground, a "
   "cardboard box, the backs of houses and one lit window behind.",
 "the-ermine-with-the-thaw":
   "A dry-stone wall running across a scree slope high on an alpine mountain "
   "in late winter. A ruined byre, deep snow, a black sky.",

 "the-fox-only-the-lost-can-see":
   "A village car park at dusk in winter. Bins, a low wall, a minibus, wet "
   "tarmac, a dark wood rising immediately behind.",
 "the-eel-who-maps-the-drowned-lane":
   "A drained reservoir bed in drought. A plain of cracked mud, a roofless "
   "stone church tower standing alone, shallow pools in a straight line.",
 "the-geese-with-the-winters-post":
   "The roofs of a small village at one in the morning. Chimneys, a chapel "
   "wall, folded papers left on windowsills, a great many birds passing low.",
 "the-owl-who-knows-your-middle-name":
   "A concrete stairwell landing in a tower block at night. A window with a "
   "narrow gap at the top corner, an external sill, city lights beyond.",
 "the-ptarmigan-that-hid-a-village":
   "A snow ridge above a hollow full of small roofs. Rock, deep drift, "
   "smoke lying flat, a whiteout closing the pass beyond.",

 "the-badgers-lost-property":
   "A boundary bank in a wood in November. A great beech with exposed roots, "
   "a dark gap between two of them, wet leaf litter, rain.",
 "the-octopus-and-the-net-library":
   "An underwater rock ledge eight metres down, seen sideways. An overhang "
   "with horizontal cracks in it, objects set into them, blue water above.",
 "the-clock-toad":
   "A ford at the bottom of a hornbeam wood at dusk. Flat stones, shallow "
   "fast water, a ruined mill gable, deep shadow under the trees.",
 "the-salmon-carrying-a-name":
   "A wide river mouth on a June morning. Green shallow water over shingle, "
   "a line of people standing knee deep, low green hills behind.",
 "the-lark-holding-morning-open":
   "A great flat barley field on a plain before sunrise. A road, a distant "
   "village and church tower, an enormous sky, one bird very high.",

 "the-glow-worms-of-the-waiting-place":
   "A high-banked country lane at night. A bus stop pole and timetable, a "
   "low wall, hedge on both sides, green points of light on the bank.",
 "the-goose-under-the-ice":
   "The frozen edge of a northern lake. Clear black ice, reeds, a low bank "
   "of birch, something pale held a few centimetres below the surface.",
 "the-web-that-catches-sound":
   "A stand of hornbeam on a valley side in August. Smooth grey trunks close "
   "together, a large grey sheet of web slung between two of them.",
 "the-turtle-older-than-the-wall":
   "A Mediterranean beach at night beside a concrete harbour arm. Sand, a "
   "wide flipper track going up from the water, the town lights turned off.",
 "the-starling-map":
   "A flat coastal marsh at last light. A long straight dyke, reed beds, an "
   "immense low sky, a dense band of birds folding over the horizon.",

 "the-mouse-who-lights-the-stairs":
   "A covered stone staircase climbing between old houses at night. Vaulting "
   "overhead, worn steps, an iron rail, one dead lamp on a landing.",
 "the-wolves-who-keep-the-ice-honest":
   "A frozen lake before dawn. Snow-crust and wind-scour, a reed edge, a "
   "single-file line of tracks running out across the open ice.",
 "the-woodpeckers-doors":
   "A northern spruce and birch forest in low light. Straight dark trunks, "
   "moss and blaeberry, a single round hole in one living trunk at head height.",
 "the-stork-of-apologies":
   "An Alsatian village church in late August. A stone north wall, a small "
   "wire basket on a bracket, tiled roofs, a stork nest on a chimney.",
 "the-nightingale-of-forgotten-parts":
   "Elder scrub behind a village church at night in May. Dense leaf, a "
   "whitewashed wall, a bell tower, houses beyond with two lit windows.",

 "the-fox-who-hid-warm-things":
   "A treeless Icelandic ridge above the sea. Lava rock, low turf, a flat "
   "slab lying half buried, grey water and a farm roof far below.",
 "the-ants-who-carry-arguments":
   "A holm oak wood behind a stone house at dusk. Dry ground and needle "
   "litter, a large domed ant mound, one open lit window in the wall behind.",
 "the-shoal-that-writes-the-tide":
   "The end of a granite harbour wall at low water. A vast expanse of mud, "
   "boats standing on their legs, a channel running out over a sand bar.",
 "the-dragonfly-in-two-summers":
   "A small farm pond in July. Reeds along one side, a fallen willow still "
   "growing lying down, four rotten posts where a jetty was.",
 "the-marten-who-trades":
   "The north wall of a small alpine church at dusk. Rough stone, a buttress, "
   "a narrow ledge at head height with small objects set out on it.",

 "the-reindeer-with-the-first-snow":
   "A Scottish mountain plateau in November. Granite, heather, old snow in "
   "the hollows, a corrie wall behind, a wide bare slope going down.",
 "the-wolf-on-the-boundary":
   "A wooded ridge between two valleys in snow. An overgrown stone-edged "
   "mule track, hornbeam, the roofs of a village visible far below.",
 "the-cormorants-count":
   "A small Cornish harbour at dusk. A stone inner wall, a black oak post "
   "standing proud of it, crab boats, houses stacked up the hill behind.",
 "the-weathercock-that-turns-early":
   "A Dutch town in flat country under a huge sky. A brick church tower, a "
   "copper weathervane cockerel on its spindle, low roofs, a dyke beyond.",
 "the-firefly-bridge":
   "A steep wooded gorge in Japan at night. Concrete bridge anchors on the "
   "near rim, cut cable stubs, a loud river far below, dense cedar.",
 "the-bat-who-draws-the-dark":
   "The inside of a house attic at night, unlit. Bare rafters and the "
   "underside of tiles, a water tank, stacked boxes, one small dark shape "
   "crossing the space.",
 "the-donkey-carrying-sleep":
   "A steep village road climbing a hillside at night. Whitewashed houses "
   "on both sides, one street lamp low down, four dark houses at the top.",
 "the-musk-ox-where-wind-starts":
   "A saddle between two low arctic hills. Bare frozen ground, no vegetation "
   "above ankle height, an enormous flat sky, snow driving from one side only.",

 "the-snow-leopard-nobody-photographed":
   "A Himalayan scree slope in February. Grey rock and thin snow, a rock "
   "spur, a frozen river far below, enormous brown mountains behind.",
}


def main():
    files = sorted(STORIES.glob("*.md"))
    missing = []
    written = 0

    for path in files:
        raw = path.read_text(encoding="utf-8")
        head, front, body = raw.split("---", 2)
        sid = re.search(r"^id:\s*(.+)$", front, re.M).group(1).strip()

        if sid not in SETTINGS:
            missing.append(sid)
            continue

        line = f"setting: {' '.join(SETTINGS[sid].split())}"
        if re.search(r"^setting:", front, re.M):
            front = re.sub(r"^setting:.*$", line, front, flags=re.M)
        else:
            # depois de summary, junto dos outros campos de conteudo
            front = re.sub(r"^(summary:.*)$", r"\1\n" + line, front, flags=re.M)

        path.write_text(f"{head}---{front}---{body}", encoding="utf-8")
        written += 1

    print(f"{written} contos com setting")
    if missing:
        print(f"  ! sem entrada em SETTINGS: {missing}")
    extra = set(SETTINGS) - {
        re.search(r"^id:\s*(.+)$", p.read_text(encoding='utf-8').split('---')[1], re.M).group(1).strip()
        for p in files}
    if extra:
        print(f"  ! entradas sem conto: {sorted(extra)}")


if __name__ == "__main__":
    main()
