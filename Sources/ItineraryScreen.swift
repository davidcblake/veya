import PPDesign
import SwiftData
import SwiftUI

/// What is planned, in order, day by day.
///
/// Every day of the trip gets a heading even when nothing is on it, because
/// "nothing is planned on Thursday" is an answer somebody is looking for.
struct ItineraryScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.ppTheme) private var theme
    let trip: Trip

    @State private var editing: PlanItem?
    @State private var addingOn: DayOfTheTrip?

    var body: some View {
        NavigationStack {
            List {
                ForEach(trip.days, id: \.self) { day in
                    Section {
                        let plans = trip.plans(on: day)
                        if plans.isEmpty {
                            Text("Nothing planned")
                                .ppText(.body)
                                .foregroundStyle(theme.textSecondary)
                        } else {
                            ForEach(plans) { plan in
                                Button {
                                    editing = plan
                                } label: {
                                    PlanRow(plan: plan)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    context.delete(plans[index])
                                }
                            }
                        }
                        Button("Add something") {
                            addingOn = DayOfTheTrip(day)
                        }
                        .ppText(.body)
                    } header: {
                        Text(day.formatted(date: .complete, time: .omitted))
                    }
                }
            }
            .navigationTitle("Itinerary")
            .sheet(item: $editing) { plan in
                PlanEditor(trip: trip, existing: plan, day: plan.startsAt)
            }
            .sheet(item: $addingOn) { day in
                PlanEditor(trip: trip, existing: nil, day: day.date)
            }
        }
    }
}

/// Adding and changing are the same screen, because they are the same job.
struct PlanEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let existing: PlanItem?

    @State private var title: String
    @State private var detail: String
    @State private var startsAt: Date
    @State private var isTimed: Bool

    init(trip: Trip, existing: PlanItem?, day: Date) {
        self.trip = trip
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _detail = State(initialValue: existing?.detail ?? "")
        _startsAt = State(initialValue: existing?.startsAt ?? Self.defaultTime(on: day))
        _isTimed = State(initialValue: existing?.isTimed ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $title)
                }
                Section {
                    Toggle("At a set time", isOn: $isTimed)
                    DatePicker(
                        "When",
                        selection: $startsAt,
                        displayedComponents: isTimed ? [.date, .hourAndMinute] : [.date]
                    )
                }
                Section("Worth having in your hand") {
                    TextField("Platform, booking reference, which entrance", text: $detail, axis: .vertical)
                        .lineLimit(2...8)
                }
            }
            .navigationTitle(existing == nil ? "Add" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let plan = existing ?? PlanItem()
        plan.title = title.trimmingCharacters(in: .whitespaces)
        plan.detail = detail
        plan.startsAt = startsAt
        plan.isTimed = isTimed
        if existing == nil {
            plan.trip = trip
            context.insert(plan)
        }
        dismiss()
    }

    /// Nine in the morning, because most things on a trip are not at midnight
    /// and a default of midnight makes everybody set the time twice.
    private static func defaultTime(on day: Date) -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }
}

/// A day, in the one form `.sheet(item:)` will accept.
///
/// A wrapper rather than making `Date` itself `Identifiable`: conforming a type
/// somebody else owns is a promise about every other file in the app, and this
/// needs it in exactly one place.
struct DayOfTheTrip: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }

    init(_ date: Date) {
        self.date = date
    }
}
