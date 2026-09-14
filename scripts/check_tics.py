#!/usr/bin/env python3
"""
check_tics.py — procura palavra repetida demais no acervo.

Frequencia bruta nao serve pra isso e a primeira versao deste script
gritou por causa de "four", que aparece 152 vezes e esta perfeitamente
bem: sao 131 contextos diferentes, nenhum com mais de quatro usos. E so
um numero comum sendo usado normalmente.

Tique e outra coisa. Tique e quando o uso se CONCENTRA: "eleven creels",
"eleven evenings", "eleven men" — a mesma palavra colada nos mesmos
poucos substantivos, conto após conto. Entao o que importa e a proporcao
do uso que cabe nos tres contextos mais frequentes.

    python3 scripts/check_tics.py
    python3 scripts/check_tics.py --top 30    # varre o vocabulario todo
"""

import argparse
import collections
import pathlib
import re

STORIES = pathlib.Path(__file__).resolve().parent / "stories"

WATCH = ["eleven", "nine", "twelve", "four", "seven", "thirteen", "twenty",
         "extremely", "entirely", "perfectly", "considerable", "eventually",
         "properly", "exactly", "somebody", "anybody"]

STOP = set("the a an and or but of to in on at for with is was were be been "
           "that this it he she they i you we not had has have do did no so "
           "as if by from her his their its there here what which who when "
           "then than out up down about into over her him them my your our".split())


def scan(word, texts):
    pat = re.compile(rf"\b{word}\b", re.I)
    uses = 0
    spread = 0
    ctx = collections.Counter()
    for t in texts.values():
        found = pat.findall(t)
        uses += len(found)
        if found:
            spread += 1
        for m in pat.finditer(t):
            nxt = t[m.end():m.end() + 20].split()
            ctx[nxt[0].strip(".,;:—\u2019\"") if nxt else "_"] += 1
    top3 = sum(n for _, n in ctx.most_common(3))
    conc = top3 / uses if uses else 0
    return uses, spread, conc, ctx


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=0,
                    help="tambem varre as N palavras mais usadas do acervo")
    args = ap.parse_args()

    files = sorted(STORIES.glob("*.md"))
    texts = {p.stem: p.read_text(encoding="utf-8").lower() for p in files}
    n = len(files)
    if not n:
        return

    words = list(WATCH)
    if args.top:
        freq = collections.Counter()
        for t in texts.values():
            freq.update(w for w in re.findall(r"[a-z']+", t)
                        if w not in STOP and len(w) > 3)
        words += [w for w, _ in freq.most_common(args.top) if w not in words]

    print(f"{n} contos\n")
    print(f"{'palavra':14} {'usos':>5} {'contos':>7} {'concentr.':>10}")
    print("-" * 50)
    for w in words:
        uses, spread, conc, ctx = scan(w, texts)
        if uses < 8:
            continue
        # Tique: espalhado pelo acervo E concentrado em poucos contextos.
        tic = spread > 0.7 * n and conc > 0.35 and uses / n > 2.5
        mark = "  <- tique" if tic else ""
        print(f"{w:14} {uses:>5} {spread:>4}/{n:<3} {conc:>8.0%}{mark}")
        if tic:
            for c, k in ctx.most_common(3):
                print(f"{'':16} {k:>3}x  {w} {c}")


if __name__ == "__main__":
    main()
