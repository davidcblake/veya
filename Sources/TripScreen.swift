import PPDesign
import SwiftUI

/// One trip, once you are inside it.
struct TripScreen: View {
    let store: ItemStore

    var body: some View {
        TabView {
            TodayScreen(store: store)
                .tabItem { Label("Today", systemImage: "sun.horizon") }
            ItineraryScreen(store: store)
                .tabItem { Label("Itinerary", systemImage: "calendar") }
        }
        .task {
            await store.load()
            await store.watchForChanges()
        }
    }
}

/// What is happening now.
struct TodayScreen: View {
    @Environment(\.ppTheme) private var theme
    let store: ItemStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.large) {
                    if let failure = store.failure {
                        Text(failure.userMessage)
                            .ppText(.body)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Text(heading)
                        .ppText(.sectionTitle)
                        .foregroundStyle(theme.textPrimary)

                    let today = store.items(on: dayToShow)
                    if today.isEmpty {
                        PPCard {
                            Text("Nothing planned. That is allowed.")
                                .ppText(.body)
                                .foregroundStyle(theme.textSecondary)
                        }
                    } else {
                        ForEach(today) { item in
                            PPCard {
                                ItemRow(item: item)
                            }
                        }
                    }
                }
                .padding(PPSpacing.screenMargin)
            }
            .navigationTitle(store.trip.name)
        }
    }

    /// Today while the trip is on; the first day before it starts, so the
    /// screen is useful in the week you are filling it in.
    private var dayToShow: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let first = store.days.first, let last = store.days.last else { return today }
        if today < first { return first }
        if today > last { return last }
        return today
    }

    private var heading: String {
        Calendar.current.isDateInToday(dayToShow)
            ? "Today"
            : dayToShow.formatted(date: .complete, time: .omitted)
    }
}

/// Day by day, and the way to add to it.
struct ItineraryScreen: View {
    @Environment(\.ppTheme) private var theme
    let store: ItemStore

    @State private var addingOn: DayOfTheTrip?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.days, id: \.self) { day in
                    Section {
                        let items = store.items(on: day)
                        if items.isEmpty {
                            Text("Nothing planned")
                                .ppText(.body)
                                .foregroundStyle(theme.textSecondary)
                        }
                        ForEach(items) { item in
                            ItemRow(item: item)
                                .swipeActions(edge: .leading) {
                                    Button("Did it") {
                                        Task { await store.setStatus("done", for: item) }
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        Task { await store.delete(item) }
                                    }
                                    Button("Skipped") {
                                        Task { await store.setStatus("skipped", for: item) }
                                    }
                                }
                        }
                        Button("Add something") { addingOn = DayOfTheTrip(day) }
                    } header: {
                        Text(day.formatted(date: .complete, time: .omitted))
                    }
                }
            }
            .navigationTitle("Itinerary")
            .refreshable { await store.load() }
            .sheet(item: $addingOn) { day in
                AddItemScreen(store: store, day: day.date)
            }
        }
    }
}

struct ItemRow: View {
    @Environment(\.ppTheme) private var theme
    let item: ItemRecord

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
            HStack(alignment: .firstTextBaseline, spacing: PPSpacing.small) {
                if let time = ItemTimes.date(from: item.startsAt) {
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .ppText(.number)
                        .foregroundStyle(theme.accent)
                }
                Text(item.title)
                    .ppText(.cardTitle)
                    .foregroundStyle(item.status == "skipped" ? theme.textSecondary : theme.textPrimary)
                    .strikethrough(item.status == "skipped")
                if item.status == "done" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.positive)
                }
            }
            if !item.detail.isEmpty {
                Text(item.detail)
                    .ppText(.body)
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct AddItemScreen: View {
    @Environment(\.dismiss) private var dismiss
    let store: ItemStore
    let day: Date

    @State private var title = ""
    @State private var detail = ""
    @State private var isTimed = true
    @State private var time: Date

    init(store: ItemStore, day: Date) {
        self.store = store
        self.day = day
        _time = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("What is it?", text: $title) }
                Section {
                    Toggle("At a set time", isOn: $isTimed)
                    if isTimed {
                        DatePicker("When", selection: $time, displayedComponents: [.hourAndMinute])
                    }
                }
                Section("Worth having in your hand") {
                    TextField("Platform, booking reference, which entrance", text: $detail, axis: .vertical)
                        .lineLimit(2...8)
                }
            }
            .navigationTitle("Add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        let note = detail
                        let at = isTimed ? time : nil
                        let on = day
                        Task { await store.add(title: trimmed, on: on, at: at, detail: note) }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// A day, in the one form `.sheet(item:)` will accept.
struct DayOfTheTrip: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }

    init(_ date: Date) { self.date = date }
}
