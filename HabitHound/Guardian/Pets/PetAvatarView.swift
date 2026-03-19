import SwiftUI

/// Circular pet photo — shows AsyncImage if a URL is provided, otherwise a paw placeholder.
struct PetAvatarView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        ProgressView()
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(Color(.secondarySystemFill), in: Circle())
    }

    private var placeholder: some View {
        Image(systemName: "pawprint.fill")
            .resizable()
            .scaledToFit()
            .padding(size * 0.25)
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    HStack(spacing: 20) {
        PetAvatarView(url: nil, size: 60)
        PetAvatarView(url: nil, size: 44)
        PetAvatarView(url: nil, size: 32)
    }
    .padding()
}
