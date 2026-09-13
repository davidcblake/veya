import PPDesign
import SwiftUI

/// Every trip, and the way to start another one.
///
/// A trip is never deleted when it ends — it is archived, and archived trips
/// stay here to be read. The history is the point.
struct TripsScreen: View {
    @Environment(\.ppTheme) private var theme
    let store: TripStore
    let onSignOut: () -> Void

    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Group {
                if store.trips.isEmpty && !store.isLoading {
                    PPEmptyState(
                        symbolName: "suitcase",
                        title: "No trips yet",
                        message: "Start one, and everyone you invite sees the same plan.",
                        action: PPEmptyState.Action(title: "New trip") { isCreating = true }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New trip", systemImage: "plus") { isCreating = true }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign out", action: onSignOut)
                }
            }
            .refreshable { await store.load() }
            .navigationDestination(for: TripRecord.self) { trip in
                TripScreen(trip: trip, backend: store.backend, token: store.token)
            }
            .sheet(isPresented: $isCreating) {
                NewTripScreen(store: store)
            }
        }
    }

    private var list: some View {
        List {
            if let failure = store.failure {
                Section {
                    Text(failure.userMessage)
                        .ppText(.body)
                        .foregroundStyle(theme.danger)
                }
            }

            Section("Trips") {
                if store.current.isEmpty {
                    Text("Nothing planned right now.")
                        .ppText(.body)
                        .foregroundStyle(theme.textSecondary)
                }
                ForEach(store.current) { trip in
                    NavigationLink(value: trip) { TripRow(trip: trip) }
                        .swipeActions(edge: .trailing) {
                            Button("Archive") {
                                Task { await store.setStatus("archived", for: trip) }
                            }
                        }
                }
            }

            if !store.archived.isEmpty {
                Section("Been there") {
                    ForEach(store.archived) { trip in
                        NavigationLink(value: trip) { TripRow(trip: trip) }
                            .swipeActions(edge: .trailing) {
                                Button("Bring back") {
                                    Task { await store.setStatus("planning", for: trip) }
                                }
                            }
                    }
                }
            }
        }
    }
}

struct TripRow: View {
    @Environment(\.ppTheme) private var theme
    let trip: TripRecord

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
            Text(trip.name)
                .ppText(.cardTitle)
                .foregroundStyle(theme.textPrimary)
            if !trip.destination.isEmpty {
                Text(trip.destination)
                    .ppText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            if let dates {
                Text(dates)
                    .ppText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var dates: String? {
        guard let start = TripDates.date(from: trip.startDate) else { return nil }
        let startText = start.formatted(date: .abbreviated, time: .omitted)
        guard let end = TripDates.date(from: trip.endDate) else { return startText }
        return "\(startText) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct NewTripScreen: View {
    @Environment(\.dismiss) private var dismiss
    let store: TripStore

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(60 * 60 * 24 * 7)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $name)
                    TextField("Where to", text: $destination)
                }
                Section {
                    DatePicker("First day", selection: $startDate, displayedComponents: .date)
                    DatePicker("Last day", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("New trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        let where_ = destination.trimmingCharacters(in: .whitespaces)
                        let start = startDate
                        let end = endDate
                        Task { await store.create(name: trimmed, destination: where_, startDate: start, endDate: end) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
