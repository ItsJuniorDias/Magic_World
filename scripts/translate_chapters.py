#!/usr/bin/env python3
"""Merge chapter-body translations into Localizable.xcstrings.

The catalog key for a chapter body is the ENGLISH TEXT ITSELF, exactly as
it sits in Content/Stories/<id>.json. This script reads the key straight
out of that file rather than having it retyped, so a stray character can
never break the lookup.

Add a story by appending to TRANSLATIONS:  story id → {lang → {chapter
index → translated body}}.  Partial is fine — anything absent falls back
to English at runtime, which is what ContentLanguage already expects.

Usage:  python3 translate_chapters.py
"""
from __future__ import annotations

import json
from pathlib import Path

STORIES = Path("/Users/alexandre/Magic_World/Magic World/Content/Stories")
CATALOG = Path("/Users/alexandre/Magic_World/Magic World/Localizable.xcstrings")

# story id → { lang → { chapter index → translated text } }
TRANSLATIONS: dict[str, dict[str, dict[int, str]]] = {}

# ═══════════════════════════════════════════════════════════════════════
# The Glass Heron
# ═══════════════════════════════════════════════════════════════════════
TRANSLATIONS["the-glass-heron"] = {
    "pt-BR": {
        0: (
            "A água subiu numa terça-feira, o que Wren achou um dia sem graça para "
            "uma coisa tão grande acontecer. Ela tinha ido dormir com o rio onde o "
            "rio devia estar, lá embaixo depois das hortas, atrás dos salgueiros, "
            "fazendo o barulho que sempre fazia. Acordou com um barulho diferente. "
            "Era mais suave e muito mais perto, e vinha da escada. De manhã a viela "
            "era um rio e o rio não fazia ideia de que estava no lugar errado. "
            "Cuidava dos seus afazeres entre as casas exatamente como cuidava dos "
            "seus afazeres entre as margens, levando um painel de cerca, um "
            "engradado de plástico e uma bota de borracha verde, tudo na mesma "
            "velocidade sem pressa. A avó já tinha levado as cadeiras para cima. "
            "Tinha feito isso no escuro, sozinha, sem acordar ninguém, e estava "
            "tomando chá no patamar quando Wren apareceu de meias. — Não desça do "
            "quinto degrau para baixo — disse a avó. — O carpete está perdido e não "
            "quero você escorregando nele. Foi tudo. Sem pânico, sem explicação. Foi "
            "assim que Wren soube que já tinha acontecido antes. Da janela do "
            "patamar dava para ver o topo dos mourões, cada um com uma golinha de "
            "espuma. O galpão dos Henderson tinha se soltado e girado sozinho para "
            "ficar virado para o lado errado, o que lhe pareceu de algum modo mais "
            "grosseiro que a própria enchente. Mais além, onde devia estar a "
            "estrada, havia uma larga lâmina de água marrom seguindo quieta na "
            "direção dos campos. A cidade tinha virado um arquipélago da noite para "
            "o dia. Cada casa era uma ilha. As pessoas dentro delas ficavam nas "
            "janelas de cima e acenavam, e depois de um tempo pararam de acenar, "
            "porque só dá para acenar por certo tempo para alguém que você não "
            "alcança. Foi aí que ela viu o pássaro. Estava na cumeeira do telhado da "
            "casa em frente, com o pescoço dobrado para dentro dos ombros do jeito "
            "que as garças fazem quando decidiram esperar. Estava muito parada. No "
            "começo ela achou que fosse uma daquelas de plástico que as pessoas põem "
            "nos lagos para assustar os peixes. Então a luz se moveu, e atravessou. "
            "Era transparente de ponta a ponta, como uma garrafa erguida contra a "
            "janela. A manhã cinzenta entrava nela por cima e saía por baixo da cor "
            "do rio, um verde-marrom suave em movimento, como se alguma coisa "
            "estivesse sendo mexida lá dentro bem devagar. Wren não chamou ninguém. "
            "Teve a sensação forte, como às vezes se tem diante de um bicho selvagem "
            "que chegou perto, de que uma criatura daquelas devia poder chegar sem "
            "alarde. Se gritasse, a avó viria, e então a avó explicaria, e então "
            "seria uma coisa que tinha sido explicada. Então ficou na janela de "
            "meias olhando, e ela não olhou para Wren nenhuma vez, e depois de vinte "
            "minutos alçou voo, e as asas quando se abriram eram a coisa mais fina "
            "que ela já tinha visto, e atravessou a água até o telhado do número "
            "onze e se dobrou de novo. A avó veio e ficou ao lado dela, em algum "
            "momento, com uma segunda xícara de chá. — Ah — disse. — Então voltou. E "
            "desceu para cuidar do carpete, o que era, pensou Wren, uma coisa "
            "extraordinária de se dizer e depois simplesmente deixar ali largada."
        ),
        1: (
            "No segundo dia a gritaria tinha parado. Tinha sido divertido no primeiro "
            "dia, de um jeito sombrio. O senhor Adeyemi do número nove tinha uma voz "
            "que alcançava longe e gritava as notícias por cima da água como um "
            "pregoeiro: a luz tinha caído na parte de baixo, a venda tinha subido o "
            "estoque para a prateleira de cima, alguém tinha visto um lúcio passando "
            "nadando pela caixa de correio. As pessoas se debruçavam e riam. Mas "
            "gritar o dia inteiro deixa a pessoa rouca, e deixa cansada, e na tarde "
            "de quarta as janelas tinham silenciado e cada um estava sozinho na sua "
            "casa sendo sensato. Wren escreveu um bilhete. Fez isso mais para ter "
            "alguma coisa a fazer. Arrancou uma folha do fim do caderno e escreveu "
            "*vocês estão bem aí*, e não pôs nome nenhum porque não sabia para qual "
            "casa estava escrevendo. Dobrou bem pequeno e pôs no parapeito de fora "
            "debaixo de uma pedra. Fez do jeito que se joga uma moeda num poço. Sem "
            "esperar nada de verdade. Só fazendo. De manhã tinha sumido. No lugar "
            "havia um papel diferente, úmido numa ponta, dobrado do mesmo jeito. "
            "Dizia: *sim, e temos pão demais.* Wren ficou na janela com ele nas duas "
            "mãos por um tempo longo. Depois disso, ninguém precisou explicar nada a "
            "ninguém. Essa foi a parte estranha, a parte em que ela pensou durante "
            "anos depois — como uma coisa vira normal depressa quando é útil. Na "
            "quinta havia bilhetes em quatro parapeitos. Na sexta havia bilhetes em "
            "doze. A garça ia de telhado em telhado com seu passo longo e cuidadoso, "
            "e nunca tinha pressa, e nunca ia a uma casa que não tivesse posto "
            "alguma coisa para fora. Onde os pés dela tocavam a água na beira de um "
            "telhado, a água tinia, bem de leve, como uma taça batida com a colher. "
            "Se você estivesse prestando atenção, dava para saber em que parte da "
            "cidade ela estava. Os bilhetes não eram dramáticos. Era disso que Wren "
            "gostava neles. *Temos pão demais. A senhora Pryor está com tosse e sem "
            "mel. Alguém consegue chegar nos Kelly, ninguém viu luz na casa dos "
            "Kelly. Tem mel no número quatro, avisem a senhora Pryor. Os Kelly foram "
            "para a casa da filha no domingo, estão bem, parem de se preocupar com "
            "os Kelly.* E mais tarde, quando já durava cinco dias e todo mundo "
            "estava entediado e com medo em igual medida: *Tomas faz oito anos hoje "
            "e não tem bolo.* Uma dúzia de casas pôs alguma coisa no parapeito "
            "naquela noite. Wren viu a garça atravessar a água nove vezes antes de "
            "escurecer, indo mais devagar a cada vez, e uma vez chegou tão perto da "
            "janela dela que dava para ver o rio revolvendo dentro do peito. De "
            "manhã Tomas do número seis tinha uma coroa de papel, uma barra de "
            "chocolate, um desenho de cachorro assinado por alguém chamada Iris, um "
            "livro sobre submarinos com a primeira página arrancada, e quatro "
            "bilhetes separados que diziam *feliz aniversário* em quatro letras "
            "diferentes. A avó assistiu a tudo isso da cadeira do patamar sem muito "
            "comentário. — Ela não quer nada? — perguntou Wren. — Por fazer isso? A "
            "avó pensou naquilo com a seriedade que a pergunta merecia. — Alguns que "
            "ajudam — disse — não gostam que agradeçam. Não é grosseria. É só que "
            "agradecer transforma aquilo num favor, e nunca foi um favor. Sempre foi "
            "só a coisa que precisava ser feita."
        ),
        2: (
            "Na sexta noite a garça não veio. Wren pôs o bilhete no horário de "
            "sempre, debaixo da pedra de sempre, e ficou olhando o parapeito do "
            "patamar até a avó mandar ela dormir, e de manhã o bilhete ainda estava "
            "lá. Úmido, e enrolando na ponta, e por ler. No começo achou que tinha "
            "feito alguma coisa errada. Releu o próprio bilhete quatro vezes "
            "procurando o erro nele. Dizia: *a tosse da senhora Pryor piorou, alguém "
            "tem termômetro.* Pôs de novo na manhã seguinte com uma pedra em cima e "
            "foi à janela a cada vinte minutos. Às onze horas os parapeitos ao longo "
            "da viela tinham começado a encher. Dava para vê-los do patamar: "
            "quadrados brancos aparecendo no número quatro, no número nove, na casa "
            "dos Henderson, no número onze. Todo mundo tinha escrito alguma coisa. "
            "Todo mundo estava esperando. Não veio nada. É difícil descrever como "
            "foi aquele dia sem fazer parecer pior do que foi. Ninguém estava em "
            "perigo. A água não tinha subido; havia comida em todas as casas; a luz "
            "estava ligada na parte de cima da viela e as pessoas carregavam os "
            "telefones na casa dos Adeyemi passando por cima num gancho de "
            "varal. Nada tinha mudado de fato, exceto que treze bilhetes estavam "
            "sentados em catorze parapeitos molhando, e todo mundo podia ver o "
            "bilhete de todo mundo não sendo recolhido. A cidade tinha se "
            "acostumado em cinco dias. Era isso. Cinco dias não é nada — é menos que "
            "uma semana de aula — e tinha bastado para um modo inteiro de viver se "
            "estabelecer e começar a parecer permanente. A avó de Wren fez o almoço "
            "e não mencionou os bilhetes. Às quatro da tarde o senhor Adeyemi gritou "
            "por cima da água. Foi a primeira gritaria em três dias e soou "
            "enferrujada e alta demais, e ele perguntou se alguém tinha termômetro, "
            "e alguém do número quatro gritou de volta que tinha, e seguiu-se um "
            "negócio lento, difícil, de quarenta minutos, envolvendo um balde, um "
            "pedaço de corda de varal e um bocado de instrução sendo gritada de três "
            "direções ao mesmo tempo. O termômetro chegou seco na casa da senhora "
            "Pryor. A coisa toda tinha levado quarenta minutos e doze pessoas, e "
            "tinha funcionado, e Wren ficou na janela do patamar vendo o balde "
            "voltar pela água marrom na corda e entendeu uma coisa para a qual não "
            "teve palavras senão muito depois. A garça não estava fazendo uma coisa "
            "que eles não podiam fazer. Estava fazendo uma coisa que eles tinham "
            "parado de fazer. Ela disse isso à avó, mais ou menos, com palavras "
            "piores, durante o chá. A avó ouviu até o fim sem interromper, como "
            "sempre fazia, e depois disse: — Ela veio no ano em que eu tinha nove "
            "anos também. Quatro dias, daquela vez. E quando parou de vir, a viela "
            "esticou uma corda do portão dos Henderson até o nosso e deixou lá por "
            "seis anos. — Mexeu o chá. — Ainda estava lá quando sua mãe nasceu. "
            "Alguém tirou no fim porque tinha ficado verde. — Por que parou? — "
            "Tenho sessenta anos de pensar nisso e só tenho uma resposta, e você não "
            "vai gostar. Wren esperou. — Porque estávamos nos virando — disse a "
            "avó. A garça voltou na oitava noite. Wren viu do patamar por volta das "
            "seis da manhã, seguindo pela linha dos telhados das casas de número "
            "ímpar na luz cinzenta, sem pressa, exatamente como antes, recolhendo "
            "seis bilhetes molhados que a essa altura diziam coisas como *a corda "
            "funcionou, usem a corda* e *a senhora Pryor melhorou* e, do número "
            "seis, em letra de criança, *onde você foi.* Levou todos. Não trouxe "
            "nada de volta naquela manhã, até onde alguém pôde perceber. E a corda "
            "continuou esticada entre os portões, porque a essa altura as pessoas "
            "já tinham se acostumado com aquilo também."
        ),
        3: (
            "O rio foi embora do jeito que tinha vindo — sem pedir desculpa, ao longo "
            "de quatro dias lentos. Primeiro voltaram os mourões, depois o topo dos "
            "portões, depois os portões. A viela reapareceu debaixo de uma camada de "
            "lodo da cor de chá com leite, e cheirava a moeda fria e a alguma coisa "
            "mais velha por baixo. Havia um peixe no jardim dos Henderson e ninguém "
            "conseguia concordar sobre o que fazer com ele. Wren subiu ao patamar na "
            "última manhã, antes da escola, naquela parte cinzenta do dia em que "
            "tudo parece inacabado. A garça ainda estava lá. Mas tinha deixado de "
            "ser transparente. Estava na cumeeira do telhado em frente exatamente no "
            "lugar em que tinha estado na primeira manhã, e a luz não atravessava "
            "mais. Estava verde nas bordas e turva no meio, do jeito que o vidro "
            "fica quando o mar terminou com ele. Não havia nada se movendo dentro do "
            "peito dela. Ela atravessou a viela de bota por quinze centímetros de "
            "lodo e pegou a escada no galpão dos Henderson, que continuava virado "
            "para o lado errado, e subiu, o que não devia ter feito, e pôs a mão "
            "nela. Estava fria, e era mais pesada do que parecia, e não se mexeu. "
            "Desceu carregando debaixo de um braço com a escada balançando e pôs no "
            "mourão de canto no fim da viela, onde a luz vem pela estrada no fim da "
            "tarde. Ainda está lá. Alguém pôs uma laje de pedra embaixo com o tempo "
            "para não afundar quando o chão amolecesse. Quem passa acha que é um "
            "enfeite, e é, agora, mas também é uma garça. Os bilhetes foram para uma "
            "lata de biscoito debaixo da cama de Wren. Eram trinta e um, de doze "
            "casas diferentes, incluindo um que dizia *tem mel no número quatro* e "
            "um que só dizia *sim*. A avó disse que deviam guardar a lata em algum "
            "lugar sensato. Guardaram debaixo da cama."
        ),
    },
}


# ═══════════════════════════════════════════════════════════════════════

def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    strings = catalog["strings"]
    added = 0

    for story_id, by_lang in TRANSLATIONS.items():
        story = json.loads((STORIES / f"{story_id}.json").read_text())
        chapters = {c["index"]: c["text"] for c in story["chapters"]}

        # Collect per-chapter so one entry can carry several languages.
        per_chapter: dict[int, dict[str, str]] = {}
        for lang, by_index in by_lang.items():
            for idx, text in by_index.items():
                per_chapter.setdefault(idx, {})[lang] = text

        for idx, langs in sorted(per_chapter.items()):
            key = chapters.get(idx)
            if key is None:
                print(f"  !! {story_id} has no chapter {idx}")
                continue

            entry = strings.get(key, {"extractionState": "manual",
                                      "localizations": {}})
            locs = entry.setdefault("localizations", {})
            locs["en"] = {"stringUnit": {"state": "translated", "value": key}}
            for lang, value in langs.items():
                locs[lang] = {"stringUnit": {"state": "translated",
                                             "value": value}}
            strings[key] = entry
            added += 1
            print(f"  {story_id} ch{idx}: {', '.join(sorted(langs))}")

    CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False))
    print(f"\n{added} chapter bodies merged; catalog now {len(strings)} keys")


if __name__ == "__main__":
    main()
