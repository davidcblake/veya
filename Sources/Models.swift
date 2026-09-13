import Foundation
import SwiftData

// What a trip is made of, in four types. Named the way somebody on the trip
// would say them, not the way the storage works.
//
// **Every property has a default and every relationship is optional, on
// purpose.** CloudKit refuses a schema it cannot fill in for a record already
// on the server, and it has no way to require a relationship across devices
// that have not spoken yet. Version one keeps the store on the device, but
// obeying the rules now means turning sync on later is one line rather than a
// migration of somebody's real trip.

/// The trip itself. One per app in practice; the model does not insist on it.
@Model
final class Trip {
    var name: String = ""
    var destination: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    /// Where you are sleeping, written out: hotel, address, the door code.
    var lodging: String = ""
    /// Who is coming, as a person would list them.
    var travellers: String = ""

    @Relationship(deleteRule: .cascade, inverse: \PlanItem.trip)
    var plans: [PlanItem]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Place.trip)
    var places: [Place]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Essential.trip)
    var essentials: [Essential]? = nil

    init(
        name: String = "",
        destination: String = "",
        startDate: Date = .now,
        endDate: Date = .now,
        lodging: String = "",
        travellers: String = ""
    ) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.lodging = lodging
        self.travellers = travellers
    }

    /// Everything planned, in the order it happens.
    var plansInOrder: [PlanItem] {
        (plans ?? []).sorted { $0.startsAt < $1.startsAt }
    }

    /// The days of the trip, from the first to the last, whether or not
    /// anything is planned on them. A day with nothing on it is a real answer.
    var days: [Date] {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: endDate)
        guard first <= last else { return [first] }

        var days: [Date] = []
        var day = first
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    func plans(on day: Date) -> [PlanItem] {
        let calendar = Calendar.current
        return plansInOrder.filter { calendar.isDate($0.startsAt, inSameDayAs: day) }
    }
}

/// Something happening at a time: a train, a tour, dinner.
@Model
final class PlanItem {
    var title: String = ""
    var startsAt: Date = Date.now
    /// Whether the time matters. "Tuesday" and "Tuesday at 09:40" are
    /// different promises, and a tour you will miss is worth showing a clock.
    var isTimed: Bool = true
    /// Anything you would want in your hand when you get there: a platform, a
    /// booking reference, which entrance.
    var detail: String = ""

    var trip: Trip? = nil

    init(title: String = "", startsAt: Date = .now, isTimed: Bool = true, detail: String = "") {
        self.title = title
        self.startsAt = startsAt
        self.isTimed = isTimed
        self.detail = detail
    }
}

/// Somewhere worth going, and why.
@Model
final class Place {
    var name: String = ""
    /// Restaurant, site, church, shop — a person's word, not an enum, because
    /// the day somebody wants "gelato" as a category is the day an enum loses.
    var category: String = ""
    /// The reason it is on the list at all. The bit you forget by day four.
    var why: String = ""
    /// Opening hours, whether to book, what to order.
    var useful: String = ""
    var address: String = ""

    var trip: Trip? = nil

    init(name: String = "", category: String = "", why: String = "", useful: String = "", address: String = "") {
        self.name = name
        self.category = category
        self.why = why
        self.useful = useful
        self.address = address
    }
}

/// The things you need and cannot look up with no signal: confirmation
/// numbers, the emergency number here, where the passports are.
@Model
final class Essential {
    var label: String = ""
    var value: String = ""

    var trip: Trip? = nil

    init(label: String = "", value: String = "") {
        self.label = label
        self.value = value
    }
}
