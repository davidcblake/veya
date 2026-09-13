import PPDesign
import SwiftData
import SwiftUI

/// Somewhere worth going, and the reason it is on the list.
///
/// The reason is the part that matters. By day four nobody remembers why a
/// restaurant was added two months ago, and a name with no reason gets skipped.
struct PlacesScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.ppTheme) private var theme
    let trip: Trip

    @State private var editing: Place?
    @State private var isAdding = false

    private var places: [Place] {
        (trip.places ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty {
                    PPEmptyState(
                        symbolName: "mappin.and.ellipse",
                        title: "No places yet",
                        message: "Add the restaurants, sites and shops you don't want to forget.",
                        action: PPEmptyState.Action(title: "Add a place") { isAdding = true }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Places")
            .toolbar {
                Button("Add", systemImage: "plus") { isAdding = true }
            }
            .sheet(item: $editing) { place in
                PlaceEditor(trip: trip, existing: place)
            }
            .sheet(isPresented: $isAdding) {
                PlaceEditor(trip: trip, existing: nil)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(places) { place in
                Button {
                    editing = place
                } label: {
                    VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
                        Text(place.name)
                            .ppText(.cardTitle)
                            .foregroundStyle(theme.textPrimary)
                        if !place.category.isEmpty {
                            Text(place.category)
                                .ppText(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        if !place.why.isEmpty {
                            Text(place.why)
                                .ppText(.body)
                                .foregroundStyle(theme.textSecondary)
                        }
                        if !place.useful.isEmpty {
                            Text(place.useful)
                                .ppText(.body)
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(places[index])
                }
            }
        }
    }
}

struct PlaceEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let existing: Place?

    @State private var name: String
    @State private var category: String
    @State private var why: String
    @State private var useful: String
    @State private var address: String

    init(trip: Trip, existing: Place?) {
        self.trip = trip
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? "")
        _why = State(initialValue: existing?.why ?? "")
        _useful = State(initialValue: existing?.useful ?? "")
        _address = State(initialValue: existing?.address ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Restaurant, site, church, shop", text: $category)
                }
                Section("Why it's worth going") {
                    TextField("The bit you'll forget", text: $why, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Useful to know") {
                    TextField("Opening hours, whether to book, what to order", text: $useful, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Address") {
                    TextField("Street", text: $address, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(existing == nil ? "Add a place" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let place = existing ?? Place()
        place.name = name.trimmingCharacters(in: .whitespaces)
        place.category = category.trimmingCharacters(in: .whitespaces)
        place.why = why
        place.useful = useful
        place.address = address
        if existing == nil {
            place.trip = trip
            context.insert(place)
        }
        dismiss()
    }
}
