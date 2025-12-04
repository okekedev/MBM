import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dailyEntries: [DailyEntry]
    @Query(sort: \ScheduledJob.date) private var allJobs: [ScheduledJob]

    @State private var selectedDate = Date()
    @State private var profit: String = ""
    @State private var expenses: String = ""
    @State private var hours: String = ""
    @State private var notes: String = ""
    @State private var isDayCompleted: Bool = false
    @State private var showCompletionOverlay: Bool = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case profit, expenses, hours, notes
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var isYesterday: Bool {
        Calendar.current.isDateInYesterday(selectedDate)
    }

    private var canGoBack: Bool {
        isToday // Can only go back if viewing today
    }

    private var canGoForward: Bool {
        isYesterday // Can only go forward if viewing yesterday
    }

    private var dateLabel: String {
        if isToday {
            return "Business Today"
        } else if isYesterday {
            return "Business Yesterday"
        }
        return ""
    }

    private var selectedEntry: DailyEntry? {
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        return dailyEntries.first { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
    }

    private var selectedDayJobs: [ScheduledJob] {
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        return allJobs.filter {
            Calendar.current.isDate($0.date, inSameDayAs: dayStart) && $0.status == .scheduled
        }
    }

    private var completedSelectedDay: [ScheduledJob] {
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        return allJobs.filter {
            Calendar.current.isDate($0.date, inSameDayAs: dayStart) && $0.status == .completed
        }
    }

    private var profitValue: Double { Double(profit) ?? 0 }
    private var expensesValue: Double { Double(expenses) ?? 0 }
    private var hoursValue: Double { Double(hours) ?? 0 }
    private var netProfit: Double { profitValue - expensesValue }
    private var hourlyRate: Double {
        guard hoursValue > 0 else { return 0 }
        return netProfit / hoursValue
    }

    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        dateNavigation
                        rateCard

                        if isDayCompleted {
                            completedBanner
                        } else {
                            inputRow

                            if !selectedDayJobs.isEmpty || !completedSelectedDay.isEmpty {
                                jobsSection
                            }

                            notesSection
                            completeDayButton
                        }
                    }
                    .padding()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

                // Completion overlay
                if showCompletionOverlay {
                    completionOverlay
                }
            }
            .navigationBarHidden(true)
            .onAppear(perform: loadData)
            .onChange(of: selectedDate) { _, _ in
                loadData()
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == nil { saveEntry() }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundColor(AppTheme.purple)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Date Navigation Header

    private var dateNavigation: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(canGoBack ? AppTheme.purple : AppTheme.gray200)
            }
            .disabled(!canGoBack)

            Spacer()

            Text(dateLabel)
                .font(.title.weight(.bold))
                .foregroundColor(AppTheme.text)

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(canGoForward ? AppTheme.purple : AppTheme.gray200)
            }
            .disabled(!canGoForward)
        }
        .padding(.top, 8)
    }

    // MARK: - Rate Card

    private var rateCard: some View {
        VStack(spacing: 12) {
            Text(formatCurrency(hourlyRate))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(hourlyRate > 0 ? AppTheme.purpleGradient : AppTheme.grayGradient)

            Text("per hour")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 4) {
                Text(formatCurrency(netProfit))
                    .font(.headline)
                    .foregroundColor(netProfit >= 0 ? AppTheme.green : AppTheme.red)
                Text("net today")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 12) {
            InputTile(
                label: "Revenue",
                value: $profit,
                icon: "arrow.up",
                color: AppTheme.green,
                prefix: "$",
                isFocused: focusedField == .profit
            )
            .focused($focusedField, equals: .profit)

            InputTile(
                label: "Expenses",
                value: $expenses,
                icon: "arrow.down",
                color: AppTheme.red,
                prefix: "$",
                isFocused: focusedField == .expenses
            )
            .focused($focusedField, equals: .expenses)

            InputTile(
                label: "Hours",
                value: $hours,
                icon: "clock",
                color: AppTheme.blue,
                isFocused: focusedField == .hours
            )
            .focused($focusedField, equals: .hours)
        }
    }

    // MARK: - Jobs Section

    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isToday ? "Today's Jobs" : "Yesterday's Jobs")
                    .font(.headline)
                    .foregroundColor(AppTheme.text)

                Spacer()

                if !selectedDayJobs.isEmpty {
                    Text("\(selectedDayJobs.count) left")
                        .font(.caption)
                        .foregroundColor(AppTheme.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            ForEach(selectedDayJobs) { job in
                TodayJobRow(job: job) {
                    completeJob(job)
                }
            }

            ForEach(completedSelectedDay) { job in
                TodayCompletedRow(job: job)
            }
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(AppTheme.text)

            TextField(isToday ? "What did you do today?" : "What did you do yesterday?", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding()
                .background(AppTheme.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($focusedField, equals: .notes)
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Complete Day Button

    private var completeDayButton: some View {
        Button {
            saveEntry()
            withAnimation(.spring(response: 0.4)) {
                showCompletionOverlay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showCompletionOverlay = false
                    isDayCompleted = true
                    if let entry = selectedEntry {
                        entry.isCompleted = true
                        try? modelContext.save()
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Complete Day")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.purpleGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Completed Banner

    private var completedBanner: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.purpleGradient)

                Text("Day Completed")
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppTheme.text)

                Text(isToday ? "Come back tomorrow to log your next day" : "This day has been logged")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation {
                    isDayCompleted = false
                }
            } label: {
                Text("Edit Today")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.purple)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.purple.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.purple.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(AppTheme.purple)
                }

                Text("Day Completed!")
                    .font(.title.weight(.bold))
                    .foregroundColor(AppTheme.text)

                Text("Check back tomorrow to\ncomplete your next log")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppTheme.shadow, radius: 20, x: 0, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Helpers

    private func loadData() {
        if let entry = selectedEntry {
            profit = entry.profit > 0 ? String(format: "%.0f", entry.profit) : ""
            expenses = entry.expenses > 0 ? String(format: "%.0f", entry.expenses) : ""
            hours = entry.hours > 0 ? String(format: "%.1f", entry.hours) : ""
            notes = entry.voiceNoteText ?? ""
            isDayCompleted = entry.isCompleted
        } else {
            // Reset fields for new day
            profit = ""
            expenses = ""
            hours = ""
            notes = ""
            isDayCompleted = false
        }
    }

    private func saveEntry() {
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard profitValue > 0 || expensesValue > 0 || hoursValue > 0 || !note.isEmpty else { return }

        let dayStart = Calendar.current.startOfDay(for: selectedDate)

        if let existing = selectedEntry {
            existing.profit = profitValue
            existing.expenses = expensesValue
            existing.hours = hoursValue
            existing.voiceNoteText = note.isEmpty ? nil : note
        } else {
            let newEntry = DailyEntry(
                date: dayStart,
                profit: profitValue,
                expenses: expensesValue,
                hours: hoursValue,
                voiceNoteText: note.isEmpty ? nil : note
            )
            modelContext.insert(newEntry)
        }

        try? modelContext.save()
    }

    private func completeJob(_ job: ScheduledJob) {
        withAnimation {
            job.status = .completed
            job.completedDate = Date()

            if let price = job.customer?.servicePrice, price > 0 {
                let newProfit = profitValue + price
                profit = String(format: "%.0f", newProfit)
                saveEntry()
            }
        }
    }
}

// MARK: - Input Tile

struct InputTile: View {
    let label: String
    @Binding var value: String
    let icon: String
    let color: Color
    var prefix: String = ""
    var isFocused: Bool = false

    @FocusState private var textFieldFocused: Bool
    @State private var cursorVisible = true

    private var isEmpty: Bool {
        value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            ZStack {
                // Placeholder with blinking cursor (only when empty and not focused)
                if isEmpty && !isFocused && !textFieldFocused {
                    HStack(spacing: 1) {
                        if !prefix.isEmpty {
                            Text(prefix)
                                .foregroundColor(AppTheme.textMuted.opacity(0.5))
                        }
                        Text("0")
                            .foregroundColor(AppTheme.textMuted.opacity(0.5))
                        Rectangle()
                            .fill(color)
                            .frame(width: 2, height: 24)
                            .opacity(cursorVisible ? 1 : 0)
                    }
                }

                // Actual TextField - full width for easier tapping
                HStack(spacing: 1) {
                    if !prefix.isEmpty && !isEmpty {
                        Text(prefix)
                            .foregroundColor(AppTheme.text)
                    }
                    TextField("", text: $value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .foregroundColor(isEmpty ? .clear : AppTheme.text)
                        .focused($textFieldFocused)
                }
            }
            .font(.title2.weight(.bold))
            .frame(height: 30)

            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isFocused || textFieldFocused ? color.opacity(0.08) : AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                textFieldFocused = true
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused || textFieldFocused ? color : AppTheme.gray200, lineWidth: isFocused || textFieldFocused ? 2 : 1)
        )
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
        .onAppear {
            startBlinking()
        }
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                cursorVisible.toggle()
            }
        }
    }
}

// MARK: - Today Job Row

struct TodayJobRow: View {
    let job: ScheduledJob
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundColor(AppTheme.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(job.customer?.name ?? "Customer")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.text)

                if let service = job.customer?.serviceName, !service.isEmpty {
                    Text(service)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            if let price = job.customer?.servicePrice, price > 0 {
                Text("$\(Int(price))")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AppTheme.green)
            }
        }
        .padding(12)
        .background(AppTheme.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Today Completed Row

struct TodayCompletedRow: View {
    let job: ScheduledJob

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(AppTheme.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.customer?.name ?? "Customer")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
                    .strikethrough()

                if let service = job.customer?.serviceName, !service.isEmpty {
                    Text(service)
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            Spacer()

            if let price = job.customer?.servicePrice, price > 0 {
                Text("$\(Int(price))")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(12)
        .background(AppTheme.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
