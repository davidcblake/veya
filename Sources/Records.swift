import Foundation

// The rows, as Swift sees them. Column names convert automatically
// (snake_case ↔ camelCase), so these mirror `supabase/0001_init.sql` directly.
//
// **Dates are text, deliberately.** Postgres hands back `2026-09-22` for a date
// column and a timestamp with fractional seconds for a timestamptz, and a
// decoder that tries to be clever about both fails at runtime on a phone in
// Croatia. They are parsed where they are displayed, by code that knows which
// kind it is looking at.

struct TripRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var destination: String
    var startDate: String?
    var endDate: String?
    var status: String

    var isArchived: Bool { status == "archived" }
}

struct NewTrip: Encodable, Sendable {
    var name: String
    var destination: String
    var startDate: String?
    var endDate: String?
    var status: String = "planning"
    var createdBy: String
}

struct TripStatusChange: Encodable, Sendable {
    var status: String
}

struct NewMember: Encodable, Sendable {
    var tripId: String
    var userId: String
    var role: String
    var displayName: String
}

struct ItemRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var tripId: String
    var day: String
    var startsAt: String?
    var title: String
    var detail: String
    var isOptional: Bool
    var status: String
    var wasOffPlan: Bool
    var position: Int
}

struct NewItem: Encodable, Sendable {
    var tripId: String
    var day: String
    var startsAt: String?
    var title: String
    var detail: String
    var isOptional: Bool = false
    var wasOffPlan: Bool = false
    var position: Int = 0
}

struct StayRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var tripId: String
    var city: String
    var name: String
    var checkIn: String?
    var checkOut: String?
    var address: String
    var detail: String
    var booked: Bool
}

struct TodoRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var tripId: String
    var title: String
    var url: String
    var done: Bool
    var position: Int
}
