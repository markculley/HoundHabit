import Foundation

/// App-wide error surface. Inject into the environment from HoundHabitApp;
/// ContentView presents an alert when `message` is non-nil.
/// Individual ViewModels handle routine errors locally with their own
/// `errorMessage`. Use ErrorStore only for errors that have no local owner
/// (e.g. background auth failures, service calls outside a ViewModel).
@Observable
class ErrorStore {
    var message: String?

    func report(_ error: Error) {
        message = error.localizedDescription
    }

    func report(_ message: String) {
        self.message = message
    }
}
