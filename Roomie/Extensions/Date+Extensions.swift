import Foundation

extension Date {

    /// "2024-03" → used as Firestore month key
    var monthKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: self)
    }

    /// The Monday at 00:00:00 of the week containing this date
    var startOfWeek: Date {
        Calendar.current.startOfWeek(for: self)
    }

    /// Friendly relative time string: "2 hours ago", "Yesterday", "Mar 14"
    var timeAgoDisplay: String {
        let now = Date()
        let diff = now.timeIntervalSince(self)

        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 172800 { return "Yesterday" }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: self)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        var components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Monday
        return self.date(from: components) ?? date
    }
}

extension String {
    /// "2024-03" → "March 2024"
    var formattedMonthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        guard let date = fmt.date(from: self) else { return self }
        let out = DateFormatter()
        out.dateFormat = "MMMM yyyy"
        return out.string(from: date)
    }
}
