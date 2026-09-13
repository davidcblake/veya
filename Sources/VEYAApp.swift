import PPCore
import PPDesign
import SwiftUI

/// VEYA — trips, planned together and kept afterwards.
///
/// One trip is one record that moves through three states: planned, lived,
/// remembered. Everyone on the trip sees the same one.
@main
struct VEYAApp: App {
    @State private var session = Session()

    var body: some Scene {
        WindowGroup {
            content
                .ppTheme(.plugAndPlay)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .notConfigured:
            NotConfiguredScreen()
        case .signedOut, .signingIn:
            SignInScreen(session: session)
        case .signedIn(let userID, let token):
            if let backend = session.backend {
                SignedInScreen(backend: backend, userID: userID, token: token) {
                    session.signOut()
                }
            } else {
                NotConfiguredScreen()
            }
        }
    }
}

/// Holds the trip store for as long as somebody is signed in.
struct SignedInScreen: View {
    let backend: Backend
    let userID: String
    let token: String
    let onSignOut: () -> Void

    @State private var store: TripStore?

    var body: some View {
        Group {
            if let store {
                TripsScreen(store: store, onSignOut: onSignOut)
            } else {
                ProgressView()
            }
        }
        .task {
            guard store == nil else { return }
            let store = TripStore(backend: backend, userID: userID, token: token)
            self.store = store
            await store.load()
        }
    }
}
