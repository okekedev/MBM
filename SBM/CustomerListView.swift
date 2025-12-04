import SwiftUI
import SwiftData
import Contacts
import ContactsUI

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.name) private var customers: [Customer]
    @State private var showingAddCustomer = false
    @State private var showingContactPicker = false
    @State private var selectedCustomer: Customer?
    @State private var searchText = ""

    private var filteredCustomers: [Customer] {
        if searchText.isEmpty { return customers }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.serviceName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    header

                    // Search
                    if !customers.isEmpty {
                        searchBar
                    }

                    // Customer List
                    customerListSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showingAddCustomer) {
            CustomerFormView()
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView { contact in
                importContact(contact)
            }
        }
        .sheet(item: $selectedCustomer) { customer in
            CustomerDetailView(customer: customer)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Customers")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Menu {
                Button {
                    showingContactPicker = true
                } label: {
                    Label("Import Contact", systemImage: "person.crop.circle.badge.plus")
                }

                Button {
                    showingAddCustomer = true
                } label: {
                    Label("Add Manually", systemImage: "plus")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(AppTheme.primaryGradient)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.textMuted)

            TextField("Search customers...", text: $searchText)
                .foregroundColor(AppTheme.text)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.cornerRadiusSmall)
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
    }

    // MARK: - Customer List

    private var customerListSection: some View {
        VStack(spacing: 12) {
            if customers.isEmpty {
                emptyState
            } else if filteredCustomers.isEmpty {
                noResultsState
            } else {
                ForEach(filteredCustomers) { customer in
                    CustomerCard(customer: customer) {
                        selectedCustomer = customer
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.purpleGradient)
            }

            VStack(spacing: 8) {
                Text("No Customers Yet")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppTheme.text)

                Text("Add your first customer to start\ntracking recurring jobs")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    showingContactPicker = true
                } label: {
                    Label("Import", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppTheme.gray100)
                        .foregroundColor(AppTheme.text)
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }

                Button {
                    showingAddCustomer = true
                } label: {
                    Label("Add New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppTheme.purpleGradient)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }
            }
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(AppTheme.textMuted)

            Text("No results for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func importContact(_ contact: CNContact) {
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let phone = contact.phoneNumbers.first?.value.stringValue
        let address: String? = {
            guard let postal = contact.postalAddresses.first?.value else { return nil }
            return [postal.street, postal.city, postal.state, postal.postalCode].filter { !$0.isEmpty }.joined(separator: ", ")
        }()

        let customer = Customer(
            name: name.isEmpty ? "New Customer" : name,
            phone: phone,
            address: address,
            serviceName: "",
            servicePrice: 0,
            recurrenceRule: .none
        )
        modelContext.insert(customer)
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedCustomer = customer
        }
    }
}

// MARK: - Customer Card

struct CustomerCard: View {
    let customer: Customer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Avatar with gradient
                ZStack {
                    Circle()
                        .fill(AppTheme.purpleGradient)
                        .frame(width: 50, height: 50)

                    Text(customer.initials)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.text)

                    if !customer.serviceName.isEmpty {
                        Text(customer.serviceName)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if customer.servicePrice > 0 {
                    Text(formatCurrency(customer.servicePrice))
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppTheme.green)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Customer Detail View

struct CustomerDetailView: View {
    @Bindable var customer: Customer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingSchedule = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader

                    // Quick Actions
                    quickActions

                    // Service Info
                    serviceInfo

                    // Contact Info
                    contactInfo

                    // Delete
                    deleteButton
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    try? modelContext.save()
                    dismiss()
                }
                .foregroundColor(AppTheme.purple)
            }
        }
        .sheet(isPresented: $showingSchedule) {
            ScheduleJobSheet(customer: customer)
        }
        .alert("Delete Customer", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(customer)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \(customer.name) and all their scheduled jobs.")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.purpleGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: AppTheme.purple.opacity(0.3), radius: 10)

                Text(customer.initials)
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
            }

            TextField("Customer Name", text: $customer.name)
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            ActionTile(icon: "calendar.badge.plus", label: "Schedule", color: AppTheme.purple) {
                showingSchedule = true
            }

            if let phone = customer.phone, !phone.isEmpty {
                ActionTile(icon: "phone.fill", label: "Call", color: AppTheme.blue) {
                    callCustomer(phone)
                }

                ActionTile(icon: "message.fill", label: "Text", color: AppTheme.teal) {
                    messageCustomer(phone)
                }
            }

            if let address = customer.address, !address.isEmpty {
                ActionTile(icon: "map.fill", label: "Maps", color: AppTheme.green) {
                    openInMaps(address)
                }
            }
        }
    }

    private var serviceInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Service Details", systemImage: "briefcase.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 12) {
                EditableRow(label: "Service", text: Binding(
                    get: { customer.serviceName },
                    set: { customer.serviceName = $0 }
                ), placeholder: "e.g. Lawn Care")

                HStack {
                    Text("Price")
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("$")
                            .foregroundColor(AppTheme.green)
                        TextField("0", value: $customer.servicePrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppTheme.green)
                            .frame(width: 80)
                    }
                    .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
    }

    private var contactInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Contact Info", systemImage: "person.crop.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 12) {
                EditableRow(label: "Phone", text: Binding(
                    get: { customer.phone ?? "" },
                    set: { customer.phone = $0.isEmpty ? nil : $0 }
                ), placeholder: "Phone number", keyboardType: .phonePad)

                EditableRow(label: "Address", text: Binding(
                    get: { customer.address ?? "" },
                    set: { customer.address = $0.isEmpty ? nil : $0 }
                ), placeholder: "Street address")
            }
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 1)
    }

    private var deleteButton: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Delete Customer")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.danger)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.danger.opacity(0.15))
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }

    private func callCustomer(_ phone: String) {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }

    private func messageCustomer(_ phone: String) {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "sms:\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }

    private func openInMaps(_ address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct EditableRow: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppTheme.text)
        }
        .font(.subheadline)
    }
}

struct ActionTile: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(label)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppTheme.text

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct ScheduleJobSheet: View {
    let customer: Customer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(customer.name)
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppTheme.text)
                        Text(customer.serviceName)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.top)

                    DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppTheme.purple)
                        .padding(.horizontal)

                    Spacer()

                    Button {
                        let job = ScheduledJob(date: Calendar.current.startOfDay(for: selectedDate), customer: customer)
                        modelContext.insert(job)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Text("Schedule Job")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.purpleGradient)
                            .foregroundColor(.white)
                            .cornerRadius(AppTheme.cornerRadius)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct ContactPickerView: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void
        init(onSelect: @escaping (CNContact) -> Void) { self.onSelect = onSelect }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) { onSelect(contact) }
    }
}
