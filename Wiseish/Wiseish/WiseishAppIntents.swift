import AppIntents
import Foundation

struct TodayWiseishIntent: AppIntent {
    static let title: LocalizedStringResource = "今日のWise-ish"
    static let description = IntentDescription("今日の一言を、Ishがひとつ置いておきます。")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let quote = WiseishTodayQuoteResolver.resolve()
        WiseishContextStore.recordUsage(.appIntentRun)

        let spokenText = "\(quote.text.replacingOccurrences(of: "\n", with: " ")) \(quote.aside)"
        return .result(dialog: IntentDialog(stringLiteral: spokenText))
    }
}

struct WiseishAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayWiseishIntent(),
            phrases: [
                "\(.applicationName)で今日の迷言",
                "\(.applicationName)の今日の言葉",
                "\(.applicationName)に今日のことを聞く"
            ],
            shortTitle: "今日のWise-ish",
            systemImageName: "calendar"
        )
    }
}

private enum WiseishTodayQuoteResolver {
    static func resolve(date: Date = .now, calendar: Calendar = .current) -> WiseishCatalogQuote {
        let catalog = WiseishCatalogStore.currentCatalog()

        if let record = WiseishContextStore.quoteHistory().first(where: {
            calendar.isDate($0.shownAt, inSameDayAs: date)
        }), let quote = catalog.quotes.first(where: { $0.id == record.quoteID }) {
            return quote
        }

        return WiseishCatalogStore.dailyQuote(for: date, bundle: .main, calendar: calendar)
    }
}
