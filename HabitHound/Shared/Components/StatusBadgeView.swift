import SwiftUI

/// A small coloured circle representing a training session status.
struct StatusBadgeView: View {
    let status: TrainingStatus
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(TrainingStatus.allCases, id: \.self) { status in
            VStack(spacing: 4) {
                StatusBadgeView(status: status, size: 24)
                Text(status.shortLabel).font(.caption)
            }
        }
    }
    .padding()
}
