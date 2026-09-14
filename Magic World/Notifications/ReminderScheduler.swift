//
//  ReminderScheduler.swift
//  Magic World
//
//  Lembrete diario de hora da historia.
//
//  A permissao NUNCA e pedida na abertura do app. O sistema so deixa
//  perguntar uma vez: se a crianca (ou o pai) nega no primeiro segundo,
//  sem entender o que e, acabou — so volta pelos Ajustes. Por isso a tela
//  de onboarding explica primeiro e so pede depois do toque.
//

import Foundation
import UserNotifications
import OSLog

enum ReminderScheduler {

    static let identifier = "magicworld.bedtime"
    private static let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "reminders")

    /// True se o usuario autorizou. False tanto para negado quanto para erro.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("permissao de notificacao falhou: \(error.localizedDescription)")
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Reagenda o lembrete diario. Chamar sempre que o horario mudar.
    static func schedule(hour: Int, minute: Int) async {
        cancel()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Story time"
        content.body = "A chapter is waiting."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("lembrete agendado para \(hour):\(minute)")
        } catch {
            log.error("falha ao agendar lembrete: \(error.localizedDescription)")
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
