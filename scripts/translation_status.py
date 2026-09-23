#!/usr/bin/env python3
"""Report chapter-translation coverage and lay out the remaining sessions.

Reads the real state — Content/Stories/*.json for the source, and
Localizable.xcstrings for what has actually been translated — so the plan
can never drift from the repository the way a hand-kept checklist does.

    python3 scripts/translation_status.py            # progress + next sessions
    python3 scripts/translation_status.py --all      # every remaining session
    python3 scripts/translation_status.py --lang pt-BR
    python3 scripts/translation_status.py --markdown # emit a checklist

A SESSION is three stories in one language. That size comes from measuring
the work: one story averages ~2,160 words, two were comfortable in a single
sitting, and past four the prose starts going mechanical — which is the
failure mode that matters here, since a flat translation of a bedtime story
is worse than no translation.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
STORIES = REPO / "Magic World" / "Content" / "Stories"
FREE_WEEKS = REPO / "Magic World" / "Content" / "free-weeks.json"
NOT_SCHEDULED = 10_000
CATALOG = REPO / "Magic World" / "Localizable.xcstrings"

# Source language is excluded: its "translation" is the key itself.
LANGUAGES = ["pt-BR", "es", "fr", "de", "it", "ar"]
STORIES_PER_SESSION = 3


def first_free_week() -> dict[str, int]:
    """story id → the first week of the free rotation it opens in.

    Written by free_weeks.py. A story missing from it sorts last."""
    weeks = json.loads(FREE_WEEKS.read_text())["weeks"]
    first: dict[str, int] = {}
    for n, week in enumerate(weeks):
        for sid in week:
            first.setdefault(sid, n)
    return first


def load_stories() -> list[dict]:
    ids = json.loads((STORIES / "stories.json").read_text())["stories"]
    week = first_free_week()
    out = []
    for sid in ids:
        data = json.loads((STORIES / f"{sid}.json").read_text())
        out.append({
            "id": sid,
            "title": data["title"],
            # Missing from the rotation (free_weeks.py not rerun): last.
            "week": week.get(sid, NOT_SCHEDULED),
            "chapters": [c["text"] for c in data["chapters"]],
            "words": sum(len(c["text"].split()) for c in data["chapters"]),
        })
    return out


def coverage(stories: list[dict]) -> dict[str, dict[str, int]]:
    """story id → language → how many of its chapters are translated."""
    catalog = json.loads(CATALOG.read_text())["strings"]
    result: dict[str, dict[str, int]] = {}
    for story in stories:
        per_lang = {lang: 0 for lang in LANGUAGES}
        for body in story["chapters"]:
            entry = catalog.get(body)
            if not entry:
                continue
            for lang in LANGUAGES:
                unit = entry.get("localizations", {}).get(lang, {})
                value = unit.get("stringUnit", {}).get("value")
                # A value identical to the key is the English fallback
                # sitting in a language slot, not a translation.
                if value and value != body:
                    per_lang[lang] += 1
        result[story["id"]] = per_lang
    return result


def build_sessions(stories: list[dict], cov: dict) -> list[dict]:
    """Remaining work, language by language — pt-BR first (it is the market
    the paywall prices in Reais for) — and within each language by the week
    each story first turns free (free-weeks.json), so what an unpaid reader
    opens next is translated first IN THAT LANGUAGE.

    Language-major, not week-major, on purpose: it keeps the session
    numbers the parallel translation sessions already work from. The cost
    is that next week's free stories get a human translation in pt-BR long
    before the other five languages, which show machine translation meanwhile.

    free_weeks.py lays the rotation out in these same batches of three, in
    stories.json order after week 0, so a session is normally one week."""
    ordered_langs = LANGUAGES  # pt-BR is already first
    # sorted() is stable: stories that open in the same week keep their
    # stories.json order.
    by_week = sorted(stories, key=lambda s: s["week"])

    sessions: list[dict] = []
    for lang in ordered_langs:
        pending = [
            s for s in by_week
            if cov[s["id"]][lang] < len(s["chapters"])
        ]
        for i in range(0, len(pending), STORIES_PER_SESSION):
            batch = pending[i:i + STORIES_PER_SESSION]
            sessions.append({
                "week": batch[0]["week"],
                "lang": lang,
                "stories": batch,
                "words": sum(s["words"] for s in batch),
            })
    return sessions


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="every session, not just the next ten")
    ap.add_argument("--lang", help="restrict to one language")
    ap.add_argument("--markdown", action="store_true", help="emit a checklist")
    args = ap.parse_args()

    stories = load_stories()
    cov = coverage(stories)
    sessions = build_sessions(stories, cov)
    if args.lang:
        sessions = [s for s in sessions if s["lang"] == args.lang]

    total_chapters = sum(len(s["chapters"]) for s in stories) * len(LANGUAGES)
    done_chapters = sum(sum(c.values()) for c in cov.values())
    total_words = sum(s["words"] for s in stories) * len(LANGUAGES)
    remaining_words = sum(s["words"] for s in sessions)

    if args.markdown:
        print("# Chapter translation sessions\n")
        print(f"Generated by `scripts/translation_status.py`. "
              f"{done_chapters}/{total_chapters} chapters done.\n")
        for n, s in enumerate(sessions, 1):
            titles = ", ".join(x["title"] for x in s["stories"])
            print(f"- [ ] **S{n:02d}** `{s['lang']}` ({s['words']:,}w) — {titles}")
        return

    print(f"CHAPTER TRANSLATION")
    print(f"  {done_chapters:,} / {total_chapters:,} chapters "
          f"({done_chapters / total_chapters * 100:.1f}%)")
    print(f"  {total_words - remaining_words:,} / {total_words:,} words")
    print()

    print("PER LANGUAGE")
    for lang in LANGUAGES:
        done = sum(c[lang] for c in cov.values())
        total = sum(len(s["chapters"]) for s in stories)
        bar = "█" * int(done / total * 24) + "·" * (24 - int(done / total * 24))
        print(f"  {lang:6s} {bar} {done:3d}/{total}")
    print()

    show = sessions if args.all else sessions[:10]
    print(f"NEXT SESSIONS  ({len(sessions)} remaining, "
          f"{STORIES_PER_SESSION} stories each)")
    for n, s in enumerate(show, 1):
        tag = f"wk{s['week']:02d}"
        print(f"  S{n:02d}  {s['lang']:6s} {tag}  {s['words']:>6,}w")
        for story in s["stories"]:
            print(f"        {story['id']}")
    if not args.all and len(sessions) > len(show):
        print(f"  … and {len(sessions) - len(show)} more (--all to list)")


if __name__ == "__main__":
    main()
