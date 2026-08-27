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
        // Widgetの初回Timeline生成ではApp Groupのキャッシュを読まない。
        // cfprefsdや共有コンテナの復旧待ちでWidgetがLoadingのままになることがあるため、
        // まずは拡張自身に同梱されたCatalogだけで必ず描画できるようにする。
        guard let catalog = WiseishCatalogStore.bundledCatalog(bundle: .main) else {
            return []
        }
        return catalog.quotes.map {
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
        if let shared = WiseishContextStore.widgetQuote(for: date) {
            return WidgetQuote(
                id: shared.quoteID,
                mood: "daily",
                text: shared.text,
                theme: shared.theme,
                tags: ["daily"],
                activeMonths: nil
            )
        }
        let active = quotes.filter { $0.isActive(on: date, calendar: calendar) }
        guard !active.isEmpty else {
            // 季節限定データや一時的なCatalog更新で候補が空になっても、
            // Widget全体を落とさず、最低限の一言を表示する。
            return WidgetQuote(
                id: "widget-fallback",
                mood: "quiet",
                text: "今日は、今日として置いておく。\nそれ以上は、また明日でよい。",
                theme: "今日について",
                tags: ["daily"],
                activeMonths: nil
            )
        }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return active[abs(day) % active.count]
    }
}

private struct WiseishEntry: TimelineEntry {
    let date: Date
    let quote: WidgetQuote
}

private struct WiseishProvider: TimelineProvider {
    func placeholder(in context: Context) -> WiseishEntry {
        WiseishEntry(date: .now, quote: WidgetQuoteStore.quote(for: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (WiseishEntry) -> Void) {
        completion(WiseishEntry(
            date: .now,
            quote: WidgetQuoteStore.quote(for: .now)
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WiseishEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let dates = WiseishDayRollover.timelineDates(from: now, daysAhead: 7, calendar: calendar)
        let entries = dates.map { date in
            WiseishEntry(
                date: date,
                quote: WidgetQuoteStore.quote(for: date, calendar: calendar)
            )
        }
        // 未来分のエントリを先に作っていても、WidgetKit が古いタイムラインを
        // 保持することがある。次の0時に必ず再取得させ、アプリと同じ日付を出す。
        let reloadDate = WiseishDayRollover.nextStartOfDay(after: now, calendar: calendar)
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
}

private struct WiseishWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entry: WiseishEntry

    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    private var paper: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.09)
            : Color(red: 0.96, green: 0.92, blue: 0.85)
    }

    private var lightPaper: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.15, blue: 0.13)
            : Color(red: 1.00, green: 0.98, blue: 0.94)
    }

    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.91, green: 0.89, blue: 0.84)
            : Color(red: 0.16, green: 0.15, blue: 0.13)
    }

    private var softInk: Color {
        colorScheme == .dark
            ? Color(red: 0.66, green: 0.63, blue: 0.58)
            : Color(red: 0.44, green: 0.41, blue: 0.37)
    }

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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                compactDate

                Spacer(minLength: 4)

                brand
                    .padding(.top, 3)
            }

            Rectangle()
                .fill(ink.opacity(0.16))
                .frame(height: 1)
                .padding(.vertical, 8)

            Text(entry.quote.text)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            Text(entry.quote.theme)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(softInk)
                .lineLimit(1)
                .padding(.trailing, 34)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            animatedIsh(width: 36)
                .padding(.trailing, 8)
                .padding(.bottom, 5)
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            calendarPage

            VStack(alignment: .leading, spacing: 0) {
                brand

                let metric = WiseishDailyMetric.make(for: entry.date)
                Text("\(metric.value) · \(metric.title)")
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .foregroundStyle(softInk)
                    .lineLimit(1)
                    .padding(.top, 4)

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

            animatedIsh(width: 72)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactDate: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(dayNumber)
                .font(.system(size: 31, weight: .bold, design: .serif))
            VStack(alignment: .leading, spacing: 0) {
                Text(monthLabel)
                Text(entry.date, format: .dateTime.weekday(.abbreviated))
            }
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(softInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var calendarPage: some View {
        VStack(spacing: 1) {
            Text(monthLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(softInk)

            Text(dayNumber)
                .font(.system(size: 42, weight: .bold, design: .serif))
                .minimumScaleFactor(0.8)

            Text(entry.date, format: .dateTime.weekday(.wide))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(softInk)
        }
        .frame(width: 64, height: 94)
        .background(lightPaper.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ink.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var brand: some View {
        HStack(spacing: 0) {
            Text("Wise")
            Text("–").foregroundStyle(mustard)
            Text("ish")
        }
        .font(.system(size: 11, weight: .bold, design: .serif))
    }

    private func animatedIsh(width: CGFloat) -> some View {
        Image("IshWidget")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .id("ish-\(dayKey)")
            .transition(ishTransition)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.18)
                    : .easeInOut(duration: 2.0),
                value: dayKey
            )
            .accessibilityHidden(true)
    }

    private var ishTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(
                active: WidgetIshRolloverModifier(progress: 0),
                identity: WidgetIshRolloverModifier(progress: 1)
            ),
            removal: .opacity
        )
    }

    private var dayKey: String {
        WiseishDayRollover.dayKey(for: entry.date)
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: entry.date))
    }

    private var monthLabel: String {
        "\(Calendar.current.component(.month, from: entry.date))月"
    }
}

private struct WidgetIshRolloverModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let remaining = 1 - progress
        let shake = sin(progress * .pi * 6) * remaining
        let hop = sin(progress * .pi) * remaining

        content
            .scaleEffect(0.78 + (0.22 * progress) + (hop * 0.12), anchor: .bottom)
            .offset(x: shake * 16, y: -hop * 18)
            .rotationEffect(.degrees(shake * 18), anchor: .bottom)
    }
}

private struct WiseishWidget: Widget {
    let kind = "WiseishDailyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WiseishProvider()) { entry in
            WiseishWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の Wise-ish")
        .description("日付と、Ishの役に立たない哲学を置いておきます。")
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
