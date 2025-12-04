import SwiftUI
import SwiftData

struct CustomerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var customer: Customer?

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var serviceName = ""
    @State private var price = ""

    private var isEditing: Bool { customer != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Contact Section
                Section("Contact") {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    TextField("Address (optional)", text: $address)
                        .textContentType(.fullStreetAddress)
                }

                // Service Section
                Section("Service") {
                    TextField("Service name (e.g. Lawn Care)", text: $serviceName)

                    HStack {
                        Text("$")
                            .foregroundColor(AppTheme.secondaryLabel)
                        TextField("Price", text: $price)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Customer" : "New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadData()
            }
        }
        .navigationViewStyle(.stack)
    }

    private func loadData() {
        guard let customer = customer else { return }
        name = customer.name
        phone = customer.phone ?? ""
        address = customer.address ?? ""
        serviceName = customer.serviceName
        price = customer.servicePrice > 0 ? String(format: "%.0f", customer.servicePrice) : ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let priceValue = Double(price) ?? 0

        if let existing = customer {
            existing.name = trimmedName
            existing.phone = phone.isEmpty ? nil : phone
            existing.address = address.isEmpty ? nil : address
            existing.serviceName = serviceName
            existing.servicePrice = priceValue
        } else {
            let newCustomer = Customer(
                name: trimmedName,
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                serviceName: serviceName,
                servicePrice: priceValue,
                recurrenceRule: .none
            )
            modelContext.insert(newCustomer)
        }

        try? modelContext.save()
    }
}
