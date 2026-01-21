import Foundation
import Supabase

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // TODO: Replace these placeholders with your real project values.
        let url = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!
        let key = "YOUR_ANON_PUBLIC_KEY"

        // Default options are fine for most apps; you can customize if needed.
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
