import Foundation

struct WiseishQuoteRecord: Codable, Equatable, Identifiable {
    let id: String
    let quoteID: String
    let text: String
    let theme: String
    let aside: String
    let shownAt: Date
}

enum WiseishUsageEvent: String, CaseIterable {
    case appOpened
    case onboardingReply
    case onboardingCompleted
    case notificationPrompted
    case widgetInstalled
    case favoriteAdded
    case nextQuote
    case shareCardCreated
    case widgetGuideOpened
    case collectionOpened
    case appIntentRun
    case settingsOpened
    case notificationEnabled
}

enum WiseishContextStore {
    static let appGroupID = "group.com.naoki.Wiseish"
    private static let widgetQuoteFileName = "wiseish-widget-quote.json"

    private enum Key {
        static let favoriteQuoteIDs = "personalization.favoriteQuoteIDs"
        static let quoteHistory = "personalization.quoteHistory"
        static let shownQuoteDates = "daily.shownQuoteDates"
        static let usageCounts = "diagnostics.usageCounts"
    }

    // App Groupが利用できない場合に標準UserDefaultsへ混ざると、アプリ固有の
    // データが別Widgetや他の機能から見えてしまう。隔離した一時ストアにする。
    private static let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults()

    static func recordFavorite(quoteID: String, isFavorite: Bool) {
        var ids = Set(defaults.stringArray(forKey: Key.favoriteQuoteIDs) ?? [])
        if isFavorite {
            ids.insert(quoteID)
        } else {
            ids.remove(quoteID)
        }
        defaults.set(Array(ids), forKey: Key.favoriteQuoteIDs)
    }

    static func isFavorite(quoteID: String) -> Bool {
        Set(defaults.stringArray(forKey: Key.favoriteQuoteIDs) ?? []).contains(quoteID)
    }

    static func metDayCount(calendar: Calendar = .current) -> Int {
        Set(quoteHistory().map { calendar.startOfDay(for: $0.shownAt) }).count
    }

    static func recordQuote(
        quoteID: String,
        text: String,
        theme: String,
        aside: String,
        date: Date = .now
    ) {
        let components = Calendar.current.dateComponents([.era, .year, .month, .day], from: date)
        let day = [components.era, components.year, components.month, components.day]
            .map { String($0 ?? 0) }
            .joined(separator: "-")
        let record = WiseishQuoteRecord(
            id: "\(quoteID)-\(day)",
            quoteID: quoteID,
            text: text,
            theme: theme,
            aside: aside,
            shownAt: date
        )
        var records = quoteHistory()
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        // 購入後の「言葉の棚」で全期間を読めるよう、日々の記録は端末内に残す。
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Key.quoteHistory)
        recordShownQuote(quoteID: quoteID, date: date)
        // WidgetはUserDefaultsの復旧待ちで描画が止まることがあるため、
        // 今日実際に表示した一言だけは小さな共有ファイルにも保存する。
        if let widgetURL = widgetQuoteURL,
           let widgetData = try? JSONEncoder().encode(record) {
            try? widgetData.write(to: widgetURL, options: .atomic)
        }
    }

    /// 日めくりの重複回避に使う、IDと表示日時だけの全期間記録。
    static func shownQuoteDates() -> [String: Date] {
        guard
            let data = defaults.data(forKey: Key.shownQuoteDates),
            let dates = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return dates
    }

    private static func recordShownQuote(quoteID: String, date: Date) {
        var dates = shownQuoteDates()
        if let previous = dates[quoteID], Calendar.current.isDate(previous, inSameDayAs: date) {
            return
        }
        dates[quoteID] = date
        guard let data = try? JSONEncoder().encode(dates) else { return }
        defaults.set(data, forKey: Key.shownQuoteDates)
    }

    static func widgetQuote(for date: Date = .now) -> WiseishQuoteRecord? {
        guard let url = widgetQuoteURL,
              let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(WiseishQuoteRecord.self, from: data),
              Calendar.current.isDate(record.shownAt, inSameDayAs: date)
        else { return nil }
        return record
    }

    private static var widgetQuoteURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(widgetQuoteFileName)
    }

    static func quoteHistory() -> [WiseishQuoteRecord] {
        guard
            let data = defaults.data(forKey: Key.quoteHistory),
            let records = try? JSONDecoder().decode([WiseishQuoteRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.shownAt > $1.shownAt }
    }

    static func recordUsage(_ event: WiseishUsageEvent) {
        var counts = defaults.dictionary(forKey: Key.usageCounts) as? [String: Int] ?? [:]
        counts[event.rawValue, default: 0] += 1
        defaults.set(counts, forKey: Key.usageCounts)
    }

    static func recordUsageOnce(_ event: WiseishUsageEvent) {
        var counts = defaults.dictionary(forKey: Key.usageCounts) as? [String: Int] ?? [:]
        guard counts[event.rawValue, default: 0] == 0 else { return }
        counts[event.rawValue] = 1
        defaults.set(counts, forKey: Key.usageCounts)
    }

    static func usageCounts() -> [String: Int] {
        defaults.dictionary(forKey: Key.usageCounts) as? [String: Int] ?? [:]
    }

}
