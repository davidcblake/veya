import PPDesign
import SwiftUI

/// One trip, once you are inside it.
///
/// The stores are built once and kept for as long as the screen is, so
/// switching tabs does not re-fetch everything and swiping between Today and
/// Itinerary is instant.
struct TripScreen: View {
    let trip: TripRecord
    let backend: Backend
    let token: String

    @State private var items: ItemStore?
    @State private var stays: StayStore?
    @State private var todos: TodoStore?

    var body: some View {
        Group {
            if let items, let stays, let todos {
                TabView {
                    TodayScreen(store: items)
                        .tabItem { Label("Today", systemImage: "sun.horizon") }
                    ItineraryScreen(store: items)
                        .tabItem { Label("Itinerary", systemImage: "calendar") }
                    StaysScreen(store: stays)
                        .tabItem { Label("Stays", systemImage: "bed.double") }
                    TodosScreen(store: todos)
                        .tabItem { Label("To do", systemImage: "checklist") }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            guard items == nil else { return }
            let itemStore = ItemStore(trip: trip, backend: backend, token: token)
            let stayStore = StayStore(trip: trip, backend: backend, token: token)
            let todoStore = TodoStore(trip: trip, backend: backend, token: token)
            items = itemStore
            stays = stayStore
            todos = todoStore
            await itemStore.load()
            await stayStore.load()
            await todoStore.load()
            // Keeps running until the screen goes away, which is what `.task`
            // cancellation is for.
            await itemStore.watchForChanges()
        }
    }
}

/// Where you are sleeping, and the address to hand a taxi driver.
struct StaysScreen: View {
    @Environment(\.ppTheme) private var theme
    let store: StayStore

    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if store.stays.isEmpty {
                    PPEmptyState(
                        symbolName: "bed.double",
                        title: "Nowhere to sleep yet",
                        message: "Add where you're staying so the address is here when the signal isn't.",
                        action: PPEmptyState.Action(title: "Add a stay") { isAdding = true }
                    )
                } else {
                    List {
                        ForEach(store.stays) { stay in
                            VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
                                Text(stay.city.isEmpty ? stay.name : stay.city)
                                    .ppText(.cardTitle)
                                    .foregroundStyle(theme.textPrimary)
                                if !stay.name.isEmpty && !stay.city.isEmpty {
                                    Text(stay.name)
                                        .ppText(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                if let nights {
                                    Text(nights(stay))
                                        .ppText(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                if !stay.address.isEmpty {
                                    Text(stay.address)
                                        .ppText(.body)
                                        .foregroundStyle(theme.textPrimary)
                                        .textSelection(.enabled)
                                }
                                if !stay.detail.isEmpty {
                                    Text(stay.detail)
                                        .ppText(.body)
                                        .foregroundStyle(theme.textSecondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await store.delete(stay) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stays")
            .toolbar {
                Button("Add", systemImage: "plus") { isAdding = true }
            }
            .refreshable { await store.load() }
            .sheet(isPresented: $isAdding) { AddStayScreen(store: store) }
        }
    }

    /// A closure rather than a method so the row stays a plain expression.
    private var nights: ((StayRecord) -> String)? {
        { stay in
            guard let checkIn = TripDates.date(from: stay.checkIn) else { return "" }
            let inText = checkIn.formatted(date: .abbreviated, time: .omitted)
            guard let checkOut = TripDates.date(from: stay.checkOut) else { return inText }
            return "\(inText) – \(checkOut.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

struct AddStayScreen: View {
    @Environment(\.dismiss) private var dismiss
    let store: StayStore

    @State private var city = ""
    @State private var name = ""
    @State private var address = ""
    @State private var detail = ""
    @State private var checkIn = Date.now
    @State private var checkOut = Date.now.addingTimeInterval(60 * 60 * 24 * 2)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("City", text: $city)
                    TextField("Hotel or apartment", text: $name)
                }
                Section {
                    DatePicker("Check in", selection: $checkIn, displayedComponents: .date)
                    DatePicker("Check out", selection: $checkOut, in: checkIn..., displayedComponents: .date)
                }
                Section("Address") {
                    TextField("Street, number, city", text: $address, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Anything else") {
                    TextField("Door code, who to ask for, parking", text: $detail, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("Add a stay")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let values = (city, name, address, detail, checkIn, checkOut)
                        Task {
                            await store.add(
                                city: values.0, name: values.1, address: values.2,
                                checkIn: values.4, checkOut: values.5, detail: values.3
                            )
                        }
                        dismiss()
                    }
                    .disabled(city.trimmingCharacters(in: .whitespaces).isEmpty
                              && name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// What still has to be booked.
struct TodosScreen: View {
    @Environment(\.ppTheme) private var theme
    let store: TodoStore

    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Something to book", text: $newTitle)
                        Button("Add") {
                            let title = newTitle.trimmingCharacters(in: .whitespaces)
                            guard !title.isEmpty else { return }
                            newTitle = ""
                            Task { await store.add(title: title, url: "") }
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                ForEach(store.todos) { todo in
                    Button {
                        Task { await store.setDone(!todo.done, for: todo) }
                    } label: {
                        HStack(spacing: PPSpacing.small) {
                            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.done ? theme.positive : theme.textSecondary)
                            Text(todo.title)
                                .ppText(.body)
                                .foregroundStyle(todo.done ? theme.textSecondary : theme.textPrimary)
                                .strikethrough(todo.done)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            Task { await store.delete(todo) }
                        }
                    }
                }
            }
            .navigationTitle(store.openCount > 0 ? "To do · \(store.openCount)" : "To do")
            .refreshable { await store.load() }
        }
    }
}
