import Foundation

enum SkyCalendarError: LocalizedError {
    case changedFormat(String)
    case unavailable(String)
    var errorDescription: String? {
        switch self {
        case .changedFormat(let source):
            return "\(source) returned an unexpected format. Its alerts were skipped."
        case .unavailable(let source): return "Unable to update \(source). Please try again later."
        }
    }
}
