import Foundation

extension Double {
    var currencyFormatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = .current
        return fmt.string(from: NSNumber(value: self)) ?? "$\(String(format: "%.2f", self))"
    }
}
