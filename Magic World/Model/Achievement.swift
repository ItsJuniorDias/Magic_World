//
//  Achievement.swift
//  Magic World
//
//  O QUE NAO TEM AQUI, E POR QUE
//
//  Nao ha sequencia de dias. Nao ha meta diaria. Nao ha nada que se perca
//  por nao abrir o app.
//
//  O dado existe — `ChapterState.lastOpened` guarda a data, entao calcular
//  "sete noites seguidas" seria trivial. E e exatamente por isso que vale
//  escrever por que nao foi feito.
//
//  Isto e um app de hora de dormir para uma crianca de nove a onze anos.
//  Sequencia transforma uma noite perdida em prejuizo, e cria pressao pra
//  ler numa noite em que a crianca deveria estar dormindo. As duas coisas
//  sao o oposto do que o app existe pra fazer. Um pai que deixa a crianca
//  dormir mais cedo nao pode ser punido por isso na tela seguinte.
//
//  Entao as conquistas aqui sao registro de onde voce esteve, nao placar
//  de com que frequencia apareceu. Nenhuma se perde. Nenhuma expira.
//  Nenhuma destranca conteudo — o que destranca conteudo e a assinatura, e
//  misturar as duas coisas seria vender leitura como recompensa.
//

import Foundation

struct Achievement: Identifiable, Hashable {
    enum Family: String, CaseIterable {
        case creatures, realms, chapters, listening, keeping

        var label: String {
            switch self {
            case .creatures: "Creatures"
            case .realms: "Realms"
            case .chapters: "Chapters"
            case .listening: "Listening"
            case .keeping: "Keeping"
            }
        }
    }

    let id: String
    let family: Family
    let title: String
    /// O que a pessoa fez. Sempre no passado e sempre concreto — "voce leu
    /// dez historias", nunca "continue assim".
    let detail: String
    let symbol: String
    /// Quanto falta, de 0 a 1. Conquista fechada e 1.
    let progress: Double
    let isEarned: Bool
    /// Texto do que falta, quando ainda nao fechou. Nil quando fechou.
    let remaining: String?

    /// Nome da arte do selo, sem o prefixo `badge-`.
    ///
    /// Um desenho por FAMILIA, e nao por conquista: cinco patas quase
    /// iguais lado a lado na grade pareceriam erro, e o numero que as
    /// distingue o cartao ja escreve. As excecoes sao os cinco habitats,
    /// que sao lugares diferentes, e o "All fifty", que fecha a coleção.
    var art: String? {
        switch family {
        case .creatures: id == "creatures-50" ? "creatures-all" : "creatures"
        case .chapters: "chapters"
        case .listening: "listening"
        case .realms: id == "realm-everywhere"
            ? "everywhere" : String(id.dropFirst("realm-".count))
        case .keeping: id == "keeping-favorites" ? "favorites" : "bedtime"
        }
    }
}

// MARK: - Calculo

enum Achievements {

    /// Marcos de historias terminadas. Chamadas de criaturas porque e assim
    /// que o app fala de si em todo lugar.
    private static let creatureSteps = [1, 5, 10, 25, 50]
    private static let chapterSteps = [4, 20, 60, 120, 200]
    /// Em segundos: uma hora, tres, cinco, e o acervo inteiro.
    private static let listeningSteps: [TimeInterval] = [3600, 3 * 3600, 5 * 3600, 9 * 3600]

    static func all(library: ContentLibrary,
                    progress: ReadingProgress,
                    app: AppState) -> [Achievement] {
        let finished = library.stories.filter { progress.completion(of: $0) >= 1 }
        let chapters = progress.chaptersRead
        let seconds = listenedSeconds(library: library, progress: progress)

        var out: [Achievement] = []
        out += creatures(finished.count, total: library.stories.count)
        out += realms(finished: finished, library: library)
        out += chapterMilestones(chapters, total: library.stories.count * 4)
        out += listening(seconds)
        out += keeping(app: app, finished: finished.count)
        return out
    }

    /// Soma da duracao dos capitulos concluidos. Usa a duracao real do
    /// audio quando ela existe; quando nao, a estimativa do texto — que e a
    /// mesma que a lista mostra, entao os dois numeros nunca se contradizem.
    static func listenedSeconds(library: ContentLibrary,
                                progress: ReadingProgress) -> TimeInterval {
        var total: TimeInterval = 0
        for story in library.stories {
            for chapter in story.chapters
            where progress.isComplete(storyId: story.id, chapterIndex: chapter.index) {
                total += chapter.audioDuration
                    ?? library.timings(storyId: story.id,
                                       chapterIndex: chapter.index)?.duration
                    ?? 0
            }
        }
        return total
    }

    // MARK: Familias

    private static func creatures(_ count: Int, total: Int) -> [Achievement] {
        creatureSteps.map { step in
            let earned = count >= step
            return Achievement(
                id: "creatures-\(step)",
                family: .creatures,
                title: step == 1 ? "The first one"
                     : step == total ? "All fifty"
                     : "\(step) creatures",
                detail: step == 1
                    ? "You finished a story from beginning to end."
                    : "You have met \(step) of the fifty.",
                symbol: step == total ? "star.circle.fill" : "pawprint.fill",
                progress: min(1, Double(count) / Double(step)),
                isEarned: earned,
                remaining: earned ? nil
                    : "\(step - count) more \(step - count == 1 ? "story" : "stories")")
        }
    }

    /// Um selo por habitat completo, mais um por ter estado nos cinco.
    private static func realms(finished: [Story], library: ContentLibrary) -> [Achievement] {
        var out: [Achievement] = []
        var completeRealms = 0

        for realm in Story.Realm.allCases {
            let inRealm = library.stories.filter { $0.realm == realm }
            guard !inRealm.isEmpty else { continue }
            let done = finished.filter { $0.realm == realm }.count
            let earned = done == inRealm.count
            if earned { completeRealms += 1 }
            out.append(Achievement(
                id: "realm-\(realm.rawValue)",
                family: .realms,
                title: realm.label,
                detail: "You have read every story in \(realm.label).",
                symbol: realm.symbol,
                progress: Double(done) / Double(inRealm.count),
                isEarned: earned,
                remaining: earned ? nil : "\(inRealm.count - done) left here"))
        }

        let all = Story.Realm.allCases.count
        out.append(Achievement(
            id: "realm-everywhere",
            family: .realms,
            title: "Everywhere",
            detail: "You have read every story in all five realms.",
            symbol: "globe.europe.africa.fill",
            progress: Double(completeRealms) / Double(all),
            isEarned: completeRealms == all,
            remaining: completeRealms == all ? nil
                : "\(all - completeRealms) realms to finish"))
        return out
    }

    private static func chapterMilestones(_ count: Int, total: Int) -> [Achievement] {
        chapterSteps.map { step in
            let earned = count >= step
            return Achievement(
                id: "chapters-\(step)",
                family: .chapters,
                title: step >= total ? "Every chapter" : "\(step) chapters",
                detail: "You have finished \(step) chapters.",
                symbol: "book.closed.fill",
                progress: min(1, Double(count) / Double(step)),
                isEarned: earned,
                remaining: earned ? nil : "\(step - count) to go")
        }
    }

    private static func listening(_ seconds: TimeInterval) -> [Achievement] {
        listeningSteps.map { step in
            let hours = Int(step / 3600)
            let earned = seconds >= step
            return Achievement(
                id: "listening-\(hours)",
                family: .listening,
                title: hours == 1 ? "An hour" : "\(hours) hours",
                detail: "You have listened for \(hours) hours.",
                symbol: "waveform",
                progress: min(1, seconds / step),
                isEarned: earned,
                remaining: earned ? nil
                    : "\(Int((step - seconds) / 60)) minutes more")
        }
    }

    /// Favoritos e o lembrete. Sao as duas unicas coisas que a pessoa
    /// escolhe deliberadamente, e nenhuma delas depende de ler mais.
    private static func keeping(app: AppState, finished: Int) -> [Achievement] {
        var out: [Achievement] = []
        let favs = app.favoriteIds.count
        out.append(Achievement(
            id: "keeping-favorites",
            family: .keeping,
            title: "A shelf of your own",
            detail: "You have kept five stories as favourites.",
            symbol: "heart.fill",
            progress: min(1, Double(favs) / 5),
            isEarned: favs >= 5,
            remaining: favs >= 5 ? nil : "\(5 - favs) more to keep"))

        out.append(Achievement(
            id: "keeping-bedtime",
            family: .keeping,
            title: "A time set aside",
            detail: "You chose an hour for reading.",
            symbol: "moon.stars.fill",
            progress: app.bedtimeReminderEnabled ? 1 : 0,
            isEarned: app.bedtimeReminderEnabled,
            remaining: app.bedtimeReminderEnabled ? nil : "Set a reminder"))
        return out
    }
}
