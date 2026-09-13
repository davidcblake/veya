import Foundation
import PPCore

/// Where VEYA's settings come from.
///
/// Read through `PPCore`'s `ConfigurationSource` rather than hard-coded, so the
/// values live in `Info.plist` (generated from `project.yml`) and a test can
/// hand in different ones.
enum ConfigKey {
    static let supabaseURL: ConfigurationKey = "SUPABASE_URL"
    static let supabaseAnonKey: ConfigurationKey = "SUPABASE_ANON_KEY"
}

/// What the app needs to reach its backend.
///
/// **The anon key is meant to be in the app.** It identifies the project, not a
/// person; row level security is what actually protects the data, and every
/// policy in `supabase/0001_init.sql` asks the same question — are you a member
/// of this trip. A key that let somebody read another family's itinerary would
/// be a broken policy, not a leaked secret.
struct BackendConfiguration: Sendable {
    let url: URL
    let anonKey: String

    /// `nil` when the app was built without the values filled in, which is a
    /// state worth showing a screen about rather than crashing on.
    init?(source: any ConfigurationSource = BundleConfiguration()) {
        let urlText = source.string(ConfigKey.supabaseURL, default: "")
        let key = source.string(ConfigKey.supabaseAnonKey, default: "")
        guard !urlText.isEmpty, !key.isEmpty, let url = URL(string: urlText) else { return nil }
        self.url = url
        self.anonKey = key
    }
}
