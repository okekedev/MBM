import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var jobs: [ScheduledJob]
    @Query private var customers: [Customer]
    @Query private var dailyEntries: [DailyEntry]

    @State private var selectedDate = Date()
    @State private var showingAddJob = false
    @State private var currentMonth = Date()

    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        // Month navigation
                        monthNavigation
                            .padding(.horizontal)

                        // Weekday headers
                        weekdayHeaders
                            .padding(.horizontal)

                        // Calendar grid
                        calendarGrid
                            .padding(.horizontal)

                        // Selected day section
                        selectedDaySection
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") {
                        withAnimation {
                            selectedDate = Date()
                            currentMonth = Date()
                        }
                    }
                    .foregroundColor(AppTheme.purple)
                }
            }
            .sheet(isPresented: $showingAddJob) {
                AddJobSheet(selectedDate: selectedDate, customers: Array(customers))
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.purple)
            }

            Spacer()

            Text(monthYearLabel)
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.text)

            Spacer()

            Button {
                withAnimation {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.purple)
            }
        }
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        return HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    CalendarDayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDateInToday(date),
                        jobCount: jobsFor(date: date).count,
                        netProfit: netProfitFor(date: date)
                    ) {
                        selectedDate = date
                        showingAddJob = true
                    } onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 56)
                }
            }
        }
    }

    // MARK: - Selected Day Section

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayLabel)
                        .font(.title3.weight(.bold))
                        .foregroundColor(AppTheme.text)
                    Text(fullDateLabel)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    showingAddJob = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.purpleGradient)
                }
            }

            // Jobs list
            let dayJobs = jobsFor(date: selectedDate)

            if dayJobs.isEmpty {
                emptyDayState
            } else {
                ForEach(dayJobs) { job in
                    JobCard(job: job, onComplete: { completeJob(job) })
                }
            }
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 2)
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: selectedDate)
        }
    }

    private var fullDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Empty State

    private var emptyDayState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textMuted)

            Text("No jobs scheduled")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Helpers

    private func jobsFor(date: Date) -> [ScheduledJob] {
        jobs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.status == .scheduled }
            .sorted { $0.date < $1.date }
    }

    private func netProfitFor(date: Date) -> Double? {
        guard let entry = dailyEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        return entry.netProfit
    }

    private func completeJob(_ job: ScheduledJob) {
        job.status = .completed
        job.completedDate = Date()
        try? modelContext.save()
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current

        // Get first day of month
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }

        // Get number of days in month
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        let numDays = range.count

        // Get weekday of first day (0 = Sunday)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1

        // Build array with leading nils for offset
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in 1...numDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let jobCount: Int
    let netProfit: Double?
    let onAddJob: () -> Void
    let onTap: () -> Void

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var profitColor: Color? {
        guard let profit = netProfit else { return nil }
        if profit > 0 { return AppTheme.green }
        if profit < 0 { return AppTheme.red }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.body.weight(isToday || isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : (isToday ? AppTheme.purple : AppTheme.text))

                // Job indicators
                if jobCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(jobCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? Color.white : AppTheme.purple)
                                .frame(width: 5, height: 5)
                        }
                        if jobCount > 3 {
                            Text("+")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(isSelected ? .white : AppTheme.purple)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday && !isSelected ? AppTheme.purple : Color.clear, lineWidth: 2)
            )
        }
        .contextMenu {
            Button {
                onAddJob()
            } label: {
                Label("Add Job", systemImage: "plus")
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.purple
        }
        if let color = profitColor {
            return color.opacity(0.2)
        }
        return AppTheme.card
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: ScheduledJob
    let onComplete: () -> Void

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: job.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.customer?.name ?? "Unknown Customer")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)

                    if let service = job.customer?.serviceName, !service.isEmpty {
                        Text(service)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeString)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.text)

                    if let price = job.customer?.servicePrice, price > 0 {
                        Text("$\(Int(price))")
                            .font(.headline)
                            .foregroundColor(AppTheme.green)
                    }
                }
            }

            Divider()
                .background(AppTheme.gray200)

            // Actions
            HStack(spacing: 12) {
                // Complete button
                Button {
                    onComplete()
                } label: {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.green.opacity(0.15))
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }

                // Contact button
                if let phone = job.customer?.phone, !phone.isEmpty {
                    Button {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.blue)
                            .frame(width: 44, height: 36)
                            .background(AppTheme.blue.opacity(0.15))
                            .cornerRadius(AppTheme.cornerRadiusSmall)
                    }

                    Button {
                        if let url = URL(string: "sms:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.teal)
                            .frame(width: 44, height: 36)
                            .background(AppTheme.teal.opacity(0.15))
                            .cornerRadius(AppTheme.cornerRadiusSmall)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
    }
}

// MARK: - Add Job Sheet

struct AddJobSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date
    let customers: [Customer]

    enum Mode {
        case selectCustomer
        case newCustomer
    }

    @State private var mode: Mode = .selectCustomer
    @State private var selectedCustomer: Customer?
    @State private var jobTime = Date()
    @State private var notes = ""

    // New customer fields
    @State private var newName = ""
    @State private var newPhone = ""
    @State private var newAddress = ""
    @State private var newPrice = ""
    @State private var recurrence: RecurrenceRule = .none
    @State private var recurrenceDay: Int = 1
    @State private var showContactDetails = false

    private var canSave: Bool {
        if mode == .newCustomer {
            return !newName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return selectedCustomer != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Mode toggle
                        modePicker

                        if mode == .selectCustomer {
                            customerPicker
                        } else {
                            newCustomerForm
                        }

                        // Date & Time
                        dateTimePicker

                        // Notes
                        notesField
                    }
                    .padding()
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { addJob() }
                        .font(.headline)
                        .foregroundColor(canSave ? AppTheme.green : AppTheme.textMuted)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            jobTime = selectedDate
            if customers.isEmpty {
                mode = .newCustomer
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 12) {
            ModeButton(
                title: "Existing",
                icon: "person.fill",
                isSelected: mode == .selectCustomer,
                disabled: customers.isEmpty
            ) {
                withAnimation { mode = .selectCustomer }
            }

            ModeButton(
                title: "New",
                icon: "person.badge.plus",
                isSelected: mode == .newCustomer,
                disabled: false
            ) {
                withAnimation { mode = .newCustomer }
            }
        }
    }

    // MARK: - Customer Picker

    private var customerPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Customer")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)

            LazyVStack(spacing: 8) {
                ForEach(customers) { customer in
                    CustomerSelectRow(
                        customer: customer,
                        isSelected: selectedCustomer?.id == customer.id
                    ) {
                        selectedCustomer = customer
                    }
                }
            }
        }
    }

    // MARK: - New Customer Form

    private var newCustomerForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Customer")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)

            // Name (required)
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)

                TextField("Customer name", text: $newName)
                    .textContentType(.name)
                    .padding()
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                    .foregroundColor(AppTheme.text)
            }

            // Price (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("Price (optional)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)

                HStack {
                    Text("$")
                        .foregroundColor(AppTheme.textMuted)
                    TextField("0", text: $newPrice)
                        .keyboardType(.decimalPad)
                        .foregroundColor(AppTheme.text)
                }
                .padding()
                .background(AppTheme.card)
                .cornerRadius(AppTheme.cornerRadiusSmall)
            }

            // Contact Details (collapsible)
            DisclosureGroup(isExpanded: $showContactDetails) {
                VStack(alignment: .leading, spacing: 12) {
                    // Phone
                    TextField("Phone number", text: $newPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(AppTheme.card)
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                        .foregroundColor(AppTheme.text)

                    // Address
                    TextField("Address", text: $newAddress)
                        .textContentType(.fullStreetAddress)
                        .padding()
                        .background(AppTheme.card)
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                        .foregroundColor(AppTheme.text)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(AppTheme.blue)
                    Text("Contact Details")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if !newPhone.isEmpty || !newAddress.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.green)
                            .font(.caption)
                    }
                }
                .foregroundColor(AppTheme.text)
            }
            .padding()
            .background(AppTheme.card)
            .cornerRadius(AppTheme.cornerRadiusSmall)

            // Recurring schedule (collapsible)
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RecurrenceRule.allCases) { rule in
                                RecurrenceChip(
                                    rule: rule,
                                    isSelected: recurrence == rule
                                ) {
                                    recurrence = rule
                                }
                            }
                        }
                    }

                    // Day picker for weekly/monthly
                    if recurrence == .weekly || recurrence == .biWeekly {
                        Text("On which day?")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(1...7, id: \.self) { day in
                                    DayChip(
                                        day: day,
                                        isSelected: recurrenceDay == day
                                    ) {
                                        recurrenceDay = day
                                    }
                                }
                            }
                        }
                    }

                    if recurrence == .monthly || recurrence == .biMonthly {
                        Text("Day of month")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)

                        Picker("Day", selection: $recurrenceDay) {
                            ForEach(1...28, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(AppTheme.orange)
                    Text("Repeat Schedule")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if recurrence != .none {
                        Text(recurrence.shortLabel)
                            .font(.caption)
                            .foregroundColor(AppTheme.green)
                    }
                }
                .foregroundColor(AppTheme.text)
            }
            .padding()
            .background(AppTheme.card)
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }

    // MARK: - Date Time Picker

    private var dateTimePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date & Time")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)

            DatePicker("", selection: $jobTime, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .tint(AppTheme.purple)
                .padding()
                .background(AppTheme.card)
                .cornerRadius(AppTheme.cornerRadius)
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)

            TextField("Add notes...", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding()
                .background(AppTheme.card)
                .cornerRadius(AppTheme.cornerRadius)
                .foregroundColor(AppTheme.text)
        }
    }

    // MARK: - Add Job

    private func addJob() {
        let customer: Customer

        if mode == .newCustomer {
            let name = newName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }

            let needsDay = recurrence == .weekly || recurrence == .biWeekly || recurrence == .monthly || recurrence == .biMonthly

            customer = Customer(
                name: name,
                phone: newPhone.isEmpty ? nil : newPhone,
                address: newAddress.isEmpty ? nil : newAddress,
                serviceName: "",
                servicePrice: Double(newPrice) ?? 0,
                recurrenceRule: recurrence,
                recurrenceDay: needsDay ? recurrenceDay : nil
            )
            modelContext.insert(customer)
        } else {
            guard let selected = selectedCustomer else { return }
            customer = selected
        }

        let job = ScheduledJob(date: jobTime, customer: customer)
        job.notes = notes.isEmpty ? nil : notes
        modelContext.insert(job)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Supporting Views

struct RecurrenceChip: View {
    let rule: RecurrenceRule
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(rule.shortLabel)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : AppTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? AppTheme.purple : AppTheme.gray100)
                )
        }
    }
}

struct DayChip: View {
    let day: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var dayName: String {
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[day]
    }

    var body: some View {
        Button(action: onTap) {
            Text(dayName)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : AppTheme.text)
                .frame(width: 44)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? AppTheme.purple : AppTheme.gray100)
                )
        }
    }
}

struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(isSelected ? .white : (disabled ? AppTheme.textMuted : AppTheme.text))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(isSelected ? AppTheme.purple : AppTheme.gray100)
            )
            .shadow(color: AppTheme.shadow, radius: 2, x: 0, y: 1)
        }
        .disabled(disabled)
    }
}

struct CustomerSelectRow: View {
    let customer: Customer
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.purpleGradient)
                        .frame(width: 44, height: 44)

                    Text(customer.initials)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.text)

                    if let phone = customer.phone, !phone.isEmpty {
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Spacer()

                if customer.servicePrice > 0 {
                    Text("$\(Int(customer.servicePrice))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.green)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppTheme.purple : AppTheme.textMuted)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isSelected ? AppTheme.purple.opacity(0.1) : AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isSelected ? AppTheme.purple : Color.clear, lineWidth: 2)
            )
            .shadow(color: AppTheme.shadow, radius: 2, x: 0, y: 1)
        }
    }
}
