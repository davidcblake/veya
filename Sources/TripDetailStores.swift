import Foundation
import Observation

/// Where you are sleeping, night by night.
///
/// The single most looked-up thing on a trip, and the one you need when the
/// signal is worst — a taxi driver asking for an address at eleven at night.
@MainActor
@Observable
final class StayStore {
    private(set) var stays: [StayRecord] = []
    private(set) var failure: BackendFailure?

    private let trip: TripRecord
    private let backend: Backend
    private let token: String

    init(trip: TripRecord, backend: Backend, token: String) {
        self.trip = trip
        self.backend = backend
        self.token = token
    }

    func load() async {
        do {
            stays = try await backend.rows(
                from: "stays",
                query: [
                    URLQueryItem(name: "trip_id", value: "eq.\(trip.id)"),
                    URLQueryItem(name: "order", value: "check_in.asc.nullslast"),
                ],
                as: StayRecord.self,
                token: token
            )
            failure = nil
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't load where you're staying.", logMessage: "\(error)")
        }
    }

    func add(city: String, name: String, address: String, checkIn: Date, checkOut: Date, detail: String) async {
        do {
            let _: [StayRecord] = try await backend.insert(
                NewStay(
                    tripId: trip.id,
                    city: city,
                    name: name,
                    checkIn: TripDates.text(from: checkIn),
                    checkOut: TripDates.text(from: checkOut),
                    address: address,
                    detail: detail
                ),
                into: "stays",
                token: token
            )
            await load()
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't save that.", logMessage: "\(error)")
        }
    }

    func delete(_ stay: StayRecord) async {
        do {
            try await backend.delete(
                from: "stays",
                matching: [URLQueryItem(name: "id", value: "eq.\(stay.id)")],
                token: token
            )
            await load()
        } catch { failure = BackendFailure(userMessage: "Couldn't remove that.", logMessage: "\(error)") }
    }
}

struct NewStay: Encodable, Sendable {
    var tripId: String
    var city: String
    var name: String
    var checkIn: String?
    var checkOut: String?
    var address: String
    var detail: String
}

/// What still has to be booked before anybody leaves.
@MainActor
@Observable
final class TodoStore {
    private(set) var todos: [TodoRecord] = []
    private(set) var failure: BackendFailure?

    private let trip: TripRecord
    private let backend: Backend
    private let token: String

    init(trip: TripRecord, backend: Backend, token: String) {
        self.trip = trip
        self.backend = backend
        self.token = token
    }

    var openCount: Int { todos.filter { !$0.done }.count }

    func load() async {
        do {
            todos = try await backend.rows(
                from: "todos",
                query: [
                    URLQueryItem(name: "trip_id", value: "eq.\(trip.id)"),
                    URLQueryItem(name: "order", value: "position.asc"),
                ],
                as: TodoRecord.self,
                token: token
            )
            failure = nil
        } catch let error as BackendFailure {
            failure = error
        } catch {
            failure = BackendFailure(userMessage: "Couldn't load the list.", logMessage: "\(error)")
        }
    }

    func add(title: String, url: String) async {
        do {
            let _: [TodoRecord] = try await backend.insert(
                NewTodo(tripId: trip.id, title: title, url: url, position: todos.count),
                into: "todos",
                token: token
            )
            await load()
        } catch { failure = BackendFailure(userMessage: "Couldn't add that.", logMessage: "\(error)") }
    }

    func setDone(_ done: Bool, for todo: TodoRecord) async {
        do {
            try await backend.update(
                TodoDoneChange(done: done),
                in: "todos",
                matching: [URLQueryItem(name: "id", value: "eq.\(todo.id)")],
                token: token
            )
            await load()
        } catch { failure = BackendFailure(userMessage: "Couldn't change that.", logMessage: "\(error)") }
    }

    func delete(_ todo: TodoRecord) async {
        do {
            try await backend.delete(
                from: "todos",
                matching: [URLQueryItem(name: "id", value: "eq.\(todo.id)")],
                token: token
            )
            await load()
        } catch { failure = BackendFailure(userMessage: "Couldn't remove that.", logMessage: "\(error)") }
    }
}

struct NewTodo: Encodable, Sendable {
    var tripId: String
    var title: String
    var url: String
    var position: Int
}

struct TodoDoneChange: Encodable, Sendable {
    var done: Bool
}
