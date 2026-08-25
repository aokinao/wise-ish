import Foundation
import UserNotifications

enum WiseishNotificationService {
    static let notificationID = "wiseish.daily.reminder"

    private static var notificationIDs: [String] {
        [notificationID] + (1...7).map { "\(notificationID).weekday.\($0)" }
    }

    private static let dailyBodies = [
        "日曜日になりました。わしは同じ場所におる。",
        "月曜日です。そういう日も、まああります。",
        "火曜日の分、ここに置いておくぞ。",
        "水曜日です。真ん中かどうかは知らん。",
        "木曜日になりました。日付だけは確かじゃ。",
        "金曜日の分です。特に急がなくてよい。",
        "土曜日です。わしはまだ座っておる。"
    ]

    static func requestAndSchedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let isAuthorized: Bool

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else { return false }
        return await schedule(hour: hour, minute: minute)
    }

    static func schedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: notificationIDs)

        do {
            for weekday in 1...7 {
                let content = UNMutableNotificationContent()
                content.title = "今日のWise-ish"
                content.body = dailyBodies[weekday - 1]
                content.sound = .default
                content.threadIdentifier = "wiseish.daily"

                var components = DateComponents()
                components.weekday = weekday
                components.hour = min(max(hour, 0), 23)
                components.minute = min(max(minute, 0), 59)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(notificationID).weekday.\(weekday)",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            }
            return true
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: notificationIDs)
            return false
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: notificationIDs)
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
