import PPDesign
import SwiftData
import SwiftUI

/// The things you cannot look up when there is no signal.
///
/// Confirmation numbers, the emergency number here, where the passports are,
/// a phrase you keep needing. Every value can be selected and copied, because
/// the whole point is reading one out to somebody behind a desk.
struct EssentialsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.ppTheme) private var theme
    let trip: Trip

    @State private var editing: Essential?
    @State private var isAdding = false

    private var essentials: [Essential] {
        trip.essentials ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if essentials.isEmpty {
                    PPEmptyState(
                        symbolName: "key",
                        title: "Nothing saved yet",
                        message: "Confirmation numbers, emergency contacts, where the passports are.",
                        action: PPEmptyState.Action(title: "Add one") { isAdding = true }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Essentials")
            .toolbar {
                Button("Add", systemImage: "plus") { isAdding = true }
            }
            .sheet(item: $editing) { essential in
                EssentialEditor(trip: trip, existing: essential)
            }
            .sheet(isPresented: $isAdding) {
                EssentialEditor(trip: trip, existing: nil)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(essentials) { essential in
                VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
                    Text(essential.label)
                        .ppText(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(essential.value)
                        .ppText(.number)
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        context.delete(essential)
                    }
                    Button("Edit") {
                        editing = essential
                    }
                }
            }
        }
    }
}

struct EssentialEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let existing: Essential?

    @State private var label: String
    @State private var value: String

    init(trip: Trip, existing: Essential?) {
        self.trip = trip
        self.existing = existing
        _label = State(initialValue: existing?.label ?? "")
        _value = State(initialValue: existing?.value ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $label)
                } footer: {
                    Text("Flight reference, apartment code, emergency number.")
                }
                Section {
                    TextField("The bit you read out", text: $value, axis: .vertical)
                        .lineLimit(1...6)
                }
            }
            .navigationTitle(existing == nil ? "Add" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let essential = existing ?? Essential()
        essential.label = label.trimmingCharacters(in: .whitespaces)
        essential.value = value
        if existing == nil {
            essential.trip = trip
            context.insert(essential)
        }
        dismiss()
    }
}
