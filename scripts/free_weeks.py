#!/usr/bin/env python3
"""
free_weeks.py — o calendario das historias gratis da semana.

Uso:
    python3 scripts/free_weeks.py            # acrescenta conto novo ao calendario
    python3 scripts/free_weeks.py --check    # so confere; sai com 1 se divergir
    python3 scripts/free_weeks.py --reset    # refaz do zero — so antes de publicar

Nenhum conto e gratis pra sempre. Toda segunda-feira, a meia-noite no
fuso do aparelho, tres contos inteiros ficam abertos pra quem nao assina,
e os da semana anterior trancam de novo — mesmo pela metade. Quem decide
qual semana e agora e o app (ver Model/FreeWeek.swift), pela data do
aparelho: sem servidor, funciona em modo aviao.

A ORDEM segue a fila de traducao, e isso e de proposito. A semana 0 sao os
tres contos que eram gratis antes da rotacao, traduzidos a mao nos seis
idiomas. Depois vem o acervo na ordem de stories.json, de tres em tres —
exatamente os lotes das sessoes de translation_status.py. Traduzir "o que
vai ficar gratis primeiro" continua sendo so seguir a fila.

O ultimo lote sobra com menos de tres (47 = 15 x 3 + 2). Ele e completado
com o comeco da rotacao, entao o ciclo tem 17 semanas e todo conto aparece
ao menos uma vez. Depois da ultima semana o calendario volta pra primeira.

STARTS_ON e a segunda-feira da semana 0. Pra que a semana 0 coincida com o
lancamento, troque pela segunda-feira da semana em que a versao sai e rode
com --reset. Precisa ser segunda: o app conta semanas de segunda a segunda.

DEPOIS DE PUBLICADO, O CALENDARIO SO CRESCE

O app calcula a semana pela data, entao mexer numa semana ja publicada — ou
em startsOn — troca os gratis de todo mundo no instante em que a atualizacao
instala, no meio da semana, e nao na segunda. Por isso, sem --reset, o
arquivo gravado manda: startsOn e as semanas existentes ficam como estao, e
conto novo entra em semanas acrescentadas no fim.

Mesmo so acrescentando ha um efeito: o ciclo fica mais longo, e depois que a
primeira volta termina a conta `semana % total` muda. Uma versao que
acrescenta semanas depois disso tambem troca os gratis ao instalar. E raro
(so quando o acervo cresce) e aceito; o que este script impede e o caso
comum, de reordenar sem querer.
"""

import argparse
import datetime
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTENT = ROOT / "Magic World" / "Content"
STORIES = CONTENT / "Stories"
OUT = CONTENT / "free-weeks.json"

STARTS_ON = "2026-09-21"
PER_WEEK = 3

# Os tres que eram gratis antes da rotacao. Traduzidos a mao nos seis
# idiomas — sao a primeira impressao de quem instala na semana 0.
FIRST_WEEK = [
    "the-glass-heron",
    "where-the-moths-sleep",
    "the-cat-who-walks-you-home",
]


def fail(msg):
    print(f"free_weeks: {msg}", file=sys.stderr)
    sys.exit(1)


def catalog_order():
    return json.loads((STORIES / "stories.json").read_text())["stories"]


def batches(order, pad_from):
    """Lotes de PER_WEEK. O ultimo, se sobrar curto, e completado com o
    comeco de `pad_from`, sem repetir conto dentro da mesma semana."""
    weeks = [order[i:i + PER_WEEK] for i in range(0, len(order), PER_WEEK)]
    if weeks:
        last = weeks[-1]
        for sid in pad_from:
            if len(last) == PER_WEEK:
                break
            if sid not in last:
                last.append(sid)
    return weeks


def build(ids):
    missing = [sid for sid in FIRST_WEEK if sid not in ids]
    if missing:
        fail(f"FIRST_WEEK cita contos que nao existem: {missing}")

    order = FIRST_WEEK + [sid for sid in ids if sid not in FIRST_WEEK]
    return {"startsOn": STARTS_ON, "weeks": batches(order, order)}


def extend(saved, ids):
    """O calendario gravado, intocado, mais semanas no fim pros contos que
    ainda nao aparecem em nenhuma."""
    scheduled = {sid for week in saved["weeks"] for sid in week}
    new = [sid for sid in ids if sid not in scheduled]
    rotation = [sid for week in saved["weeks"] for sid in week]
    return {"startsOn": saved["startsOn"],
            "weeks": saved["weeks"] + batches(new, rotation)}


def validate(schedule, ids):
    problems = []
    start = datetime.date.fromisoformat(schedule["startsOn"])
    if start.weekday() != 0:
        problems.append(f"startsOn {start} nao e segunda-feira")

    known = set(ids)
    seen = set()
    for n, week in enumerate(schedule["weeks"]):
        if len(week) != PER_WEEK:
            problems.append(f"semana {n} tem {len(week)} contos, nao {PER_WEEK}")
        if len(set(week)) != len(week):
            problems.append(f"semana {n} repete conto: {week}")
        for sid in week:
            if sid not in known:
                problems.append(f"semana {n}: '{sid}' nao esta em stories.json")
        seen.update(week)

    never = [sid for sid in ids if sid not in seen]
    if never:
        problems.append(f"contos que nunca ficam gratis: {never}")
    return problems


def render(schedule):
    return json.dumps(schedule, indent=2, ensure_ascii=False) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="so confere o arquivo gravado; nao escreve nada")
    ap.add_argument("--reset", action="store_true",
                    help="ignora o arquivo gravado e refaz do zero (so antes de publicar)")
    args = ap.parse_args()

    ids = catalog_order()
    if OUT.exists() and not args.reset:
        schedule = extend(json.loads(OUT.read_text()), ids)
    else:
        schedule = build(ids)

    problems = validate(schedule, ids)
    if problems:
        fail("calendario invalido:\n  " + "\n  ".join(problems))

    text = render(schedule)
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            fail(f"{OUT.relative_to(ROOT)} desatualizado — rode sem --check")
        print(f"{OUT.relative_to(ROOT)} em dia: {len(schedule['weeks'])} semanas")
        return

    OUT.write_text(text)
    start = datetime.date.fromisoformat(schedule["startsOn"])
    print(f"{OUT.relative_to(ROOT)}: {len(schedule['weeks'])} semanas, ciclo de "
          f"{len(schedule['weeks']) * 7} dias")
    for n, week in enumerate(schedule["weeks"]):
        monday = start + datetime.timedelta(weeks=n)
        print(f"  {n:2d}  {monday}  {', '.join(week)}")


if __name__ == "__main__":
    main()
