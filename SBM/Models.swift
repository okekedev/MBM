import Foundation
import SwiftData

// MARK: - Daily Entry
// Tracks your daily profit, expenses, hours worked, and notes

@Model
final class DailyEntry {
    var date: Date = Date()
    var profit: Double = 0
    var expenses: Double = 0
    var hours: Double = 0
    var voiceNoteText: String?
    var isCompleted: Bool = false

    init(date: Date = Date(), profit: Double = 0, expenses: Double = 0, hours: Double = 0, voiceNoteText: String? = nil, isCompleted: Bool = false) {
        self.date = date
        self.profit = profit
        self.expenses = expenses
        self.hours = hours
        self.voiceNoteText = voiceNoteText
        self.isCompleted = isCompleted
    }

    var netProfit: Double {
        profit - expenses
    }

    var hourlyRate: Double {
        guard hours > 0 else { return 0 }
        return netProfit / hours
    }
}

// MARK: - Customer
// A customer with their service info and schedule

@Model
final class Customer {
    var id: UUID = UUID()
    var name: String = ""
    var phone: String?
    var address: String?
    var serviceName: String = ""
    var servicePrice: Double = 0
    var recurrenceRuleRaw: String = RecurrenceRule.none.rawValue
    var recurrenceDay: Int?
    var createdDate: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ScheduledJob.customer)
    var jobs: [ScheduledJob]?

    @Transient var recurrenceRule: RecurrenceRule {
        get { RecurrenceRule(rawValue: recurrenceRuleRaw) ?? .none }
        set { recurrenceRuleRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        phone: String? = nil,
        address: String? = nil,
        serviceName: String = "",
        servicePrice: Double = 0,
        recurrenceRule: RecurrenceRule = .none,
        recurrenceDay: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.address = address
        self.serviceName = serviceName
        self.servicePrice = servicePrice
        self.recurrenceRuleRaw = recurrenceRule.rawValue
        self.recurrenceDay = recurrenceDay
        self.createdDate = Date()
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Scheduled Job
// A job scheduled for a specific date

@Model
final class ScheduledJob {
    var id: UUID = UUID()
    var date: Date = Date()
    var statusRaw: String = JobStatus.scheduled.rawValue
    var notes: String?
    var completedDate: Date?

    var customer: Customer?

    @Transient var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    init(date: Date = Date(), customer: Customer? = nil, status: JobStatus = .scheduled) {
        self.id = UUID()
        self.date = date
        self.customer = customer
        self.statusRaw = status.rawValue
    }
}

// MARK: - Recurrence Rule
// How often a customer's job repeats

enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none = "One-time"
    case daily = "Daily"
    case everyOtherDay = "Every Other Day"
    case every3Days = "Every 3 Days"
    case weekly = "Weekly"
    case biWeekly = "Every Other Week"
    case monthly = "Monthly"
    case biMonthly = "Every Other Month"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .none: return "Once"
        case .daily: return "Daily"
        case .everyOtherDay: return "2 Days"
        case .every3Days: return "3 Days"
        case .weekly: return "Week"
        case .biWeekly: return "2 Weeks"
        case .monthly: return "Month"
        case .biMonthly: return "2 Months"
        }
    }
}

// MARK: - Job Status

enum JobStatus: String, Codable {
    case scheduled
    case completed
    case cancelled
    case rescheduled
}
