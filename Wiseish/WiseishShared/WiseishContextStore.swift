import Foundation

struct WiseishExternalContext: Codable, Equatable {
    let tags: [String]
    let reason: String
    let createdAt: Date
}

struct WiseishPendingInput: Codable, Equatable {
    let text: String
    let createdAt: Date
}

struct WiseishGeneratedQuote: Codable, Equatable {
    let catalogID: String
    let text: String
    let reflection: String
    let theme: String
    let aside: String
    let contextReason: String
    let tags: [String]
    let createdAt: Date
}

struct WiseishQuoteRecord: Codable, Equatable, Identifiable {
    let id: String
    let quoteID: String
    let text: String
    let reflection: String
    let theme: String
    let aside: String
    let shownAt: Date
}

enum WiseishReflectionReaction: String, Codable, CaseIterable {
    case resonate
    case leaveIt
    case unknown
}

enum WiseishUsageEvent: String, CaseIterable {
    case appOpened
    case onboardingReply
    case onboardingCompleted
    case notificationPrompted
    case widgetInstalled
    case favoriteAdded
    case nextQuote
    case moodChanged
    case aiRequested
    case shareCardCreated
    case widgetGuideOpened
    case collectionOpened
    case appIntentRun
    case reflectionReacted
    case settingsOpened
    case notificationEnabled
}

enum WiseishContextStore {
    static let appGroupID = "group.com.naoki.Wiseish"

    private enum Key {
        static let preferredMood = "personalization.preferredMood"
        static let preferredMoodDay = "personalization.preferredMoodDay"
        static let favoriteQuoteIDs = "personalization.favoriteQuoteIDs"
        static let skippedQuoteCounts = "personalization.skippedQuoteCounts"
        static let externalContext = "personalization.externalContext"
        static let pendingInput = "personalization.pendingInput"
        static let generatedQuote = "personalization.generatedQuote"
        static let quoteHistory = "personalization.quoteHistory"
        static let usageCounts = "diagnostics.usageCounts"
        static let reflectionReactions = "personalization.reflectionReactions"
        static let quoteReactionScores = "personalization.quoteReactionScores"
        static let tagReactionScores = "personalization.tagReactionScores"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var preferredMood: String? {
        preferredMood(for: .now)
    }

    static func recordMood(_ mood: String, date: Date = .now) {
        defaults.set(mood, forKey: Key.preferredMood)
        defaults.set(dayKey(for: date), forKey: Key.preferredMoodDay)
    }

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

    static func recordSkip(quoteID: String) {
        var counts = defaults.dictionary(forKey: Key.skippedQuoteCounts) as? [String: Int] ?? [:]
        counts[quoteID, default: 0] += 1
        defaults.set(counts, forKey: Key.skippedQuoteCounts)
    }

    static func preferredIndex(
        candidateIDs: [String],
        candidateTags: [String: [String]] = [:],
        date: Date = .now
    ) -> Int {
        guard !candidateIDs.isEmpty else { return 0 }
        let favorites = Set(defaults.stringArray(forKey: Key.favoriteQuoteIDs) ?? [])
        let skips = defaults.dictionary(forKey: Key.skippedQuoteCounts) as? [String: Int] ?? [:]
        let quoteScores = defaults.dictionary(forKey: Key.quoteReactionScores) as? [String: Int] ?? [:]
        let tagScores = defaults.dictionary(forKey: Key.tagReactionScores) as? [String: Int] ?? [:]
        let contextTags = Set(recentExternalContext(now: date)?.tags ?? [])
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let contextBias = contextTags.joined().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let recentDays = recentlyShownDaysByQuoteID(relativeTo: date)

        let ranked = candidateIDs.enumerated().sorted { lhs, rhs in
            let lhsScore = (favorites.contains(lhs.element) ? 3 : 0) - min(skips[lhs.element, default: 0], 3)
                + reactionScore(for: lhs.element, candidateTags: candidateTags, quoteScores: quoteScores, tagScores: tagScores)
                + contextScore(for: lhs.element, candidateTags: candidateTags, contextTags: contextTags)
                + recencyScore(daysAgo: recentDays[lhs.element])
                + ((day + contextBias + lhs.offset) % candidateIDs.count == 0 ? 1 : 0)
            let rhsScore = (favorites.contains(rhs.element) ? 3 : 0) - min(skips[rhs.element, default: 0], 3)
                + reactionScore(for: rhs.element, candidateTags: candidateTags, quoteScores: quoteScores, tagScores: tagScores)
                + contextScore(for: rhs.element, candidateTags: candidateTags, contextTags: contextTags)
                + recencyScore(daysAgo: recentDays[rhs.element])
                + ((day + contextBias + rhs.offset) % candidateIDs.count == 0 ? 1 : 0)
            return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
        }
        return ranked.first?.offset ?? 0
    }

    static func recordReflectionReaction(
        _ reaction: WiseishReflectionReaction,
        quoteID: String,
        tags: [String],
        date: Date = .now
    ) {
        let key = reflectionKey(quoteID: quoteID, date: date)
        var reactions = defaults.dictionary(forKey: Key.reflectionReactions) as? [String: String] ?? [:]
        var quoteScores = defaults.dictionary(forKey: Key.quoteReactionScores) as? [String: Int] ?? [:]
        var tagScores = defaults.dictionary(forKey: Key.tagReactionScores) as? [String: Int] ?? [:]

        if let previousRawValue = reactions[key],
           let previous = WiseishReflectionReaction(rawValue: previousRawValue) {
            applyReaction(previous, multiplier: -1, quoteID: quoteID, tags: tags, quoteScores: &quoteScores, tagScores: &tagScores)
        }

        reactions[key] = reaction.rawValue
        applyReaction(reaction, multiplier: 1, quoteID: quoteID, tags: tags, quoteScores: &quoteScores, tagScores: &tagScores)
        defaults.set(reactions, forKey: Key.reflectionReactions)
        defaults.set(quoteScores, forKey: Key.quoteReactionScores)
        defaults.set(tagScores, forKey: Key.tagReactionScores)
    }

    static func reflectionReaction(
        quoteID: String,
        date: Date = .now
    ) -> WiseishReflectionReaction? {
        let reactions = defaults.dictionary(forKey: Key.reflectionReactions) as? [String: String] ?? [:]
        return reactions[reflectionKey(quoteID: quoteID, date: date)]
            .flatMap(WiseishReflectionReaction.init(rawValue:))
    }

    static func previousDayReaction(
        relativeTo date: Date = .now,
        calendar: Calendar = .current
    ) -> WiseishReflectionReaction? {
        guard let previousDate = calendar.date(byAdding: .day, value: -1, to: date),
              let record = quoteHistory().first(where: {
                  calendar.isDate($0.shownAt, inSameDayAs: previousDate)
              }) else {
            return nil
        }
        return reflectionReaction(quoteID: record.quoteID, date: previousDate)
    }

    static func metDayCount(calendar: Calendar = .current) -> Int {
        Set(quoteHistory().map { calendar.startOfDay(for: $0.shownAt) }).count
    }

    static func saveExternalContext(tags: [String], reason: String, date: Date = .now) {
        let context = WiseishExternalContext(tags: Array(Set(tags)).sorted(), reason: reason, createdAt: date)
        guard let data = try? JSONEncoder().encode(context) else { return }
        defaults.set(data, forKey: Key.externalContext)
    }

    static func recentExternalContext(now: Date = .now) -> WiseishExternalContext? {
        guard
            let data = defaults.data(forKey: Key.externalContext),
            let context = try? JSONDecoder().decode(WiseishExternalContext.self, from: data),
            now.timeIntervalSince(context.createdAt) < 60 * 60 * 24 * 7
        else {
            return nil
        }
        return context
    }

    static func savePendingInput(_ text: String, date: Date = .now) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let input = WiseishPendingInput(text: String(trimmed.prefix(1_200)), createdAt: date)
        guard let data = try? JSONEncoder().encode(input) else { return }
        defaults.set(data, forKey: Key.pendingInput)
    }

    static func pendingInput(now: Date = .now) -> WiseishPendingInput? {
        guard
            let data = defaults.data(forKey: Key.pendingInput),
            let input = try? JSONDecoder().decode(WiseishPendingInput.self, from: data)
        else {
            return nil
        }
        guard now.timeIntervalSince(input.createdAt) < 60 * 60 else {
            clearPendingInput()
            return nil
        }
        return input
    }

    static func clearPendingInput() {
        defaults.removeObject(forKey: Key.pendingInput)
    }

    static func saveGeneratedQuote(_ quote: WiseishGeneratedQuote) {
        guard let data = try? JSONEncoder().encode(quote) else { return }
        defaults.set(data, forKey: Key.generatedQuote)
    }

    static func recentGeneratedQuote(now: Date = .now) -> WiseishGeneratedQuote? {
        guard
            let data = defaults.data(forKey: Key.generatedQuote),
            let quote = try? JSONDecoder().decode(WiseishGeneratedQuote.self, from: data),
            now.timeIntervalSince(quote.createdAt) >= -300,
            now.timeIntervalSince(quote.createdAt) < 60 * 60 * 24 * 7
        else {
            return nil
        }
        return quote
    }

    static func generatedQuoteIsFromToday(now: Date = .now) -> Bool {
        guard let quote = recentGeneratedQuote(now: now) else { return false }
        return Calendar.current.isDate(quote.createdAt, inSameDayAs: now)
    }

    static func recordQuote(
        quoteID: String,
        text: String,
        reflection: String,
        theme: String,
        aside: String,
        date: Date = .now
    ) {
        let day = date.formatted(.iso8601.year().month().day())
        let record = WiseishQuoteRecord(
            id: "\(quoteID)-\(day)",
            quoteID: quoteID,
            text: text,
            reflection: reflection,
            theme: theme,
            aside: aside,
            shownAt: date
        )
        var records = quoteHistory()
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        guard let data = try? JSONEncoder().encode(Array(records.prefix(100))) else { return }
        defaults.set(data, forKey: Key.quoteHistory)
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

    static func recommendedMood(date: Date = .now) -> String {
        if let preferredMood = preferredMood(for: date) { return preferredMood }
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 22 || hour < 6 { return "thinking" }
        if recentExternalContext()?.tags.contains("information") == true { return "foggy" }
        return "quiet"
    }

    private static func preferredMood(for date: Date) -> String? {
        guard defaults.string(forKey: Key.preferredMoodDay) == dayKey(for: date) else {
            return nil
        }
        return defaults.string(forKey: Key.preferredMood)
    }

    private static func dayKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    private static func reactionScore(
        for quoteID: String,
        candidateTags: [String: [String]],
        quoteScores: [String: Int],
        tagScores: [String: Int]
    ) -> Int {
        let quoteScore = min(max(quoteScores[quoteID, default: 0], -3), 3)
        let tagScore = candidateTags[quoteID]?
            .map { tagScores[$0, default: 0] }
            .max()
            .map { min(max($0, -2), 2) } ?? 0
        return quoteScore + tagScore
    }

    private static func contextScore(
        for quoteID: String,
        candidateTags: [String: [String]],
        contextTags: Set<String>
    ) -> Int {
        Set(candidateTags[quoteID] ?? []).intersection(contextTags).count * 3
    }

    private static func recentlyShownDaysByQuoteID(relativeTo date: Date) -> [String: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        var result: [String: Int] = [:]

        for record in quoteHistory() {
            let shownDay = calendar.startOfDay(for: record.shownAt)
            guard let daysAgo = calendar.dateComponents([.day], from: shownDay, to: today).day,
                  (0...6).contains(daysAgo) else {
                continue
            }
            result[record.quoteID] = min(result[record.quoteID] ?? daysAgo, daysAgo)
        }
        return result
    }

    private static func recencyScore(daysAgo: Int?) -> Int {
        guard let daysAgo else { return 0 }
        return switch daysAgo {
        case 0: -12
        case 1: -8
        case 2: -5
        case 3: -3
        case 4...6: -1
        default: 0
        }
    }

    private static func reflectionKey(quoteID: String, date: Date) -> String {
        "\(date.formatted(.iso8601.year().month().day()))|\(quoteID)"
    }

    private static func applyReaction(
        _ reaction: WiseishReflectionReaction,
        multiplier: Int,
        quoteID: String,
        tags: [String],
        quoteScores: inout [String: Int],
        tagScores: inout [String: Int]
    ) {
        switch reaction {
        case .resonate:
            quoteScores[quoteID, default: 0] += 2 * multiplier
            for tag in tags { tagScores[tag, default: 0] += multiplier }
        case .leaveIt:
            tagScores["rest", default: 0] += 2 * multiplier
        case .unknown:
            quoteScores[quoteID, default: 0] -= multiplier
            tagScores["creative", default: 0] += multiplier
            tagScores["daily", default: 0] += multiplier
        }
    }
}

enum WiseishContextClassifier {
    static func classify(_ text: String) -> WiseishExternalContext {
        let normalized = text.lowercased()
        var tags: [String] = []

        appendTag("work", whenAnyOf: ["仕事", "会議", "会社", "上司", "締切", "タスク", "work", "meeting", "deadline"], in: normalized, to: &tags)
        appendTag("information", whenAnyOf: ["ニュース", "炎上", "速報", "まとめ", "情報", "ai", "news", "trend"], in: normalized, to: &tags)
        appendTag("rest", whenAnyOf: ["休", "眠", "疲", "風呂", "お茶", "sleep", "tired", "break"], in: normalized, to: &tags)
        appendTag("relationship", whenAnyOf: ["友達", "恋", "家族", "人間関係", "friend", "love", "family"], in: normalized, to: &tags)
        appendTag("money", whenAnyOf: ["お金", "投資", "株", "給料", "節約", "money", "stock", "salary"], in: normalized, to: &tags)
        appendTag("creative", whenAnyOf: ["作る", "デザイン", "絵", "音楽", "本", "creative", "design", "music", "book"], in: normalized, to: &tags)

        if tags.isEmpty { tags = ["daily"] }
        let reason = reasonText(for: tags)
        return WiseishExternalContext(tags: tags, reason: reason, createdAt: .now)
    }

    private static func appendTag(_ tag: String, whenAnyOf words: [String], in text: String, to tags: inout [String]) {
        if words.contains(where: text.contains) { tags.append(tag) }
    }

    private static func reasonText(for tags: [String]) -> String {
        if tags.contains("information") { return "情報を少し浴びた日" }
        if tags.contains("work") { return "仕事の気配が濃い日" }
        if tags.contains("rest") { return "休みどきを探している日" }
        if tags.contains("relationship") { return "人のことを考えた日" }
        if tags.contains("money") { return "数字が気になる日" }
        if tags.contains("creative") { return "何かを作りたい日" }
        return "気になるものを拾った日"
    }
}
