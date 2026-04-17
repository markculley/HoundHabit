import Foundation
import Supabase

let supabase: SupabaseClient = {
    guard
        let url = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
        let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
        let supabaseURL = URL(string: url)
    else {
        fatalError("Supabase credentials missing from Info.plist. Check Secrets.xcconfig.")
    }
    return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
}()
