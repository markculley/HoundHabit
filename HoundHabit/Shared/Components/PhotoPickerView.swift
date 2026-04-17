import SwiftUI
import PhotosUI

/// Reusable photo picker. Binds to `imageData: Data?` and shows a preview when selected.
struct PhotoPickerView: View {
    @Binding var imageData: Data?

    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: Image?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            if let previewImage {
                previewImage
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 3)
                            .padding(8)
                    }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Tap to select a photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                imageData = data
                previewImage = Image(uiImage: uiImage)
            }
        }
    }
}

#Preview {
    @Previewable @State var data: Data? = nil
    PhotoPickerView(imageData: $data)
        .padding()
}
