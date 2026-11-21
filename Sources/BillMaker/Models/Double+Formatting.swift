import Foundation

public extension Double {
    var cleanFormatted: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.2f", self)
        }
    }
}
