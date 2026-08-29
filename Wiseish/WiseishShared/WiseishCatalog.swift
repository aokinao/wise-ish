import Foundation

struct WiseishCatalog: Codable, Equatable {
    let schemaVersion: Int
    let catalogVersion: String
    let quotes: [WiseishCatalogQuote]
}

struct WiseishCatalogQuote: Codable, Equatable, Identifiable {
    let id: String
    let mood: String
    let text: String
    let theme: String
    let aside: String
    let tags: [String]
    let activeMonths: [Int]?

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let activeMonths else { return true }
        return activeMonths.contains(calendar.component(.month, from: date))
    }
}

enum WiseishCatalogError: Error {
    case unsupportedSchema
    case emptyCatalog
    case tooManyQuotes
    case duplicateID
    case invalidQuote(String)
}

enum WiseishCatalogValidator {
    private static let moods = Set(["quiet", "foggy", "thinking"])
    private static let tags = Set(["work", "information", "rest", "relationship", "money", "creative", "daily"])
    private static let voiceMarkers = ["じゃ", "かの", "わし", "たぶん", "知らん", "ぬ", "おる", "がの", "ぞい"]

    static func decodeAndValidate(_ data: Data) throws -> WiseishCatalog {
        let catalog = try JSONDecoder().decode(WiseishCatalog.self, from: data)
        try validate(catalog)
        return catalog
    }

    static func validate(_ catalog: WiseishCatalog) throws {
        guard catalog.schemaVersion == 1 else { throw WiseishCatalogError.unsupportedSchema }
        guard catalog.catalogVersion.range(
            of: #"^\d{4}-\d{2}-\d{2}\.\d+$"#,
            options: .regularExpression
        ) != nil else {
            throw WiseishCatalogError.invalidQuote("catalogVersion")
        }
        guard !catalog.quotes.isEmpty else { throw WiseishCatalogError.emptyCatalog }
        guard catalog.quotes.count <= 500 else { throw WiseishCatalogError.tooManyQuotes }
        guard Set(catalog.quotes.map(\.id)).count == catalog.quotes.count else {
            throw WiseishCatalogError.duplicateID
        }

        for quote in catalog.quotes {
            let lineCount = quote.text.split(whereSeparator: { $0.isNewline }).count
            let characterCount = quote.text.filter { !$0.isWhitespace && !$0.isNewline }.count
            guard
                !quote.id.isEmpty,
                moods.contains(quote.mood),
                (2...3).contains(lineCount),
                (12...80).contains(characterCount),
                !quote.theme.isEmpty,
                !quote.aside.isEmpty,
                voiceMarkers.contains(where: { quote.text.contains($0) || quote.aside.contains($0) }),
                !quote.tags.isEmpty,
                quote.tags.allSatisfy(tags.contains),
                quote.activeMonths?.allSatisfy((1...12).contains) != false,
                quote.activeMonths?.isEmpty != true,
                !quote.text.contains("."),
                !quote.text.contains(",")
            else {
                throw WiseishCatalogError.invalidQuote(quote.id)
            }
        }

    }
}

enum WiseishCatalogStore {
    private static let cacheFileName = "wiseish-quotes.json"

    static func currentCatalog(bundle: Bundle = .main) -> WiseishCatalog {
        let cached = cachedCatalog()
        let bundled = bundledCatalog(bundle: bundle)
        if let cached, let bundled {
            return isNewerCatalogVersion(cached.catalogVersion, than: bundled.catalogVersion) ? cached : bundled
        }
        if let cached { return cached }
        if let bundled { return bundled }
        return fallbackCatalog
    }

    static func isNewerCatalogVersion(_ lhs: String, than rhs: String) -> Bool {
        guard let left = catalogVersionKey(lhs), let right = catalogVersionKey(rhs) else {
            return lhs > rhs
        }
        return left > right
    }

    private static func catalogVersionKey(_ version: String) -> (Int, Int, Int, Int)? {
        let parts = version.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let dateParts = parts[0].split(separator: "-").compactMap { Int($0) }
        guard dateParts.count == 3, let revision = Int(parts[1]) else { return nil }
        return (dateParts[0], dateParts[1], dateParts[2], revision)
    }

    static func bundledCatalog(bundle: Bundle = .main) -> WiseishCatalog? {
        guard
            let url = bundle.url(forResource: "quotes", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? WiseishCatalogValidator.decodeAndValidate(data)
    }

    /// アプリとApp Intentで使う決定的なResolver。リモート更新を含む現行Catalogを使う。
    static func dailyQuote(for date: Date, bundle: Bundle = .main, calendar: Calendar = .current) -> WiseishCatalogQuote {
        dailyQuote(
            for: date,
            catalog: currentCatalog(bundle: bundle),
            shownQuoteDates: WiseishContextStore.shownQuoteDates(),
            calendar: calendar
        )
    }

    /// Widgetの未確定時に使うResolver。App GroupのCatalogキャッシュは読まず、
    /// 拡張に同梱されたCatalogだけを使って即時描画する。
    static func bundledDailyQuote(for date: Date, bundle: Bundle = .main, calendar: Calendar = .current) -> WiseishCatalogQuote {
        dailyQuote(for: date, catalog: bundledCatalog(bundle: bundle) ?? fallbackCatalog, calendar: calendar)
    }

    static func dailyQuote(for date: Date, catalog: WiseishCatalog, calendar: Calendar = .current) -> WiseishCatalogQuote {
        dailyQuote(for: date, catalog: catalog, shownQuoteDates: WiseishContextStore.shownQuoteDates(), calendar: calendar)
    }

    static func dailyQuote(
        for date: Date,
        catalog: WiseishCatalog,
        shownQuoteDates: [String: Date],
        calendar: Calendar = .current
    ) -> WiseishCatalogQuote {
        let active = catalog.quotes.filter { $0.isActive(on: date, calendar: calendar) }
        let candidates = active.isEmpty ? catalog.quotes : active
        guard !candidates.isEmpty else { return fallbackCatalog.quotes[0] }

        // その日の表示済みの一枚は、再起動やWidget更新でも固定する。
        let shownToday = candidates.first { quote in
            guard let shownAt = shownQuoteDates[quote.id] else { return false }
            return calendar.isDate(shownAt, inSameDayAs: date)
        }
        if let shownToday { return shownToday }

        let unseen = candidates.filter { shownQuoteDates[$0.id] == nil }
        if unseen.isEmpty {
            // 一巡後は、最も古く表示した言葉から再登場させる。
            let order = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($0.element.id, $0.offset) })
            return candidates.min { lhs, rhs in
                let left = shownQuoteDates[lhs.id] ?? .distantPast
                let right = shownQuoteDates[rhs.id] ?? .distantPast
                return left == right
                    ? order[lhs.id, default: 0] < order[rhs.id, default: 0]
                    : left < right
            } ?? candidates[0]
        }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return unseen[abs(day) % unseen.count]
    }

    static func cachedCatalog() -> WiseishCatalog? {
        guard
            let url = cacheURL,
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? WiseishCatalogValidator.decodeAndValidate(data)
    }

    static func saveRemoteCatalog(data: Data) throws {
        _ = try WiseishCatalogValidator.decodeAndValidate(data)
        guard let url = cacheURL else { return }
        try data.write(to: url, options: .atomic)
    }

    private static var cacheURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WiseishContextStore.appGroupID)?
            .appendingPathComponent(cacheFileName)
    }

    private static let fallbackCatalog = WiseishCatalog(
        schemaVersion: 1,
        catalogVersion: "fallback-2",
        quotes: [
            WiseishCatalogQuote(
                id: "fallback-quiet",
                mood: "quiet",
                text: "人は物差しで世界を比べる。\nわしのは曲がっておるので、だいたい皆同じじゃ。",
                theme: "比較について",
                aside: "三寸ほど怪しい。",
                tags: ["relationship", "daily"],
                activeMonths: nil
            ),
            WiseishCatalogQuote(
                id: "fallback-foggy",
                mood: "foggy",
                text: "知識が増えるほど、無知も広がる。\n茶柱一本にも、なぜ立つのか分からぬことが多い。",
                theme: "情報について",
                aside: "茶は見てよい。",
                tags: ["information", "work"],
                activeMonths: nil
            ),
            WiseishCatalogQuote(
                id: "fallback-thinking",
                mood: "thinking",
                text: "人は、分からぬものに名前をつけて安心する。\nわしは昨夜の不眠を、真理と名づけた。",
                theme: "思考について",
                aside: "真理は、少し眠い。",
                tags: ["rest", "work"],
                activeMonths: nil
            )
        ]
    )
}
