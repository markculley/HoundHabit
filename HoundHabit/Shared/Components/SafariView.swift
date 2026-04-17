import SwiftUI
import SafariServices

/// Wraps SFSafariViewController for use as a SwiftUI sheet.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    SafariView(url: URL(string: "https://apple.com")!)
}
