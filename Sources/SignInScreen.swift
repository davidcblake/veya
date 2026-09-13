import AuthenticationServices
import PPDesign
import SwiftUI

/// One tap, and then never again on this phone.
struct SignInScreen: View {
    @Environment(\.ppTheme) private var theme
    let session: Session

    var body: some View {
        VStack(spacing: PPSpacing.large) {
            Spacer()
            VStack(spacing: PPSpacing.small) {
                Text("VEYA")
                    .ppText(.screenTitle)
                    .foregroundStyle(theme.textPrimary)
                Text("Your trips, everyone on the same page.")
                    .ppText(.body)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let failure = session.failure {
                Text(failure.userMessage)
                    .ppText(.body)
                    .foregroundStyle(theme.danger)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if case .signingIn = session.state {
                ProgressView()
                    .frame(height: PPSpacing.minimumTapTarget)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    // A name, once, so other people on the trip see who added
                    // what. Apple only ever gives it on the first sign-in.
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    Task { await session.finishSigningIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: PPSpacing.minimumTapTarget)
            }

            Text("Signing in is how everyone on a trip sees the same itinerary.")
                .ppText(.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PPSpacing.screenMargin)
    }
}

/// The app was shipped without its backend settings. Somebody has to be told.
struct NotConfiguredScreen: View {
    @Environment(\.ppTheme) private var theme

    var body: some View {
        PPEmptyState(
            symbolName: "gearshape.badge.xmark",
            title: "VEYA isn't configured",
            message: "This build has no SUPABASE_URL or SUPABASE_ANON_KEY. It needs rebuilding with them set in project.yml."
        )
        .foregroundStyle(theme.textPrimary)
    }
}
