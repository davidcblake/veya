import Foundation
import Observation

/// Every trip this person is on — the one being planned, the one they are on,
/// and every one they have finished.
@MainActor
@Observable
final class TripStore {
    private(set) var trips: [TripRecord] = []
    private(set) var isLoading = false
    private(set) var failure: BackendFailure?

    let backend: Backend
    let token: String
    private let userID: String

    init(backend: Backend, userID: String, token: String) {
        self.backend = backend
        self.userID = userID
        self.token = token
    }

    var current: [TripRecord] { trips.filter { !$0.isArchived } }
    var archived: [TripRecord] { trips.filter(\.isArchived) }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            trips = try await backend.rows(
                from: "trips",
                query: [URLQueryItem(name: "order", value: "start_date.desc.nullslast")],
                as: TripRecord.self,
                token: token
            )
            failure = nil
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't load your trips.", logMessage: "\(error)")
        }
    }

    /// Make a trip, and join it.
    ///
    /// **Both halves matter.** Row level security decides what you can see by
    /// membership, so a trip created without a membership row would vanish the
    /// moment it was written — visible to nobody, including whoever just made
    /// it.
    func create(name: String, destination: String, startDate: Date, endDate: Date) async {
        do {
            let created: [TripRecord] = try await backend.insert(
                NewTrip(
                    name: name,
                    destination: destination,
                    startDate: TripDates.text(from: startDate),
                    endDate: TripDates.text(from: endDate),
                    createdBy: userID
                ),
                into: "trips",
                token: token
            )
            guard let trip = created.first else { return }

            let _: [NewMemberEcho] = try await backend.insert(
                NewMember(tripId: trip.id, userId: userID, role: "owner", displayName: ""),
                into: "trip_members",
                token: token
            )
            await load()
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't make that trip.", logMessage: "\(error)")
        }
    }

    /// Wind a trip down, or take it back out of the drawer.
    ///
    /// Archiving never deletes. A finished trip is the thing you keep.
    func setStatus(_ status: String, for trip: TripRecord) async {
        do {
            try await backend.update(
                TripStatusChange(status: status),
                in: "trips",
                matching: [URLQueryItem(name: "id", value: "eq.\(trip.id)")],
                token: token
            )
            await load()
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't change that trip.", logMessage: "\(error)")
        }
    }
}

/// PostgREST hands back the row it wrote; nothing here needs it.
private struct NewMemberEcho: Decodable {}

/// Postgres date columns are `2026-09-22`, and nothing else.
enum TripDates {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        // Fixed, not the phone's locale: this is a wire format, and a phone set
        // to a Japanese calendar must still send the date Postgres expects.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func text(from date: Date) -> String { formatter.string(from: date) }
    static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        return formatter.date(from: text)
    }
}
