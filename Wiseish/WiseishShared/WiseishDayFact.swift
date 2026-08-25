import Foundation

struct WiseishDayFact: Equatable {
    let text: String
    let dayOfYear: Int
    let daysRemaining: Int
    let progress: String
    let progressValue: Double

    static func make(for date: Date, calendar: Calendar = .current) -> WiseishDayFact {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let total = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        let remaining = max(total - day, 0)

        let progressValue = Double(day) / Double(max(total, 1))
        let progress = progress(day: day, total: total)
        let text = switch day % 3 {
        case 0:
            "今年の\(day)日目"
        case 1:
            "今年はあと\(remaining)日"
        default:
            "今年は\(progress)%ほど進んだ"
        }
        return WiseishDayFact(
            text: text,
            dayOfYear: day,
            daysRemaining: remaining,
            progress: progress,
            progressValue: progressValue
        )
    }

    private static func progress(day: Int, total: Int) -> String {
        let value = Double(day) / Double(max(total, 1)) * 100
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}
