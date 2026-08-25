import SwiftUI
import WidgetKit

private struct WidgetQuote {
    let id: String
    let mood: String
    let text: String
    let theme: String
    let tags: [String]
    let activeMonths: [Int]?

    func isActive(on date: Date, calendar: Calendar) -> Bool {
        guard let activeMonths else { return true }
        return activeMonths.contains(calendar.component(.month, from: date))
    }
}

private enum WidgetQuoteStore {
    static var quotes: [WidgetQuote] {
        WiseishCatalogStore.currentCatalog().quotes.map {
            WidgetQuote(
                id: $0.id,
                mood: $0.mood,
                text: $0.text,
                theme: $0.theme,
                tags: $0.tags,
                activeMonths: $0.activeMonths
            )
        }
    }

    static func quote(for date: Date, calendar: Calendar = .current) -> WidgetQuote {
        if let displayed = recentlyDisplayedQuote(for: date, calendar: calendar) {
            return displayed
        }
        if let generated = generatedQuote(for: date, calendar: calendar) {
            return generated
        }

        let mood = WiseishContextStore.recommendedMood(date: date)
        let active = quotes.filter { $0.isActive(on: date, calendar: calendar) }
        let matchingMood = active.filter { $0.mood == mood }
        let candidates = matchingMood.isEmpty ? active : matchingMood
        let index = WiseishContextStore.preferredIndex(
            candidateIDs: candidates.map(\.id),
            candidateTags: Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.tags) }),
            date: date
        )
        return candidates[index % candidates.count]
    }

    private static func recentlyDisplayedQuote(for date: Date, calendar: Calendar) -> WidgetQuote? {
        guard let record = WiseishContextStore.quoteHistory().first(where: {
            calendar.isDate($0.shownAt, inSameDayAs: date)
        }) else {
            return nil
        }
        return WidgetQuote(
            id: record.quoteID,
            mood: WiseishContextStore.recommendedMood(date: date),
            text: record.text,
            theme: record.theme,
            tags: ["daily"],
            activeMonths: nil
        )
    }

    static func contextReason(for date: Date, calendar: Calendar = .current) -> String? {
        if let generated = WiseishContextStore.recentGeneratedQuote(now: date),
           calendar.isDate(generated.createdAt, inSameDayAs: date) {
            return generated.contextReason
        }
        let context = WiseishContextStore.recentExternalContext(now: date)
        let todayRecord = WiseishContextStore.quoteHistory().first {
            calendar.isDate($0.shownAt, inSameDayAs: date)
        }
        if let todayRecord, let context, context.createdAt >= todayRecord.shownAt {
            return nil
        }
        return context?.reason
    }

    private static func generatedQuote(for date: Date, calendar: Calendar) -> WidgetQuote? {
        guard let generated = WiseishContextStore.recentGeneratedQuote(now: date),
              calendar.isDate(generated.createdAt, inSameDayAs: date) else {
            return nil
        }
        return WidgetQuote(
            id: generated.catalogID,
            mood: WiseishContextStore.recommendedMood(date: date),
            text: generated.text,
            theme: generated.theme,
            tags: generated.tags,
            activeMonths: nil
        )
    }
}

private struct WiseishEntry: TimelineEntry {
    let date: Date
    let quote: WidgetQuote
    let contextReason: String?
}

private struct WiseishProvider: TimelineProvider {
    func placeholder(in context: Context) -> WiseishEntry {
        WiseishEntry(date: .now, quote: WidgetQuoteStore.quotes[0], contextReason: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WiseishEntry) -> Void) {
        completion(WiseishEntry(
            date: .now,
            quote: WidgetQuoteStore.quote(for: .now),
            contextReason: WidgetQuoteStore.contextReason(for: .now)
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WiseishEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        let entry = WiseishEntry(
            date: now,
            quote: WidgetQuoteStore.quote(for: now, calendar: calendar),
            contextReason: WidgetQuoteStore.contextReason(for: now, calendar: calendar)
        )
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

private struct WiseishWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WiseishEntry

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            default:
                smallWidget
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ink)
        .containerBackground(for: .widget) {
            paper
        }
    }

    private var smallWidget: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                brandAndDate

                Text(entry.quote.text)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineSpacing(2)
                    .lineLimit(4)
                    .minimumScaleFactor(0.64)
                    .allowsTightening(true)
                    .layoutPriority(2)
                    .padding(.top, 9)

                Spacer(minLength: 5)

                Text("# \(entry.quote.theme)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(softInk)
                    .lineLimit(1)
                    .padding(.trailing, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Image("IshWidget")
                .resizable()
                .scaledToFit()
                .frame(width: 37, height: 41)
                .accessibilityHidden(true)
        }
        .padding(13)
    }

    private var mediumWidget: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                brandAndDate

                if let reason = entry.contextReason {
                    Text("あなた向け · \(reason)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(mustard)
                        .lineLimit(1)
                        .padding(.top, 4)
                }

                Spacer(minLength: 8)

                Text(entry.quote.text)
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .lineSpacing(5)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .layoutPriority(2)

                Spacer(minLength: 6)

                Text("# \(entry.quote.theme)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(softInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image("IshWidget")
                .resizable()
                .scaledToFit()
                .frame(width: 93)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var brandAndDate: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 0) {
                Text("Wise")
                Text("–").foregroundStyle(mustard)
                Text("ish")
            }
            .font(.system(size: 11, weight: .bold, design: .serif))

            Spacer()

            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(softInk)
        }
    }
}

private struct WiseishWidget: Widget {
    let kind = "WiseishDailyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WiseishProvider()) { entry in
            WiseishWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の Wise-ish")
        .description("今日の哲学っぽい迷言を、Ishと一緒に表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct WiseishWidgetBundle: WidgetBundle {
    var body: some Widget {
        WiseishWidget()
    }
}
