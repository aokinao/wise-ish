import SwiftUI
import WidgetKit

private struct WidgetQuote {
    let text: String
    let theme: String
    let tags: [String]
}

private enum WidgetQuoteStore {
    static var quotes: [WidgetQuote] {
        WiseishCatalogStore.currentCatalog().quotes.map {
            WidgetQuote(text: $0.text, theme: $0.theme, tags: $0.tags)
        }
    }

    static func quote(for date: Date, calendar: Calendar = .current) -> WidgetQuote {
        if let displayed = recentlyDisplayedQuote(for: date, calendar: calendar) {
            return displayed
        }
        if let generated = generatedQuote(for: date, calendar: calendar) {
            return generated
        }

        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        guard let context = WiseishContextStore.recentExternalContext(now: date) else {
            return quotes[day % quotes.count]
        }
        return quotes.enumerated().max { lhs, rhs in
            let lhsScore = Set(lhs.element.tags).intersection(context.tags).count * 10 + ((day + lhs.offset) % quotes.count)
            let rhsScore = Set(rhs.element.tags).intersection(context.tags).count * 10 + ((day + rhs.offset) % quotes.count)
            return lhsScore < rhsScore
        }?.element ?? quotes[day % quotes.count]
    }

    private static func recentlyDisplayedQuote(for date: Date, calendar: Calendar) -> WidgetQuote? {
        guard let record = WiseishContextStore.quoteHistory().first(where: {
            calendar.isDate($0.shownAt, inSameDayAs: date)
        }) else {
            return nil
        }
        return WidgetQuote(text: record.text, theme: record.theme, tags: ["daily"])
    }

    static func contextReason(for date: Date, calendar: Calendar = .current) -> String? {
        if let generated = WiseishContextStore.recentGeneratedQuote(now: date),
           calendar.isDate(generated.createdAt, inSameDayAs: date) {
            return generated.contextReason
        }
        return WiseishContextStore.recentExternalContext(now: date)?.reason
    }

    private static func generatedQuote(for date: Date, calendar: Calendar) -> WidgetQuote? {
        guard let generated = WiseishContextStore.recentGeneratedQuote(now: date),
              calendar.isDate(generated.createdAt, inSameDayAs: date) else {
            return nil
        }
        return WidgetQuote(
            text: generated.text,
            theme: generated.theme,
            tags: generated.tags
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
        .foregroundStyle(ink)
        .containerBackground(for: .widget) {
            paper
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandAndDate

            Text(entry.quote.text)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .lineSpacing(2)
                .lineLimit(4)
                .minimumScaleFactor(0.68)
                .allowsTightening(true)
                .layoutPriority(2)
                .padding(.top, 8)

            Spacer(minLength: 2)

            HStack(alignment: .bottom) {
                Text("# \(entry.quote.theme)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(softInk)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image("IshWidget")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 37)
                    .accessibilityHidden(true)
            }
        }
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
    }
}

@main
struct WiseishWidgetBundle: WidgetBundle {
    var body: some Widget {
        WiseishWidget()
    }
}
