import AppIntents
import Foundation

struct TodayWiseishIntent: AppIntent {
    static let title: LocalizedStringResource = "今日のWise-ish"
    static let description = IntentDescription("今日の哲学っぽい迷言を、Ishがひとつ返します。")
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

        if let generated = WiseishContextStore.recentGeneratedQuote(now: date),
           calendar.isDate(generated.createdAt, inSameDayAs: date),
           let quote = catalog.quotes.first(where: { $0.id == generated.catalogID }) {
            return quote
        }

        let mood = WiseishContextStore.recommendedMood(date: date)
        let candidates = catalog.quotes.filter { $0.mood == mood }
        let available = candidates.isEmpty ? catalog.quotes : candidates
        let index = WiseishContextStore.preferredIndex(
            candidateIDs: available.map(\.id),
            candidateTags: Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0.tags) }),
            date: date
        )
        return available[index % available.count]
    }
}
