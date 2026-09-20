# scripts

## Chapter translation

Chapter bodies are localised through `Magic World/Localizable.xcstrings`,
where the **key is the full English text of the chapter**. Nothing retypes
that English: `translate_chapters.py` reads each key straight out of
`Magic World/Content/Stories/<id>.json`, so a stray character cannot
silently break the lookup.

```bash
python3 scripts/translate_chapters.py      # merge translations into the catalog
python3 scripts/translation_status.py      # coverage + the next sessions
python3 scripts/translation_status.py --markdown > TRANSLATION.md
```

To add a language to a story, append to the `TRANSLATIONS` dict:

```python
TRANSLATIONS["the-glass-heron"]["fr"] = {0: "...", 1: "...", 2: "...", 3: "..."}
```

Partial coverage is fine. Anything absent falls back to English at runtime,
which is what `ContentLanguage` in `Model/Story.swift` already expects.

## Working in parallel

Several translation sessions usually run at once, each in its own git
worktree, and all of them touch the same three files: this script, the
catalog, and `TRANSLATION.md`. The first to push wins; everyone else
rebases.

That rebase is mechanical, because the merge script is **idempotent and
order-independent** — it merges into whatever catalog it finds rather than
generating one from scratch. So:

```bash
git pull --rebase origin main
```

- **Conflict in `Localizable.xcstrings`** — take the incoming version
  wholesale (`git checkout --ours "Magic World/Localizable.xcstrings"`
  during a rebase, which is main's side). Your own translations are not
  lost: they live in `translate_chapters.py`, not in the catalog.
- **Conflict in `translate_chapters.py`** — keep **both** blocks. Two
  sessions appending different `TRANSLATIONS[...]` entries is not a real
  conflict, just adjacent text.
- **Conflict in `TRANSLATION.md`** — ignore it, the file is generated.

Then re-derive both generated files and finish:

```bash
python3 scripts/translate_chapters.py
python3 scripts/translation_status.py --markdown > TRANSLATION.md
git add "Magic World/Localizable.xcstrings" scripts/translate_chapters.py TRANSLATION.md
git rebase --continue
```

Two things keep this tolerable, and both are load-bearing:

- The catalog is written with `sort_keys=True`. Unsorted, Python's
  insertion order makes every rewrite a different permutation of 500+
  keys and the conflict is the whole file. Sorted, the diff is only what
  actually changed. Xcode writes the catalog sorted anyway.
- Paths resolve from `__file__`, not from an absolute path. A hardcoded
  `/Users/<you>/Magic_World/...` sends every worktree session writing
  into the main checkout while committing its own untouched copy — the
  translations appear to vanish.

## Voice

These are bedtime stories for nine-to-eleven-year-olds in a quiet British
register: long sentences, dry understatement, no exclamation marks, no
whimsy. The existing `pt-BR` and `es` blocks are the reference. Match the
restraint rather than brightening it — a mechanical translation of a
bedtime story is worse than leaving it in English, because the English at
least has a voice.

Proper nouns stay (Wren, Ines, Bruno, Rua da Cordoaria, the Hendersons).
*The Cat Who Walks You Home* is set in Portugal, so `boa noite` stays in
Portuguese in every language — the English had already borrowed it.
