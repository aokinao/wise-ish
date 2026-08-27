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
    let reflection: String
    let theme: String
    let aside: String
    let tags: [String]
    let isPremium: Bool
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
                !quote.reflection.isEmpty,
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

        let reflectionQuestionCount = catalog.quotes.filter { $0.reflection.contains("？") }.count
        guard reflectionQuestionCount * 10 <= catalog.quotes.count * 4 else {
            throw WiseishCatalogError.invalidQuote("reflection-question-rate")
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

    /// アプリ、Widget、App Intentで同じ日付の一枚を選ぶ決定的なResolver。
    static func dailyQuote(for date: Date, bundle: Bundle = .main, calendar: Calendar = .current) -> WiseishCatalogQuote {
        let catalog = bundledCatalog(bundle: bundle) ?? currentCatalog(bundle: bundle)
        let active = catalog.quotes.filter { $0.isActive(on: date, calendar: calendar) }
        let candidates = active.isEmpty ? catalog.quotes : active
        guard !candidates.isEmpty else { return fallbackCatalog.quotes[0] }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return candidates[abs(day) % candidates.count]
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
                reflection: "曲がった物差しは、違いまでやさしく曲げる。",
                theme: "比較について",
                aside: "三寸ほど怪しい。",
                tags: ["relationship", "daily"],
                isPremium: false,
                activeMonths: nil
            ),
            WiseishCatalogQuote(
                id: "fallback-foggy",
                mood: "foggy",
                text: "知識が増えるほど、無知も広がる。\n茶柱一本にも、なぜ立つのか分からぬことが多い。",
                reflection: "知るほど、知らないものの輪郭が増える。",
                theme: "情報について",
                aside: "茶は見てよい。",
                tags: ["information", "work"],
                isPremium: false,
                activeMonths: nil
            ),
            WiseishCatalogQuote(
                id: "fallback-thinking",
                mood: "thinking",
                text: "人は、分からぬものに名前をつけて安心する。\nわしは昨夜の不眠を、真理と名づけた。",
                reflection: "名前をつけただけで、分かった気になっているものはある？",
                theme: "思考について",
                aside: "真理は、少し眠い。",
                tags: ["rest", "work"],
                isPremium: false,
                activeMonths: nil
            )
        ]
    )
}
