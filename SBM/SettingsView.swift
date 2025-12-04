import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 20
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 0
    @AppStorage("hourlyRateGoal") private var hourlyRateGoal = 50.0

    @State private var showingTimePicker = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var reminderTime: Date {
        get {
            var components = DateComponents()
            components.hour = dailyReminderHour
            components.minute = dailyReminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyReminderHour = components.hour ?? 20
            dailyReminderMinute = components.minute ?? 0
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: reminderTime)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        notificationsSection
                        goalsSection
                        aboutSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            checkNotificationStatus()
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notifications", systemImage: "bell.fill")
                .font(.headline)
                .foregroundColor(AppTheme.text)

            VStack(spacing: 0) {
                // Daily Reminder Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Reminder")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppTheme.text)
                        Text("Get reminded to log your day")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $dailyReminderEnabled)
                        .tint(AppTheme.purple)
                        .onChange(of: dailyReminderEnabled) { _, newValue in
                            if newValue {
                                requestNotificationPermission()
                            } else {
                                cancelNotifications()
                            }
                        }
                }
                .padding()

                if dailyReminderEnabled {
                    Divider()
                        .padding(.horizontal)

                    // Time Picker
                    HStack {
                        Text("Reminder Time")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.text)

                        Spacer()

                        DatePicker("", selection: Binding(
                            get: { reminderTime },
                            set: { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                dailyReminderHour = components.hour ?? 20
                                dailyReminderMinute = components.minute ?? 0
                                scheduleNotification()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(AppTheme.purple)
                    }
                    .padding()
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)

            if notificationStatus == .denied {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.orange)
                    Text("Notifications are disabled. Enable them in Settings.")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Goals", systemImage: "target")
                .font(.headline)
                .foregroundColor(AppTheme.text)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hourly Rate Goal")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppTheme.text)
                        Text("Your target hourly rate")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("$")
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("50", value: $hourlyRateGoal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .foregroundColor(AppTheme.green)
                    }
                    .font(.headline)
                }
                .padding()
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("About", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(AppTheme.text)

            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.text)
                    Spacer()
                    Text("1.0.0")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Notification Helpers

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    scheduleNotification()
                } else {
                    dailyReminderEnabled = false
                }
                checkNotificationStatus()
            }
        }
    }

    private func scheduleNotification() {
        cancelNotifications()

        let content = UNMutableNotificationContent()
        content.title = "Daily Log Reminder"
        content.body = "Don't forget to log your revenue, expenses, and hours for today!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = dailyReminderHour
        dateComponents.minute = dailyReminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
}
