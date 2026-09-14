#!/usr/bin/env python3
"""
detic.py — troca o "eleven" repetido por numeros variados.

O problema: 139 ocorrencias de "eleven" em 21 dos 22 contos. Num acervo
lido em sequencia isso vira tique.

O que NAO pode ser trocado:
  - idade ("she was eleven", "an eleven year old") — o leitor-alvo tem
    9 a 11 anos e a idade dos protagonistas e deliberada;
  - hora ("eleven o'clock");
  - numero de casa ("number eleven");
  - qualquer coisa dentro de um ano (1911).

O que precisa de cuidado: uma quantidade que se repete DENTRO do mesmo
conto tem de virar sempre o mesmo numero. "eleven creels" aparece tres
vezes em the-seal-who-waits; se cada uma virar um numero diferente, a
historia deixa de fechar.

Solucao: a substituicao e indexada por (arquivo, substantivo seguinte).
Todas as "eleven creels" daquele arquivo recebem o mesmo numero, e
arquivos diferentes recebem numeros diferentes.

    python3 scripts/detic.py --dry-run
    python3 scripts/detic.py
"""

import argparse
import hashlib
import pathlib
import re

STORIES = pathlib.Path(__file__).resolve().parent / "stories"

ALTERNATIVES = ["nine", "twelve", "six", "fourteen", "seventeen",
                "seven", "a dozen", "twenty", "thirteen", "five"]

# Contextos onde "eleven" fica, casados contra os 30 caracteres seguintes.
# Lista explicita em vez de regex esperta: idade e hora sao os dois casos
# em que trocar o numero muda o sentido, e nao vale arriscar.
KEEP_AFTER = [
    "years old", "year old", "-year-old", "o'clock",
    " and she was extremely", " and has never quite",
    " when they flooded", ", and had left the hou",
    " and daft", " and had spent forty", " with her hands going",
    " became a thing", " and have got hold",
    " and had recently beco", " can take a thing",
    " and she had read book", " and lived here",
    ", usually nearer one", " in the morning and at",
    " at night", ", which everyone", ", and there are people",
    ", and it took him", " when nobody is watching",
    ", which was permitted",
    " herself in 19", ", and it's about time",
]
KEEP_BEFORE = ["number "]

# Substantivo que vem depois do numero. E ele que indexa a substituicao,
# pra que toda "eleven creels" do mesmo arquivo vire o mesmo numero.
NOUN = re.compile(r"^\s*([a-z-]+)")


def should_keep(before, after):
    if any(before.lower().endswith(k) for k in KEEP_BEFORE):
        return True
    return any(after.lstrip().startswith(k.lstrip()) for k in KEEP_AFTER)


def replacement_for(path_name, noun):
    """Numero estavel por (arquivo, substantivo). Mesmo par, mesmo numero."""
    key = f"{path_name}:{noun}".encode()
    idx = int(hashlib.sha256(key).hexdigest(), 16) % len(ALTERNATIVES)
    return ALTERNATIVES[idx]


def process(path, dry_run):
    text = path.read_text(encoding="utf-8")

    # Duas passadas. A primeira decide os numeros do corpo, indexados pelo
    # substantivo. A segunda aplica, e um "Eleven" solto num titulo de
    # capitulo herda o numero mais usado no corpo do arquivo — senao o
    # titulo diz um numero e o texto diz outro.
    body_choice = {}
    counts = {}
    for m in re.finditer(r"\bEleven\b|\beleven\b", text):
        before = text[max(0, m.start() - 24):m.start()]
        after = text[m.end():m.end() + 34]
        if should_keep(before, after):
            continue
        noun_match = NOUN.match(after)
        if not noun_match:
            continue
        noun = noun_match.group(1)
        pick = replacement_for(path.name, noun)
        body_choice[noun] = pick
        counts[pick] = counts.get(pick, 0) + 1

    fallback = max(counts, key=counts.get) if counts else "nine"

    out, last, changes = [], 0, []
    for m in re.finditer(r"\bEleven\b|\beleven\b", text):
        before = text[max(0, m.start() - 24):m.start()]
        after = text[m.end():m.end() + 34]
        if should_keep(before, after):
            continue

        noun_match = NOUN.match(after)
        new = body_choice.get(noun_match.group(1)) if noun_match else None
        if new is None:
            new = fallback
        if m.group(0)[0].isupper():
            new = new[0].upper() + new[1:]

        out.append(text[last:m.start()])
        out.append(new)
        last = m.end()
        changes.append((m.group(0) + after[:22].split("\n")[0], new))

    if not changes:
        return 0

    out.append(text[last:])
    if not dry_run:
        path.write_text("".join(out), encoding="utf-8")

    print(f"\n{path.stem}  ({len(changes)})")
    for old_txt, new_txt in changes:
        print(f"    {old_txt[:44]:46} -> {new_txt}")
    return len(changes)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    total = sum(process(p, args.dry_run) for p in sorted(STORIES.glob("*.md")))
    print(f"\n{total} trocas" + (" (dry run)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
