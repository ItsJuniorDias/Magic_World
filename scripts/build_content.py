#!/usr/bin/env python3
"""
build_content.py — constroi o conteudo do bundle a partir dos markdowns.

Prosa mora em scripts/stories/*.md, num formato que da pra ler e revisar.
Este script gera, em Magic World/Content/Stories/:

    <id>.json                  a historia no schema do app
    <id>-<n>-timings.json      alinhamento sentenca <-> tempo
    stories.json               o manifesto

Os timings sao ESTIMADOS a 150 wpm. Servem pro read-along antes de existir
audio. O pipeline de narracao sobrescreve estes arquivos com os tempos
medidos do MP3 — e ai o "~" da duracao some sozinho no app.

Uso:
    python3 scripts/build_content.py
    python3 scripts/build_content.py --check      # so valida, nao escreve

Depois de gerar conto novo, ou quando entrar MP3/MP4 novo em Content/,
rode tambem scripts/odr_tags.py: sem ele a midia nova entra no .app sem
tag de On-Demand Resources e o app volta a pesar centenas de MB na loja.

Conto novo tambem precisa entrar no calendario dos gratis: rode
scripts/free_weeks.py. Sem isso ele nunca fica gratis, e o --check de la
acusa.

Formato do markdown:

    ---
    id: the-glass-heron
    title: The Glass Heron
    creature: A heron made of river glass
    realm: tides
    publishedAt: 2026-07-29
    summary: Uma linha que aparece no cartao.
    ---

    ## Titulo do capitulo

    Paragrafo.

    Outro paragrafo.

    ## Proximo capitulo
    ...
"""

import argparse
import json
import pathlib
import re
import sys

# 150 wpm e ritmo de audiolivro adulto. Narracao infantil com read-along,
# onde a crianca acompanha o texto, roda entre 130 e 140 — e a estimativa
# tem que refletir o audio que vai ser gerado, nao um ritmo que ninguem vai
# usar. Isso empurra varios contos de 14 pra 15 minutos, do que estou
# ciente: e correcao de um numero que estava errado desde o inicio, e o
# numero de verdade vem do MP3 quando o pipeline de narracao rodar.
WPM = 140.0
SENTENCE_GAP = 0.35
SPLIT = re.compile(r'(?<=[.!?])\s+')

REALMS = {"forest", "tides", "skies", "nightfall", "frost"}
# Sem `isFree`: o que abre de graca muda toda semana e mora no calendario
# (scripts/free_weeks.py), nao no conto.
REQUIRED = {"id", "title", "creature", "realm", "publishedAt", "summary"}

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Escrito pelo narrate.py quando a narracao existe. Quando ele esta aqui,
# os timings REAIS mandam e a estimativa de 140 wpm sai de cena.
NARRATION = ROOT / "scripts" / "narration-manifest.json"
STORY_DIR = ROOT / "scripts" / "stories"
OUT_DIR = ROOT / "Magic World" / "Content" / "Stories"


def parse_markdown(path):
    raw = path.read_text(encoding="utf-8")
    if not raw.startswith("---"):
        raise ValueError(f"{path.name}: falta o frontmatter")

    _, front, body = raw.split("---", 2)

    meta = {}
    for line in front.strip().splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip()

    missing = REQUIRED - meta.keys()
    if missing:
        raise ValueError(f"{path.name}: faltam campos {sorted(missing)}")
    if meta["realm"] not in REALMS:
        raise ValueError(f"{path.name}: realm '{meta['realm']}' nao existe")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", meta["publishedAt"]):
        raise ValueError(f"{path.name}: publishedAt precisa ser YYYY-MM-DD")

    chapters = []
    for block in re.split(r'^## ', body, flags=re.M)[1:]:
        lines = block.strip().split("\n", 1)
        title = lines[0].strip()
        text = lines[1].strip() if len(lines) > 1 else ""
        # Paragrafos viram um unico texto: a quebra visual e do leitor,
        # nao do conteudo. Sem isso a segmentacao em sentencas engasga.
        text = re.sub(r'\n\s*\n', ' ', text)
        text = re.sub(r'\s+', ' ', text).strip()
        if not text:
            raise ValueError(f"{path.name}: capitulo '{title}' esta vazio")
        chapters.append((title, text))

    if not chapters:
        raise ValueError(f"{path.name}: nenhum capitulo (use '## Titulo')")

    return meta, chapters


def timings_for(story_id, index, text):
    sentences = [s.strip() for s in SPLIT.split(text) if s.strip()]
    out, clock = [], 0.0
    for i, sentence in enumerate(sentences):
        duration = round(len(sentence.split()) / WPM * 60.0, 2)
        out.append({
            "index": i,
            "start": round(clock, 2),
            "end": round(clock + duration, 2),
            "text": sentence,
        })
        clock += duration + SENTENCE_GAP
    return {
        "storyId": story_id,
        "chapterIndex": index,
        "duration": round(clock, 2),
        "sentences": out,
    }


def load_narration():
    if not NARRATION.exists():
        return {}
    try:
        return json.loads(NARRATION.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"  ! narration-manifest.json ilegivel: {e}")
        return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="valida sem escrever")
    args = ap.parse_args()

    narration = load_narration()
    if narration:
        print(f"narracao encontrada: {len(narration)} capitulos com audio real\n")

    sources = sorted(STORY_DIR.glob("*.md"))
    if not sources:
        sys.exit(f"nenhum .md em {STORY_DIR}")

    built, ids, problems = [], set(), []

    for path in sources:
        try:
            meta, chapters = parse_markdown(path)
        except ValueError as e:
            problems.append(str(e))
            continue

        if meta["id"] in ids:
            problems.append(f"{path.name}: id duplicado '{meta['id']}'")
            continue
        ids.add(meta["id"])

        story = {
            "id": meta["id"],
            "title": meta["title"],
            "creature": meta["creature"],
            "summary": meta["summary"],
            "realm": meta["realm"],
            "publishedAt": meta["publishedAt"],
            "coverAsset": meta.get("coverAsset", ""),
            "chapters": [
                {
                    "index": i,
                    "title": title,
                    "text": text,
                    "audioFile": narration.get(f"{meta['id']}-{i}", {}).get("audioFile"),
                    "audioDuration": narration.get(f"{meta['id']}-{i}", {}).get("duration"),
                }
                for i, (title, text) in enumerate(chapters)
            ],
        }
        built.append((story, chapters))

    if problems:
        for p in problems:
            print("  !", p)
        sys.exit(1)

    if not args.check:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        for old in OUT_DIR.glob("*.json"):
            old.unlink()

    total_words = 0
    total_seconds = 0.0
    print(f"{'historia':30} {'habitat':10} {'cap':>4} {'palavras':>9} {'min':>6}")
    print("-" * 64)

    for story, chapters in sorted(built, key=lambda b: b[0]["publishedAt"]):
        words = sum(len(t.split()) for _, t in chapters)
        seconds = 0.0
        timings = []
        for i, (_, text) in enumerate(chapters):
            real = narration.get(f"{story['id']}-{i}")
            if real:
                # Medido no audio. A estimativa de 140 wpm nao encosta nisto.
                t = {"storyId": story["id"], "chapterIndex": i,
                     "duration": real["duration"], "sentences": real["sentences"]}
            else:
                t = timings_for(story["id"], i, text)
            timings.append(t)
            seconds += t["duration"]

        total_words += words
        total_seconds += seconds

        print(f"{story['id']:30} {story['realm']:10} {len(chapters):>4} "
              f"{words:>9,} {seconds/60:>5.0f}")

        # Meta e 15-20 min. Avisa em 14 pra pegar o que so raspa por baixo.
        if seconds / 60 < 14:
            print(f"    aviso: abaixo da meta de 15-20 min")

        if not args.check:
            (OUT_DIR / f"{story['id']}.json").write_text(
                json.dumps(story, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            for t in timings:
                # Um ponto so no nome. Nome com duas extensoes vira recurso
                # solto na raiz do .app que o codesign trata como componente
                # aninhado, e a assinatura falha com "code object is not
                # signed at all".
                (OUT_DIR / f"{story['id']}-{t['chapterIndex']}-timings.json").write_text(
                    json.dumps(t, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if not args.check:
        manifest = [s["id"] for s, _ in sorted(built, key=lambda b: b[0]["publishedAt"])]
        (OUT_DIR / "stories.json").write_text(
            json.dumps({"stories": manifest}, indent=2) + "\n", encoding="utf-8")

    print("-" * 64)
    print(f"{len(built)} historias, {total_words:,} palavras, "
          f"{total_seconds/60:.0f} min de narracao estimada")
    print(f"media por historia: {total_seconds/60/len(built):.0f} min")


if __name__ == "__main__":
    main()
