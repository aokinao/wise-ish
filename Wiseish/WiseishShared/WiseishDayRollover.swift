import Foundation

enum WiseishDayRollover {
    static let contentReplacementStep = 11

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return [components.era, components.year, components.month, components.day]
            .map { String($0 ?? 0) }
            .joined(separator: "-")
    }

    static func nextStartOfDay(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(86_400)
    }

    static func widgetTimelineDates(
        from date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        [date, nextStartOfDay(after: date, calendar: calendar)]
    }

    static func pageTurnProgress(for step: Int) -> Double {
        min(max(Double(step - 2) / 9, 0), 1)
    }

    static func pageTurnOpacity(for step: Int) -> Double {
        let progress = pageTurnProgress(for: step)
        let fadeStart = 0.72
        guard progress > fadeStart else { return 1 }
        return max((1 - progress) / (1 - fadeStart), 0)
    }
}
