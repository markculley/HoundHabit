import SwiftUI

struct ResourceDetailView: View {
    let resource: Resource

    @State private var showSafari = false

    var body: some View {
        List {
            switch resource.kind {
            case .photo:
                if let urlStr = resource.url, let url = URL(string: urlStr) {
                    Section {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                            case .failure:
                                Label("Failed to load image", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView().frame(maxWidth: .infinity)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }
                if let body = resource.body, !body.isEmpty {
                    Section("Notes") { Text(body) }
                }

            case .url:
                if let urlStr = resource.url {
                    Section("Link") {
                        Button {
                            showSafari = true
                        } label: {
                            Label(urlStr, systemImage: "arrow.up.right.square")
                                .lineLimit(2)
                        }
                    }
                }
                if let body = resource.body, !body.isEmpty {
                    Section("Notes") { Text(body) }
                }

            case .note:
                if let body = resource.body {
                    Section("Note") { Text(body) }
                }
            }

            Section {
                Text("Added \(resource.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .navigationTitle(resource.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showSafari) {
            if let urlStr = resource.url, let url = URL(string: urlStr) {
                SafariView(url: url)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResourceDetailView(resource: Resource(
            id: UUID(),
            ownerId: UUID(),
            addedById: UUID(),
            guardianId: UUID(),
            kind: .note,
            url: nil,
            body: "Practice recall in the backyard for 5 minutes before meals.",
            title: "Trainer's tip",
            createdAt: Date()
        ))
    }
}
