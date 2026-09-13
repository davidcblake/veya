import PPDesign
import SwiftData
import SwiftUI

/// The screen you open twenty times a day.
///
/// What is happening now, where you are sleeping tonight, and who is with you.
/// Nothing on it waits for anything.
struct TodayScreen: View {
    @Environment(\.ppTheme) private var theme
    @Bindable var trip: Trip

    @State private var isEditingTrip = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.large) {
                    header
                    today
                    staying
                }
                .padding(PPSpacing.screenMargin)
            }
            .navigationTitle(trip.name.isEmpty ? "Trip" : trip.name)
            .toolbar {
                Button("Edit") { isEditingTrip = true }
            }
            .sheet(isPresented: $isEditingTrip) {
                TripDetailsEditor(trip: trip)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
            if !trip.destination.isEmpty {
                Text(trip.destination)
                    .ppText(.screenTitle)
                    .foregroundStyle(theme.textPrimary)
            }
            Text(dateRange)
                .ppText(.caption)
                .foregroundStyle(theme.textSecondary)
            if !trip.travellers.isEmpty {
                Text(trip.travellers)
                    .ppText(.body)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var today: some View {
        VStack(alignment: .leading, spacing: PPSpacing.small) {
            Text(headingForToday)
                .ppText(.sectionTitle)
                .foregroundStyle(theme.textPrimary)

            let plans = trip.plans(on: dayToShow)
            if plans.isEmpty {
                PPCard {
                    Text("Nothing planned. That is allowed.")
                        .ppText(.body)
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                ForEach(plans) { plan in
                    PPCard {
                        PlanRow(plan: plan)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var staying: some View {
        if !trip.lodging.isEmpty {
            VStack(alignment: .leading, spacing: PPSpacing.small) {
                Text("Where you're staying")
                    .ppText(.sectionTitle)
                    .foregroundStyle(theme.textPrimary)
                PPCard {
                    Text(trip.lodging)
                        .ppText(.body)
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    /// Today if the trip is on, otherwise the first day — so the screen is
    /// useful the week before you leave, which is when it gets filled in.
    private var dayToShow: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let first = calendar.startOfDay(for: trip.startDate)
        let last = calendar.startOfDay(for: trip.endDate)
        if today < first { return first }
        if today > last { return last }
        return today
    }

    private var headingForToday: String {
        Calendar.current.isDateInToday(dayToShow)
            ? "Today"
            : dayToShow.formatted(date: .complete, time: .omitted)
    }

    private var dateRange: String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return start == end ? start : "\(start) – \(end)"
    }
}

/// One planned thing, shown the same way everywhere.
struct PlanRow: View {
    @Environment(\.ppTheme) private var theme
    let plan: PlanItem

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpacing.extraSmall) {
            HStack(alignment: .firstTextBaseline, spacing: PPSpacing.small) {
                if plan.isTimed {
                    Text(plan.startsAt.formatted(date: .omitted, time: .shortened))
                        .ppText(.number)
                        .foregroundStyle(theme.accent)
                }
                Text(plan.title)
                    .ppText(.cardTitle)
                    .foregroundStyle(theme.textPrimary)
            }
            if !plan.detail.isEmpty {
                Text(plan.detail)
                    .ppText(.body)
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }
}

/// The trip's own details, edited in one place rather than asked for up front.
struct TripDetailsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var trip: Trip

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $trip.name)
                    TextField("Where to", text: $trip.destination)
                }
                Section {
                    DatePicker("First day", selection: $trip.startDate, displayedComponents: .date)
                    DatePicker("Last day", selection: $trip.endDate, displayedComponents: .date)
                }
                Section("Where you're staying") {
                    TextField("Hotel, address, door code", text: $trip.lodging, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Who's coming") {
                    TextField("Names", text: $trip.travellers, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Trip")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
