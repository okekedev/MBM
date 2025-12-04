import SwiftUI
import SwiftData

@main
struct MBMApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyEntry.self,
            Customer.self,
            ScheduledJob.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View (Subscription Gate)
struct RootView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        Group {
            if subscriptionManager.isLoading && subscriptionManager.subscriptionStatus == .unknown {
                // Loading state
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            } else if subscriptionManager.isSubscribed {
                // User is subscribed - show main app
                ContentView()
            } else {
                // Not subscribed - show paywall
                PaywallView()
            }
        }
    }
}
