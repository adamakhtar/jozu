import Foundation

enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    case miss
    case partial
    case pass
    case easy

    var label: String {
        switch self {
        case .miss: return "Miss"
        case .partial: return "Partial"
        case .pass: return "Pass"
        case .easy: return "Easy"
        }
    }

    /// Coarse drip only. Not SM-2.
    var intervalDays: Int {
        switch self {
        case .miss: return 1
        case .partial: return 2
        case .pass: return 7
        case .easy: return 14
        }
    }
}

struct ReviewJudgment: Sendable {
    var grade: ReviewGrade
    var reason: String
    var nextHint: String
}

enum ReviewScheduler {
    static func apply(
        grade: ReviewGrade,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (intervalDays: Int, nextReviewAt: Date) {
        let days = grade.intervalDays
        let next = calendar.date(byAdding: .day, value: days, to: now)
            ?? now.addingTimeInterval(TimeInterval(days * 86_400))
        return (days, next)
    }
}
