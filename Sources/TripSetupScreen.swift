import PPDesign
import SwiftData
import SwiftUI

/// The first run: there is no trip yet, so make one.
///
/// Deliberately four fields and a button. Everything else about the trip is
/// added once you are in it, because nobody fills in a long form on the day
/// they are packing.
struct TripSetupScreen: View {
    @Environment(\.modelContext) private var context

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
                } footer: {
                    Text("Rome, Paris, wherever you are going.")
                }

                Section {
                    DatePicker("First day", selection: $startDate, displayedComponents: .date)
                    DatePicker("Last day", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    Button("Start the trip") {
                        create()
                    }
                    .buttonStyle(.ppProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New trip")
        }
    }

    private func create() {
        let trip = Trip(
            name: name.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate
        )
        context.insert(trip)
    }
}
