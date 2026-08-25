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

    static func timelineDates(
        from date: Date,
        daysAhead: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard daysAhead > 0 else { return [date] }
        let futureDates = (1...daysAhead).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date))
        }
        return [date] + futureDates
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
