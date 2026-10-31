import Foundation

/// How often a credit renews.
enum Cadence: String, CaseIterable, Identifiable, Codable {
    case monthly
    case quarterly
    case semiannual
    case annual
    case once

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiannual: "Twice a year"
        case .annual: "Yearly"
        case .once: "One time"
        }
    }

    private var monthsPerPeriod: Int? {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .semiannual: 6
        case .annual: 12
        case .once: nil
        }
    }

    /// "a month", "a quarter", "every 6 months", "a year"
    var perPeriodText: String {
        switch self {
        case .monthly: "a month"
        case .quarterly: "a quarter"
        case .semiannual: "every 6 months"
        case .annual: "a year"
        case .once: "in total"
        }
    }

    /// "monthly", "each quarter", "every 6 months", "each year"
    var resetText: String {
        switch self {
        case .monthly: "monthly"
        case .quarterly: "each quarter"
        case .semiannual: "every 6 months"
        case .annual: "each year"
        case .once: "never"
        }
    }

    /// A stable key for the period containing `date`, e.g. "2026-10", "2026-Q4", "2026-H2", "2026".
    /// One-time credits record the year they were used: "once-2026".
    func periodKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = parts.year ?? 2000
        let month = parts.month ?? 1
        switch self {
        case .monthly: return String(format: "%04d-%02d", year, month)
        case .quarterly: return "\(year)-Q\((month - 1) / 3 + 1)"
        case .semiannual: return "\(year)-H\(month <= 6 ? 1 : 2)"
        case .annual: return "\(year)"
        case .once: return "once-\(year)"
        }
    }

    /// The first day of the period a key names: "2026-03", "2026-Q1", "2026-H2", "2026" or "once-2026".
    /// Nil for keys without a date, like the plain "once" saved by earlier versions.
    static func startDate(ofKey key: String, calendar: Calendar = .current) -> Date? {
        let text = key.hasPrefix("once-") ? key.dropFirst(5) : Substring(key)
        let parts = text.split(separator: "-")
        guard let first = parts.first, let year = Int(first) else { return nil }
        var month = 1
        if parts.count > 1 {
            let part = parts[1]
            if part.hasPrefix("Q"), let quarter = Int(part.dropFirst()) {
                month = (quarter - 1) * 3 + 1
            } else if part.hasPrefix("H"), let half = Int(part.dropFirst()) {
                month = (half - 1) * 6 + 1
            } else if let number = Int(part) {
                month = number
            } else {
                return nil
            }
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    /// Re-keys used periods for this cadence so history survives a schedule change:
    /// uses in January or March become Q1, a used Q1 becomes January.
    /// Keys without a date are placed at `fallback`.
    func convert(_ keys: [String], fallback: Date, calendar: Calendar = .current) -> [String] {
        var converted: [String] = []
        for key in keys {
            let date = Cadence.startDate(ofKey: key, calendar: calendar) ?? fallback
            let newKey = periodKey(for: date, calendar: calendar)
            if !converted.contains(newKey) { converted.append(newKey) }
        }
        return converted
    }

    /// First day of the period containing `date`.
    func periodStart(for date: Date, calendar: Calendar = .current) -> Date? {
        guard let months = monthsPerPeriod else { return nil }
        let parts = calendar.dateComponents([.year, .month], from: date)
        let month = parts.month ?? 1
        let startMonth = ((month - 1) / months) * months + 1
        return calendar.date(from: DateComponents(year: parts.year, month: startMonth, day: 1))
    }

    /// The day this credit next resets, or nil for one-time credits.
    func nextReset(after date: Date, calendar: Calendar = .current) -> Date? {
        guard let months = monthsPerPeriod, let start = periodStart(for: date, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .month, value: months, to: start)
    }

    /// Every period in `year`, in order: 12 months, 4 quarters, 2 halves or the whole year.
    /// A one-time credit has a single period covering the year.
    func periods(inYear year: Int, calendar: Calendar = .current) -> [CreditPeriod] {
        guard let months = monthsPerPeriod else {
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let end = calendar.date(byAdding: .year, value: 1, to: start)
            else { return [] }
            return [CreditPeriod(key: periodKey(for: start, calendar: calendar), label: "One time", start: start, end: end)]
        }
        return stride(from: 1, through: 12, by: months).compactMap { month in
            guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let end = calendar.date(byAdding: .month, value: months, to: start)
            else { return nil }
            return CreditPeriod(key: periodKey(for: start, calendar: calendar), label: shortLabel(for: start, calendar: calendar), start: start, end: end)
        }
    }

    /// A short label for the period containing `date`: "Mar", "Q2", "Jan – Jun", "2026".
    private func shortLabel(for date: Date, calendar: Calendar) -> String {
        switch self {
        case .monthly: date.formatted(.dateTime.month(.abbreviated))
        default: periodLabel(for: date, calendar: calendar)
        }
    }

    /// A human label for the current period: "November", "Q4", "Jul – Dec", "2026".
    func periodLabel(for date: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .monthly:
            return date.formatted(.dateTime.month(.wide))
        case .quarterly:
            let month = calendar.component(.month, from: date)
            return "Q\((month - 1) / 3 + 1)"
        case .semiannual:
            return calendar.component(.month, from: date) <= 6 ? "Jan – Jun" : "Jul – Dec"
        case .annual:
            return String(calendar.component(.year, from: date))
        case .once:
            return "One time"
        }
    }
}

/// One renewal period of a credit, such as March or Q2 of a year.
struct CreditPeriod: Identifiable, Hashable {
    /// Same format as `Cadence.periodKey(for:)`, so it matches what the Credits tab records.
    let key: String
    let label: String
    let start: Date
    /// The first moment of the next period.
    let end: Date

    var id: String { key }

    func hasStarted(by date: Date = .now) -> Bool { start <= date }
    func hasEnded(by date: Date = .now) -> Bool { end <= date }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }

    var monthKey: String { Cadence.monthly.periodKey(for: self) }

    func addingMonths(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: value, to: self) ?? self
    }

    /// The date of `day` within this date's month, clamped to the month's length (31 → Feb 28).
    func day(_ day: Int) -> Date {
        let calendar = Calendar.current
        let start = startOfMonth
        let length = calendar.range(of: .day, in: .month, for: start)?.count ?? 28
        let clamped = min(max(day, 1), length)
        return calendar.date(byAdding: .day, value: clamped - 1, to: start) ?? start
    }

    /// Whole calendar days from today to this date (negative if in the past).
    var daysFromToday: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: self)).day ?? 0
    }
}
