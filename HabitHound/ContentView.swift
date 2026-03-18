import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Habit Hound")
                .font(.largeTitle)
                .bold()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
