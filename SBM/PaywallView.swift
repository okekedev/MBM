import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [AppTheme.purple.opacity(0.1), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // App Icon / Logo
                    ZStack {
                        Circle()
                            .fill(AppTheme.purpleGradient)
                            .frame(width: 100, height: 100)

                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    // Title
                    VStack(spacing: 8) {
                        Text("MBM Premium")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.text)

                        Text("Manage your business like a pro")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    // Features List
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "calendar.badge.clock", title: "Smart Scheduling", description: "Organize jobs with recurring schedules")
                        FeatureRow(icon: "person.2.fill", title: "Customer Management", description: "Keep all your clients organized")
                        FeatureRow(icon: "chart.bar.fill", title: "Income Tracking", description: "Track earnings and business growth")
                        FeatureRow(icon: "icloud.fill", title: "iCloud Sync", description: "Access your data on all devices")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)

                    Spacer().frame(height: 10)

                    // Pricing Card
                    VStack(spacing: 12) {
                        // Trial Badge
                        Text("\(subscriptionManager.trialDurationString.uppercased()) FREE TRIAL")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.purple)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(AppTheme.purple.opacity(0.15))
                            .cornerRadius(20)

                        // Price
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(subscriptionManager.priceString)
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(AppTheme.text)

                            Text("/ month")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Text("after free trial ends")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 32)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 24)

                    // Subscribe Button
                    Button(action: {
                        Task {
                            await subscriptionManager.purchase()
                        }
                    }) {
                        HStack {
                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Start Free Trial")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.purpleGradient)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(subscriptionManager.isLoading)
                    .padding(.horizontal, 24)

                    // Error Message
                    if let error = subscriptionManager.purchaseError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.purple)
                    }
                    .disabled(subscriptionManager.isLoading)

                    // Terms
                    VStack(spacing: 8) {
                        Text("Cancel anytime. Subscription auto-renews monthly.")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Link("Privacy Policy", destination: URL(string: "https://okekedev.github.io/MBM/privacy.html")!)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.purple)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.purple.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.text)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
    }
}

#Preview {
    PaywallView()
}
