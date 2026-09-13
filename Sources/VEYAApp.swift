import PPCore
import PPData
import PPDesign
import SwiftData
import SwiftUI

/// VEYA — the travel companion for a family trip.
///
/// **Everything here works with the phone in airplane mode**, because there is
/// nothing in it that does not. The app makes no network calls at all: no map
/// tiles, no prices, no weather, no sign-in. That is the promise the whole
/// foundation was built for, and the one this app is used on a street in a
/// foreign city to keep.
@main
struct VEYAApp: App {
    /// The trip, or the reason it could not be opened.
    ///
    /// Not a `try!`. A store that fails to open looks, to the person holding
    /// the phone, exactly like an app that lost everything they put in it — so
    /// the failure gets a screen that says what happened.
    private let store: Result<ModelContainer, any Error>

    init() {
        store = Result {
            // On this device only for version one. The CloudKit provider exists
            // and has never run on a device; turning it on is one line, and it
            // waits until the container is entitled and somebody has watched it
            // work. See docs/roadmap.md.
            try PPModelStore.container(
                for: [Trip.self, PlanItem.self, Place.self, Essential.self],
                kind: .thisDeviceOnly
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            content
                .ppTheme(.plugAndPlay)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store {
        case .success(let container):
            RootScreen()
                .modelContainer(container)
        case .failure(let error):
            PPErrorView(error: CouldNotOpenTheTrip(logMessage: String(describing: error)))
        }
    }
}

/// The two voices `PPCore` asks for: one a person reads, one the log keeps.
struct CouldNotOpenTheTrip: PPError {
    var userMessage: String {
        "VEYA couldn't open your trip on this phone."
    }

    let logMessage: String
}

/// The trip, or the screen that makes one.
struct RootScreen: View {
    @Query private var trips: [Trip]

    var body: some View {
        if let trip = trips.first {
            TripTabs(trip: trip)
        } else {
            TripSetupScreen()
        }
    }
}

struct TripTabs: View {
    let trip: Trip

    var body: some View {
        TabView {
            TodayScreen(trip: trip)
                .tabItem { Label("Today", systemImage: "sun.horizon") }
            ItineraryScreen(trip: trip)
                .tabItem { Label("Itinerary", systemImage: "calendar") }
            PlacesScreen(trip: trip)
                .tabItem { Label("Places", systemImage: "mappin.and.ellipse") }
            EssentialsScreen(trip: trip)
                .tabItem { Label("Essentials", systemImage: "key") }
        }
    }
}
