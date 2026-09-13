import AuthenticationServices
import Foundation
import Observation

/// Who is using the app, and the token that proves it.
///
/// One sign-in, with Apple, and then never again on this phone — the token is
/// kept in the Keychain and read back on launch.
@MainActor
@Observable
final class Session {
    enum State: Equatable {
        /// The app was built without its backend settings filled in. A screen,
        /// not a crash, because it is a build mistake somebody has to be told
        /// about plainly.
        case notConfigured
        case signedOut
        case signingIn
        case signedIn(userID: String, token: String)
    }

    private static let tokenAccount = "veya.accessToken"
    private static let userAccount = "veya.userID"

    let backend: Backend?
    private(set) var state: State
    private(set) var failure: BackendFailure?

    init() {
        guard let configuration = BackendConfiguration() else {
            backend = nil
            state = .notConfigured
            return
        }
        backend = Backend(configuration: configuration)
        if let token = Keychain.read(Self.tokenAccount), let userID = Keychain.read(Self.userAccount) {
            state = .signedIn(userID: userID, token: token)
        } else {
            state = .signedOut
        }
    }

    /// What the Sign in with Apple button hands back.
    func finishSigningIn(_ result: Result<ASAuthorization, any Error>) async {
        failure = nil
        guard let backend else { return }

        let identityToken: String
        switch result {
        case .failure(let error):
            // Cancelling is not a failure worth shouting about — somebody
            // changed their mind, which is allowed.
            if (error as? ASAuthorizationError)?.code == .canceled {
                state = .signedOut
                return
            }
            failure = BackendFailure(
                userMessage: "Signing in didn't finish. Try again.",
                logMessage: "Sign in with Apple failed: \(error)"
            )
            state = .signedOut
            return
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8) else {
                failure = BackendFailure(
                    userMessage: "Signing in didn't finish. Try again.",
                    logMessage: "Apple returned no identity token"
                )
                state = .signedOut
                return
            }
            identityToken = token
        }

        state = .signingIn
        do {
            let session = try await backend.signIn(appleIdentityToken: identityToken)
            Keychain.save(session.accessToken, for: Self.tokenAccount)
            Keychain.save(session.user.id, for: Self.userAccount)
            state = .signedIn(userID: session.user.id, token: session.accessToken)
        } catch let error as BackendFailure {
            failure = error
            state = .signedOut
        } catch {
            failure = BackendFailure(
                userMessage: "Signing in didn't finish. Try again.",
                logMessage: "\(error)"
            )
            state = .signedOut
        }
    }

    func signOut() {
        Keychain.remove(Self.tokenAccount)
        Keychain.remove(Self.userAccount)
        state = .signedOut
    }
}
