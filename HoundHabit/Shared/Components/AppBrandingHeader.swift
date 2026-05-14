import SwiftUI

/// App-branding header — the Hound Habit icon + name, with an optional subtitle.
/// Used at the top of the guardian dashboard (no subtitle) and the trainer's
/// Guardians page (subtitle "Guardians", rendered smaller than the brand line).
struct AppBrandingHeader: View {
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                Text("Hound Habit")
                    .font(.largeTitle.bold())
            }
            if let subtitle {
                Text(subtitle)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 28) {
        AppBrandingHeader()
        AppBrandingHeader(subtitle: "Guardians")
    }
    .padding()
}
