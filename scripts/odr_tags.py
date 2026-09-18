#!/usr/bin/env python3
"""
odr_tags.py — tira a narracao e as capas em movimento do bundle e as
distribui em tags de On-Demand Resources.

Uso:
    python3 scripts/odr_tags.py            # grava o pbxproj e o packs.json
    python3 scripts/odr_tags.py --check    # so confere; sai com 1 se divergir

RODE SEMPRE QUE ENTRAR MP3 OU MP4 NOVO. O projeto usa grupo sincronizado:
arquivo novo em Content/ entra no alvo sozinho, e entra SEM tag — ou seja,
dentro do .app. Foi assim que o app chegou a 429 MB. Em Debug o app avisa
na abertura quando acha midia sem tag (ver StoryPacks.swift).

Tags:
    narration-<id>   os MP3 de todos os capitulos do conto
    motion-<id>      o loop MP4 da capa

Os contos com `isFree: true` viram tags de instalacao inicial: baixam junto
com o app, e quem nunca assinou tem narracao sem precisar de rede.

O que este script escreve:
    Magic World.xcodeproj/project.pbxproj
        - assetTagsByRelativePath na excecao do grupo sincronizado
        - KnownAssetTags no projeto
        - ON_DEMAND_RESOURCES_INITIAL_INSTALL_TAGS no alvo (Debug e Release)
    Magic World/Content/packs.json
        - tag -> bytes. O app le isto pra saber quais pacotes existem sem
          ter de baixar nada pra descobrir.

O pbxproj e editado como texto, so nas chaves acima; o resto do arquivo
fica byte a byte como estava. Depois de gravar, o arquivo e relido pelo
plutil e as tags sao conferidas contra o esperado.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "Magic World"
CONTENT = APP_DIR / "Content"
STORIES = CONTENT / "Stories"
NARRATION = CONTENT / "Narration"
MOTION = CONTENT / "Motion"
PACKS_JSON = CONTENT / "packs.json"
PBXPROJ = ROOT / "Magic World.xcodeproj" / "project.pbxproj"

# ID fixo pro conjunto de excecoes que este script cria quando ainda nao
# existe nenhum. Se o Xcode ja tiver criado um pro alvo, e esse que e usado.
NEW_EXCEPTION_SET_ID = "83503E94304EE39000FD47AC"

# Limites da Apple por tag e para o que baixa junto com o app.
MAX_TAG_BYTES = 512 * 1024 * 1024
MAX_INITIAL_BYTES = 2 * 1024 * 1024 * 1024


def fail(msg):
    print(f"erro: {msg}", file=sys.stderr)
    sys.exit(1)


# MARK: - Conteudo

def load_stories():
    ids = json.loads((STORIES / "stories.json").read_text())["stories"]
    stories = []
    for sid in ids:
        story = json.loads((STORIES / f"{sid}.json").read_text())
        if story["id"] != sid:
            fail(f"{sid}.json tem id interno {story['id']!r}")
        stories.append(story)
    return stories


def plan(stories):
    """Devolve (tags por caminho relativo, bytes por tag, tags iniciais)."""
    audio_owner = {}
    for story in stories:
        for chapter in story["chapters"]:
            name = chapter.get("audioFile")
            if name:
                audio_owner[name] = story["id"]

    story_ids = {s["id"] for s in stories}
    tags_by_path = {}
    sizes = {}
    problems = []

    def add(path, tag):
        rel = path.relative_to(APP_DIR).as_posix()
        tags_by_path[rel] = tag
        sizes[tag] = sizes.get(tag, 0) + path.stat().st_size

    for mp3 in sorted(NARRATION.glob("*.mp3")):
        owner = audio_owner.get(mp3.stem)
        if owner is None:
            problems.append(f"{mp3.name}: nenhum capitulo aponta pra ele (audioFile)")
            continue
        add(mp3, f"narration-{owner}")

    for mp4 in sorted(MOTION.glob("*.mp4")):
        if mp4.stem not in story_ids:
            problems.append(f"{mp4.name}: nao ha conto com esse id")
            continue
        add(mp4, f"motion-{mp4.stem}")

    # Qualquer outra midia pesada em Content/ iria parar no .app sem tag.
    for path in sorted(CONTENT.rglob("*")):
        if path.suffix.lower() in {".mp3", ".mp4", ".m4a", ".mov", ".wav", ".aac"}:
            if path.relative_to(APP_DIR).as_posix() not in tags_by_path \
                    and path.parent not in (NARRATION, MOTION):
                problems.append(f"{path.relative_to(ROOT)}: midia fora de Narration/ e Motion/")

    if problems:
        fail("midia que nao da pra taguear:\n  " + "\n  ".join(problems))

    for name, owner in sorted(audio_owner.items()):
        if not (NARRATION / f"{name}.mp3").exists():
            print(f"aviso: {name}.mp3 nao existe — o capitulo fica sem narracao")

    for tag, size in sizes.items():
        if size > MAX_TAG_BYTES:
            fail(f"{tag} tem {size / 1e6:.0f} MB; o limite da Apple por tag e 512 MB")

    initial = []
    for story in stories:
        if story["isFree"]:
            for kind in ("narration", "motion"):
                tag = f"{kind}-{story['id']}"
                if tag in sizes:
                    initial.append(tag)
    if sum(sizes[t] for t in initial) > MAX_INITIAL_BYTES:
        fail("as tags de instalacao inicial passam de 2 GB")

    return tags_by_path, sizes, initial


def packs_json(sizes):
    return json.dumps({"packs": dict(sorted(sizes.items()))}, indent=2) + "\n"


# MARK: - pbxproj

def read_pbxproj_structure():
    out = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(PBXPROJ)],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)


def quote(s):
    return s if re.fullmatch(r"[A-Za-z0-9_$./]+", s) else '"' + s.replace('"', '\\"') + '"'


def locate(proj):
    """IDs do projeto, do alvo, das configuracoes do alvo e do grupo raiz."""
    objects = proj["objects"]
    project_id = proj["rootObject"]
    root_group_id = next(
        (oid for oid, o in objects.items()
         if o.get("isa") == "PBXFileSystemSynchronizedRootGroup" and o.get("path") == "Magic World"),
        None,
    )
    if root_group_id is None:
        fail("grupo sincronizado 'Magic World' nao encontrado no pbxproj")

    target_id = next(
        (tid for tid in objects[project_id]["targets"]
         if root_group_id in objects[tid].get("fileSystemSynchronizedGroups", [])),
        None,
    )
    if target_id is None:
        fail("nenhum alvo usa o grupo sincronizado 'Magic World'")

    config_list = objects[objects[target_id]["buildConfigurationList"]]
    config_ids = config_list["buildConfigurations"]

    exception_id = next(
        (eid for eid in objects[root_group_id].get("exceptions", [])
         if objects[eid].get("isa") == "PBXFileSystemSynchronizedBuildFileExceptionSet"
         and objects[eid].get("target") == target_id),
        None,
    )
    return project_id, target_id, config_ids, root_group_id, exception_id


def object_span(text, oid):
    """(inicio, fim) do objeto `oid` no texto, incluindo a linha de fechamento."""
    m = re.search(rf"^\t\t{oid} (/\*.*?\*/ )?= \{{\n", text, re.M)
    if not m:
        fail(f"objeto {oid} nao encontrado no texto do pbxproj")
    end = text.index("\n\t\t};\n", m.end()) + len("\n\t\t};\n")
    return m.start(), end


def block_span(text, start, end, indent, key):
    """(inicio, fim) de `key = { ... };` com a indentacao dada, dentro de [start, end)."""
    m = re.compile(rf"^{indent}{re.escape(key)} = \{{\n", re.M).search(text, start, end)
    if not m:
        fail(f"bloco {key} nao encontrado")
    close = text.index(f"\n{indent}}};\n", m.end()) + len(f"\n{indent}}};\n")
    return m.end(), close - len(f"{indent}}};\n")


def upsert(text, start, end, indent, key, rendered):
    """Troca ou insere `key` no dicionario entre [start, end), cujas chaves
    estao em `indent`. `rendered` e o texto completo da entrada, com \\n no fim.
    Insere em ordem alfabetica, que e como o Xcode grava; `isa` fica sempre
    em primeiro."""
    body = text[start:end]
    entry = re.compile(
        rf"^{indent}{re.escape(key)} = (?:\(\n.*?^{indent}\);|\{{\n.*?^{indent}\}};|[^\n]*;)\n",
        re.M | re.S,
    )
    m = entry.search(body)
    if m:
        body = body[:m.start()] + rendered + body[m.end():]
    else:
        keys = [(k.start(), k.group(1)) for k in re.finditer(rf"^{indent}(\w+) = ", body, re.M)]
        pos = len(body)
        for offset, name in keys:
            if name != "isa" and name > key:
                pos = offset
                break
        body = body[:pos] + rendered + body[pos:]
    return text[:start] + body + text[end:]


def render_list(indent, key, values):
    inner = "".join(f"{indent}\t{quote(v)},\n" for v in values)
    return f"{indent}{key} = (\n{inner}{indent});\n"


def render_asset_tags(tags_by_path):
    indent = "\t\t\t"
    lines = [f"{indent}assetTagsByRelativePath = {{\n"]
    for rel in sorted(tags_by_path):
        lines.append(f"{indent}\t{quote(rel)} = (\n{indent}\t\t{quote(tags_by_path[rel])},\n{indent}\t);\n")
    lines.append(f"{indent}}};\n")
    return "".join(lines)


def updated_pbxproj(text, tags_by_path, initial):
    proj = read_pbxproj_structure()
    project_id, target_id, config_ids, root_group_id, exception_id = locate(proj)

    # 1. Tags por arquivo, na excecao do grupo sincronizado.
    if exception_id is None:
        exception_id = NEW_EXCEPTION_SET_ID
        if exception_id in text:
            fail(f"ID {exception_id} ja existe no pbxproj; escolha outro em NEW_EXCEPTION_SET_ID")
        comment = '/* Exceptions for "Magic World" folder in "Magic World" target */'
        obj = (
            f"\t\t{exception_id} {comment} = {{\n"
            f"\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n"
            f"\t\t\ttarget = {target_id} /* Magic World */;\n"
            f"\t\t}};\n"
        )
        section = "/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */\n"
        if section in text:
            text = text.replace(section, section + obj, 1)
        else:
            anchor = "/* Begin PBXFileSystemSynchronizedRootGroup section */\n"
            text = text.replace(
                anchor,
                section + obj + "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */\n\n" + anchor,
                1,
            )
        start, end = object_span(text, root_group_id)
        text = upsert(text, start, end, "\t\t\t", "exceptions",
                      f"\t\t\texceptions = (\n\t\t\t\t{exception_id} {comment},\n\t\t\t);\n")

    start, end = object_span(text, exception_id)
    text = upsert(text, start, end, "\t\t\t", "assetTagsByRelativePath",
                  render_asset_tags(tags_by_path))

    # 2. Tags conhecidas do projeto: e a lista que aparece em Resource Tags.
    start, end = object_span(text, project_id)
    a_start, a_end = block_span(text, start, end, "\t\t\t", "attributes")
    text = upsert(text, a_start, a_end, "\t\t\t\t", "KnownAssetTags",
                  render_list("\t\t\t\t", "KnownAssetTags", sorted(set(tags_by_path.values()))))

    # 3. O que baixa junto com o app.
    for cid in config_ids:
        start, end = object_span(text, cid)
        b_start, b_end = block_span(text, start, end, "\t\t\t", "buildSettings")
        text = upsert(text, b_start, b_end, "\t\t\t\t", "ON_DEMAND_RESOURCES_INITIAL_INSTALL_TAGS",
                      f"\t\t\t\tON_DEMAND_RESOURCES_INITIAL_INSTALL_TAGS = {quote(' '.join(initial))};\n")

    return text


def verify(tags_by_path, initial):
    """Rele o pbxproj pelo plutil e confere que diz o que devia dizer."""
    proj = read_pbxproj_structure()
    objects = proj["objects"]
    project_id, target_id, config_ids, root_group_id, exception_id = locate(proj)
    errors = []

    written = {}
    if exception_id:
        for rel, tags in objects[exception_id].get("assetTagsByRelativePath", {}).items():
            written[rel] = tags
    expected = {rel: [tag] for rel, tag in tags_by_path.items()}
    if written != expected:
        missing = sorted(set(expected) - set(written))
        extra = sorted(set(written) - set(expected))
        wrong = sorted(r for r in set(expected) & set(written) if expected[r] != written[r])
        for label, items in (("sem tag", missing), ("tag de arquivo que nao existe", extra),
                             ("tag errada", wrong)):
            if items:
                errors.append(f"{label}: {len(items)} (ex.: {items[0]})")

    known = objects[project_id].get("attributes", {}).get("KnownAssetTags", [])
    if sorted(known) != sorted(set(tags_by_path.values())):
        errors.append("KnownAssetTags desatualizado")

    for cid in config_ids:
        settings = objects[cid]["buildSettings"]
        value = settings.get("ON_DEMAND_RESOURCES_INITIAL_INSTALL_TAGS", "")
        if isinstance(value, list):
            value = " ".join(value)
        if value.split() != initial:
            errors.append(f"ON_DEMAND_RESOURCES_INITIAL_INSTALL_TAGS desatualizado em {objects[cid]['name']}")
        if settings.get("ENABLE_ON_DEMAND_RESOURCES") == "NO":
            errors.append(f"ENABLE_ON_DEMAND_RESOURCES = NO em {objects[cid]['name']}")

    return errors


# MARK: - Main

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="so confere, nao grava")
    args = parser.parse_args()

    stories = load_stories()
    tags_by_path, sizes, initial = plan(stories)
    expected_packs = packs_json(sizes)

    if args.check:
        errors = verify(tags_by_path, initial)
        if not PACKS_JSON.exists() or PACKS_JSON.read_text() != expected_packs:
            errors.append("Content/packs.json desatualizado")
        if errors:
            fail("On-Demand Resources fora de sincronia — rode scripts/odr_tags.py\n  "
                 + "\n  ".join(errors))
        print(f"ok: {len(tags_by_path)} arquivos em {len(sizes)} tags")
        return

    original = PBXPROJ.read_text()
    updated = updated_pbxproj(original, tags_by_path, initial)
    if updated != original:
        backup = PBXPROJ.with_suffix(".pbxproj.bak")
        backup.write_text(original)
        PBXPROJ.write_text(updated)
        try:
            errors = verify(tags_by_path, initial)
        except subprocess.CalledProcessError:
            errors = ["plutil nao conseguiu ler o pbxproj gerado"]
        if errors:
            PBXPROJ.write_text(original)
            fail("pbxproj gerado nao confere, original restaurado:\n  " + "\n  ".join(errors))
        backup.unlink()

    PACKS_JSON.write_text(expected_packs)

    total = sum(sizes.values())
    initial_bytes = sum(sizes[t] for t in initial)
    print(f"{len(tags_by_path)} arquivos em {len(sizes)} tags, {total / 1e6:.0f} MB fora do bundle")
    print(f"instalacao inicial: {len(initial)} tags, {initial_bytes / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
