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
                !quote.tags.isEmpty,
                quote.tags.allSatisfy(tags.contains),
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
        if let cached = cachedCatalog() { return cached }
        if let bundled = bundledCatalog(bundle: bundle) { return bundled }
        return fallbackCatalog
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
        catalogVersion: "fallback-1",
        quotes: [
            WiseishCatalogQuote(
                id: "fallback-quiet",
                mood: "quiet",
                text: "心を空っぽにするのじゃ。\n団子は入れてよい。\nたぶんの。",
                reflection: "今日は何を一つ、置いておけそう？",
                theme: "余白について",
                aside: "団子は別腹じゃ。",
                tags: ["rest", "daily"],
                isPremium: false
            ),
            WiseishCatalogQuote(
                id: "fallback-foggy",
                mood: "foggy",
                text: "霧にも道はあるのじゃ。\nなければ茶にする。",
                reflection: "見えるまで、少し休んでもよいかの？",
                theme: "不確かさについて",
                aside: "茶はあったかの？",
                tags: ["rest", "daily"],
                isPremium: false
            ),
            WiseishCatalogQuote(
                id: "fallback-thinking",
                mood: "thinking",
                text: "答えは急ぐと逃げるのじゃ。\nわしはもう座るが。",
                reflection: "その答えは、今日でなくてもよいかの？",
                theme: "答えについて",
                aside: "茶も待っておる。",
                tags: ["work", "information"],
                isPremium: false
            )
        ]
    )
}
