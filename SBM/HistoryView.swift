import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    @State private var selectedPeriod: Period = .week
    @State private var selectedEntry: DailyEntry?

    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            case .all: return nil
            }
        }

        var icon: String {
            switch self {
            case .week: return "calendar"
            case .month: return "calendar.badge.clock"
            case .year: return "chart.line.uptrend.xyaxis"
            case .all: return "infinity"
            }
        }
    }

    private var filteredEntries: [DailyEntry] {
        guard let days = selectedPeriod.days else { return entries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    private var totalProfit: Double {
        filteredEntries.reduce(0) { $0 + $1.profit }
    }

    private var totalExpenses: Double {
        filteredEntries.reduce(0) { $0 + $1.expenses }
    }

    private var totalHours: Double {
        filteredEntries.reduce(0) { $0 + $1.hours }
    }

    private var netProfit: Double {
        totalProfit - totalExpenses
    }

    private var averageHourlyRate: Double {
        guard totalHours > 0 else { return 0 }
        return netProfit / totalHours
    }

    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        heroSummaryCard
                        periodSelector
                        statsGrid
                        entriesList
                    }
                    .padding()
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedEntry) { entry in
                EditEntrySheet(entry: entry)
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Hero Summary Card

    private var heroSummaryCard: some View {
        VStack(spacing: 16) {
            // Hourly Rate Ring
            ZStack {
                Circle()
                    .stroke(AppTheme.gray200, lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: min(averageHourlyRate / 100, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.purple, AppTheme.purpleLight, AppTheme.purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(formatCurrency(averageHourlyRate))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.purpleGradient)

                    Text("per hour")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: selectedPeriod.icon)
                    .font(.caption)
                Text("\(selectedPeriod.rawValue) Average")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selectedPeriod == period ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedPeriod == period
                                ? AnyView(AppTheme.purpleGradient)
                                : AnyView(AppTheme.gray100)
                        )
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            HistoryStatCard(
                title: "Net Profit",
                value: formatCurrency(netProfit),
                icon: "dollarsign.circle.fill",
                color: netProfit >= 0 ? AppTheme.green : AppTheme.red
            )

            HistoryStatCard(
                title: "Hours",
                value: String(format: "%.1f", totalHours),
                icon: "clock.fill",
                color: AppTheme.blue
            )

            HistoryStatCard(
                title: "Days",
                value: "\(filteredEntries.count)",
                icon: "calendar",
                color: AppTheme.purple
            )
        }
    }

    // MARK: - Entries List

    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredEntries.isEmpty {
                emptyState
            } else {
                Text("Recent Entries")
                    .font(.headline)
                    .foregroundColor(AppTheme.text)
                    .padding(.top, 8)

                ForEach(filteredEntries) { entry in
                    Button {
                        selectedEntry = entry
                    } label: {
                        HistoryEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.purple.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.purpleGradient)
            }

            Text("No entries yet")
                .font(.headline)
                .foregroundColor(AppTheme.text)

            Text("Log your daily profit, expenses, and hours to see your history here")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - History Stat Card

struct HistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(AppTheme.text)

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: DailyEntry

    private var isToday: Bool {
        Calendar.current.isDateInToday(entry.date)
    }

    private var dateText: String {
        if Calendar.current.isDateInToday(entry.date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(entry.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: entry.date)
        }
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: entry.date)
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.title2.weight(.bold))
                    .foregroundColor(isToday ? AppTheme.purple : AppTheme.text)

                Text(monthAbbrev)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(
                isToday
                    ? AnyView(AppTheme.purple.opacity(0.1))
                    : AnyView(AppTheme.gray100)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.text)

                    Spacer()

                    HStack(spacing: 2) {
                        Text(formatCurrency(entry.hourlyRate))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(entry.hourlyRate > 0 ? AppTheme.purpleGradient : AppTheme.grayGradient)

                        Text("/hr")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                HStack(spacing: 16) {
                    Label {
                        Text(formatCurrency(entry.netProfit))
                            .foregroundColor(entry.netProfit >= 0 ? AppTheme.green : AppTheme.red)
                    } icon: {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(entry.netProfit >= 0 ? AppTheme.green : AppTheme.red)
                    }

                    Label {
                        Text(String(format: "%.1fh", entry.hours))
                            .foregroundColor(AppTheme.textSecondary)
                    } icon: {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppTheme.blue)
                    }
                }
                .font(.caption)

                if let note = entry.voiceNoteText, !note.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                        Text(note)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
    }
}

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: DailyEntry

    @State private var profit: String = ""
    @State private var expenses: String = ""
    @State private var hours: String = ""
    @State private var notes: String = ""

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Date header
                        Text(dateString)
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)

                        // Input fields
                        VStack(spacing: 16) {
                            EditField(label: "Revenue", value: $profit, prefix: "$", color: AppTheme.green)
                            EditField(label: "Expenses", value: $expenses, prefix: "$", color: AppTheme.red)
                            EditField(label: "Hours", value: $hours, color: AppTheme.blue)
                        }
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppTheme.textSecondary)

                            TextField("What did you do?", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .padding()
                                .background(AppTheme.gray100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(AppTheme.text)
                        }
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.purple)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        profit = entry.profit > 0 ? String(format: "%.0f", entry.profit) : ""
        expenses = entry.expenses > 0 ? String(format: "%.0f", entry.expenses) : ""
        hours = entry.hours > 0 ? String(format: "%.1f", entry.hours) : ""
        notes = entry.voiceNoteText ?? ""
    }

    private func saveChanges() {
        entry.profit = Double(profit) ?? 0
        entry.expenses = Double(expenses) ?? 0
        entry.hours = Double(hours) ?? 0
        entry.voiceNoteText = notes.isEmpty ? nil : notes
        try? modelContext.save()
    }
}

struct EditField: View {
    let label: String
    @Binding var value: String
    var prefix: String = ""
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .foregroundColor(AppTheme.textMuted)
                }

                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(color)
                    .frame(width: 80)
            }
            .font(.headline)
        }
    }
}
