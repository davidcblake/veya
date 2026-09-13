import Foundation
import Observation

/// Everything planned for one trip, and the changes anybody makes to it.
///
/// **It re-reads every twenty seconds.** Not a websocket: the prototype nine
/// people actually used on a trip in Italy polled at exactly this interval and
/// nobody noticed a delay, and a polling loop is something that can be reasoned
/// about on a bad connection. It can be moved to Supabase's realtime channel
/// later without any screen changing.
@MainActor
@Observable
final class ItemStore {
    private(set) var items: [ItemRecord] = []
    private(set) var failure: BackendFailure?
    private(set) var isLoading = false

    let trip: TripRecord
    private let backend: Backend
    private let token: String

    init(trip: TripRecord, backend: Backend, token: String) {
        self.trip = trip
        self.backend = backend
        self.token = token
    }

    /// The days of the trip, whether or not anything is on them. A day with
    /// nothing planned is an answer somebody is looking for.
    var days: [Date] {
        guard let first = TripDates.date(from: trip.startDate) else { return [] }
        let last = TripDates.date(from: trip.endDate) ?? first
        var days: [Date] = []
        var day = first
        let calendar = Calendar.current
        while day <= last, days.count < 400 {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    func items(on day: Date) -> [ItemRecord] {
        let text = TripDates.text(from: day)
        return items
            .filter { $0.day == text }
            .sorted { left, right in
                switch (ItemTimes.date(from: left.startsAt), ItemTimes.date(from: right.startsAt)) {
                case (let l?, let r?): return l < r
                case (nil, _?):        return false   // untimed things sit after timed ones
                case (_?, nil):        return true
                case (nil, nil):       return left.position < right.position
                }
            }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await backend.rows(
                from: "items",
                query: [URLQueryItem(name: "trip_id", value: "eq.\(trip.id)")],
                as: ItemRecord.self,
                token: token
            )
            failure = nil
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't load the itinerary.", logMessage: "\(error)")
        }
    }

    /// Keep re-reading while the screen is open, so somebody else adding dinner
    /// shows up without anybody pulling to refresh.
    func watchForChanges() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            if Task.isCancelled { return }
            await load()
        }
    }

    func add(title: String, on day: Date, at time: Date?, detail: String, offPlan: Bool = false) async {
        do {
            let _: [ItemRecord] = try await backend.insert(
                NewItem(
                    tripId: trip.id,
                    day: TripDates.text(from: day),
                    startsAt: time.map(ItemTimes.text(from:)),
                    title: title,
                    detail: detail,
                    wasOffPlan: offPlan,
                    position: items.count
                ),
                into: "items",
                token: token
            )
            await load()
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't add that.", logMessage: "\(error)")
        }
    }

    /// Did it, skipped it, or back to planned. Nothing is deleted by marking.
    func setStatus(_ status: String, for item: ItemRecord) async {
        do {
            try await backend.update(
                ItemStatusChange(status: status),
                in: "items",
                matching: [URLQueryItem(name: "id", value: "eq.\(item.id)")],
                token: token
            )
            await load()
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't change that.", logMessage: "\(error)")
        }
    }

    func delete(_ item: ItemRecord) async {
        do {
            try await backend.delete(
                from: "items",
                matching: [URLQueryItem(name: "id", value: "eq.\(item.id)")],
                token: token
            )
            await load()
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't remove that.", logMessage: "\(error)")
        }
    }
}

struct ItemStatusChange: Encodable, Sendable {
    var status: String
}

/// Timestamps crossing the wire, in the one format Postgres sends and accepts.
enum ItemTimes {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Postgres sends fractional seconds sometimes and not others, and a parser
    /// that only handles one of those fails on roughly half the rows.
    static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        return withFraction.date(from: text) ?? plain.date(from: text)
    }

    static func text(from date: Date) -> String { plain.string(from: date) }
}
