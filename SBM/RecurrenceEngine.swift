import Foundation
import SwiftData

class RecurrenceEngine {
    static let shared = RecurrenceEngine()

    func generateDailyJobs(modelContext: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<Customer>()
        guard let customers = try? modelContext.fetch(descriptor) else { return }

        for customer in customers {
            guard customer.recurrenceRule != .none else { continue }

            if shouldGenerateJob(for: customer, on: today, context: modelContext) {
                let newJob = ScheduledJob(date: today, customer: customer)
                modelContext.insert(newJob)
            }
        }

        try? modelContext.save()
    }

    private func shouldGenerateJob(for customer: Customer, on date: Date, context: ModelContext) -> Bool {
        // Check if job already exists for this date
        let jobs = customer.jobs ?? []
        let exists = jobs.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if exists { return false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: customer.createdDate)
        let target = calendar.startOfDay(for: date)

        // Don't schedule before creation
        if target < start { return false }

        let components = calendar.dateComponents([.day], from: start, to: target)
        guard let daysSinceCreation = components.day else { return false }

        switch customer.recurrenceRule {
        case .none:
            return false

        case .daily:
            return true

        case .everyOtherDay:
            return daysSinceCreation % 2 == 0

        case .every3Days:
            return daysSinceCreation % 3 == 0

        case .weekly:
            if let targetDay = customer.recurrenceDay {
                let currentWeekday = calendar.component(.weekday, from: target)
                return currentWeekday == targetDay
            }
            return daysSinceCreation % 7 == 0

        case .biWeekly:
            if let targetDay = customer.recurrenceDay {
                let currentWeekday = calendar.component(.weekday, from: target)
                if currentWeekday != targetDay { return false }
                // Check if it's an even week since creation
                let weeksSinceCreation = daysSinceCreation / 7
                return weeksSinceCreation % 2 == 0
            }
            return daysSinceCreation % 14 == 0

        case .monthly:
            if let targetDay = customer.recurrenceDay {
                let currentDay = calendar.component(.day, from: target)
                return currentDay == targetDay
            }
            let startDay = calendar.component(.day, from: start)
            let targetDayOfMonth = calendar.component(.day, from: target)
            return startDay == targetDayOfMonth

        case .biMonthly:
            if let targetDay = customer.recurrenceDay {
                let currentDay = calendar.component(.day, from: target)
                if currentDay != targetDay { return false }
                // Check if it's an even month since creation
                let monthsSinceCreation = calendar.dateComponents([.month], from: start, to: target).month ?? 0
                return monthsSinceCreation % 2 == 0
            }
            let startDay = calendar.component(.day, from: start)
            let targetDayOfMonth = calendar.component(.day, from: target)
            if startDay != targetDayOfMonth { return false }
            let monthsSinceCreation = calendar.dateComponents([.month], from: start, to: target).month ?? 0
            return monthsSinceCreation % 2 == 0
        }
    }
}
