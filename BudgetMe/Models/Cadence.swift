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

    /// A stable key for the period containing `date`, e.g. "2026-10", "2026-Q4", "2026-H2", "2026".
    func periodKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = parts.year ?? 2000
        let month = parts.month ?? 1
        switch self {
        case .monthly: return String(format: "%04d-%02d", year, month)
        case .quarterly: return "\(year)-Q\((month - 1) / 3 + 1)"
        case .semiannual: return "\(year)-H\(month <= 6 ? 1 : 2)"
        case .annual: return "\(year)"
        case .once: return "once"
        }
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
