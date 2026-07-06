import SwiftData
import SwiftUI

struct ContactCareView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: ContactSnapshot

    @State private var isAddSheetPresented = false

    private var sortedItems: [ContactCareItem] {
        contact.careItems.sorted { lhs, rhs in
            if lhs.month != rhs.month { return lhs.month < rhs.month }
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: K.Spacing.md) {
            addButton

            if !sortedItems.isEmpty {
                itemsList
            }
        }
        .onAppear {
            contact.ensureSyncedBirthdayCareItem(in: modelContext)
        }
        .sheet(isPresented: $isAddSheetPresented) {
            AddContactCareItemSheet(contact: contact)
        }
    }

    private var addButton: some View {
        Button {
            isAddSheetPresented = true
        } label: {
            Label("Add", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.kSecondary(size: .medium, corner: .prominent, expands: true))
    }

    private var itemsList: some View {
        VStack(spacing: K.Spacing.sm) {
            ForEach(sortedItems, id: \.id) { item in
                ContactCareItemRow(item: item) {
                    deleteItem(item)
                }
            }
        }
    }

    private func deleteItem(_ item: ContactCareItem) {
        contact.careItems.removeAll { $0.id == item.id }
        modelContext.delete(item)
    }
}

private struct ContactCareItemRow: View {
    let item: ContactCareItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: K.Spacing.md) {
            Image(systemName: item.kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(K.Color.primary)
                .frame(width: 36, height: 36)
                .background(K.Color.primarySoft, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.subheadline.weight(.medium))

                Text(item.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete care item")
        }
        .padding(K.Spacing.md)
        .background(K.Color.tileBackground, in: RoundedRectangle.k(K.Radius.sm))
    }
}

private struct AddContactCareItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: ContactSnapshot

    @State private var kind = ContactCareKind.birthday
    @State private var selectedDate: Date
    @State private var customTitle = ""
    @State private var notes = ""

    init(contact: ContactSnapshot) {
        self.contact = contact
        _selectedDate = State(initialValue: contact.birthday?.date() ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ContactCareKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }
                }

                if kind == .appointment || kind == .other {
                    Section("Title") {
                        TextField(
                            kind == .appointment ? "Doctor visit, coffee catch-up…" : "What should we remind you about?",
                            text: $customTitle
                        )
                    }
                }

                Section("Date") {
                    DatePicker(
                        "When",
                        selection: $selectedDate,
                        displayedComponents: kind.requiresYear ? [.date] : [.date]
                    )
                    .datePickerStyle(.graphical)

                    if !kind.requiresYear {
                        Text("Year is optional for birthdays and anniversaries.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Optional details", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveItem() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: kind) { _, newKind in
                guard newKind == .birthday, let birthdayDate = contact.birthday?.date() else { return }
                selectedDate = birthdayDate
            }
        }
    }

    private var canSave: Bool {
        switch kind {
        case .appointment, .other:
            !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .birthday, .anniversary:
            true
        }
    }

    private func saveItem() {
        let calendar = Calendar.current
        let item = ContactCareItem(
            kind: kind,
            month: calendar.component(.month, from: selectedDate),
            day: calendar.component(.day, from: selectedDate),
            year: kind.requiresYear ? calendar.component(.year, from: selectedDate) : optionalYear(from: selectedDate, calendar: calendar),
            customTitle: customTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        item.contact = contact
        contact.careItems.append(item)
        modelContext.insert(item)
        dismiss()
    }

    private func optionalYear(from date: Date, calendar: Calendar) -> Int? {
        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: .now)
        return year == currentYear ? nil : year
    }
}
