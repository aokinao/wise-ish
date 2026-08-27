import Foundation

struct WiseishDailyMetric: Equatable {
    enum Kind: Equatable {
        case year
        case since2000
        case sinceBirth(name: String)
        case month
        case week
        case thoughtDepth
        case meaning
        case coincidence
        case elapsedTime
    }

    let kind: Kind
    let title: String
    let value: String
    let detail: String
    let progress: Double?

    static func make(for date: Date, calendar: Calendar = .current) -> WiseishDailyMetric {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        switch day % 9 {
        case 0:
            return yearMetric(for: date, calendar: calendar)
        case 1:
            return since2000Metric(for: date, calendar: calendar)
        case 2:
            return sinceBirthMetric(for: date, calendar: calendar)
        case 3:
            return monthMetric(for: date, calendar: calendar)
        case 4:
            return weekMetric(for: date, calendar: calendar)
        case 5:
            return thoughtDepthMetric(for: date, calendar: calendar)
        case 6:
            return meaningMetric(for: date, calendar: calendar)
        case 7:
            return coincidenceMetric(for: date, calendar: calendar)
        default:
            return elapsedTimeMetric(for: date, calendar: calendar)
        }
    }

    private static func yearMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let total = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        let remaining = max(total - day, 0)
        let ratio = Double(day) / Double(max(total, 1))
        return WiseishDailyMetric(
            kind: .year,
            title: "今年の進み具合（何の？）",
            value: "\(day)日目",
            detail: "あと\(remaining)日 / \(percentage(ratio))%経過",
            progress: ratio
        )
    }

    private static func since2000Metric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let start = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? date
        return WiseishDailyMetric(
            kind: .since2000,
            title: "2000年から",
            value: "\(days(from: start, to: date, calendar: calendar))日",
            detail: "基準日は、なんとなく2000年",
            progress: nil
        )
    }

    private static func sinceBirthMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        // 生年月日は固定値。意味はあるが、今日の生活にはたぶん関係ない。
        let birth = calendar.date(from: DateComponents(year: 1867, month: 2, day: 9)) ?? date
        return WiseishDailyMetric(
            kind: .sinceBirth(name: "夏目漱石"),
            title: "夏目漱石が生まれてから",
            value: "\(days(from: birth, to: date, calendar: calendar))日",
            detail: "その間に、わしは何度も昼寝をした",
            progress: nil
        )
    }

    private static func monthMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let day = calendar.component(.day, from: date)
        let total = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let ratio = Double(day) / Double(max(total, 1))
        return WiseishDailyMetric(
            kind: .month,
            title: "今月の進み具合（何の？）",
            value: "\(day)日目",
            detail: "あと\(max(total - day, 0))日 / \(percentage(ratio))%経過",
            progress: ratio
        )
    }

    private static func weekMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let weekday = calendar.component(.weekday, from: date)
        let firstWeekday = calendar.firstWeekday
        let position = ((weekday - firstWeekday + 7) % 7) + 1
        let ratio = Double(position) / 7.0
        return WiseishDailyMetric(
            kind: .week,
            title: "今週の位置",
            value: "(position)日目",
            detail: "あと(7 - position)日 / 週はまだ続く",
            progress: ratio
        )
    }

    private static func thoughtDepthMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        let depth = (day * 17) % 90 + 10
        return WiseishDailyMetric(
            kind: .thoughtDepth,
            title: "今日の思考の深さ",
            value: "(depth)cm",
            detail: "測った場所は、わしの頭の中じゃ",
            progress: nil
        )
    }

    private static func meaningMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        let meaning = (day * 37) % 101
        return WiseishDailyMetric(
            kind: .meaning,
            title: "今日の意味",
            value: "(meaning)%",
            detail: "残り(100 - meaning)%は、たぶん余白じゃ",
            progress: nil
        )
    }

    private static func coincidenceMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        let coincidences = (day * 13) % 8 + 1
        return WiseishDailyMetric(
            kind: .coincidence,
            title: "今日の偶然",
            value: "(coincidences)回",
            detail: "数えたことはないが、たぶんある",
            progress: nil
        )
    }

    private static func elapsedTimeMetric(for date: Date, calendar: Calendar) -> WiseishDailyMetric {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let reference = min(max(date, start), end)
        let elapsedMinutes = max(Int(reference.timeIntervalSince(start) / 60), 0)
        let hours = elapsedMinutes / 60
        let minutes = elapsedMinutes % 60
        let totalMinutes = max(Int(end.timeIntervalSince(start) / 60), 1)
        let ratio = min(max(Double(elapsedMinutes) / Double(totalMinutes), 0), 1)
        return WiseishDailyMetric(
            kind: .elapsedTime,
            title: "今日の経過",
            value: "(hours)時間(minutes)分",
            detail: "今日の時間は、もう戻らぬ。たぶん",
            progress: ratio
        )
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        max(calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0, 0)
    }

    private static func percentage(_ ratio: Double) -> String {
        ratio.formatted(.number.precision(.fractionLength(1)))
    }
}
