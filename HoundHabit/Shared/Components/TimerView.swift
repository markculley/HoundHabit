import SwiftUI

// MARK: - TimerDuration

enum TimerDuration: CaseIterable, Identifiable {
    case fiveSeconds
    case thirtySeconds
    case oneMinute
    case twoMinutes
    case fiveMinutes

    var label: String {
        switch self {
        case .fiveSeconds:   return "5 sec"
        case .thirtySeconds: return "30 sec"
        case .oneMinute:     return "1 min"
        case .twoMinutes:    return "2 min"
        case .fiveMinutes:   return "5 min"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .fiveSeconds:   return 5
        case .thirtySeconds: return 30
        case .oneMinute:     return 60
        case .twoMinutes:    return 120
        case .fiveMinutes:   return 300
        }
    }

    var id: Self { self }
}

// MARK: - Timer Logic Helpers

func timerFormatTime(_ remaining: TimeInterval) -> String {
    let secs = Int(ceil(remaining))
    let minutes = secs / 60
    let seconds = secs % 60
    if minutes > 0 {
        return String(format: "%d:%02d", minutes, seconds)
    } else {
        return String(format: ":%02d", seconds)
    }
}

func timerCalculateProgress(remaining: TimeInterval, total: TimeInterval) -> Double {
    guard total > 0 else { return 0 }
    return min(max((total - remaining) / total, 0), 1)
}

// MARK: - TimerViewModel

@Observable
@MainActor
final class TimerViewModel {
    enum TimerState { case idle, running, paused, complete }

    var selectedDuration: TimerDuration = .thirtySeconds
    var state: TimerState = .idle
    var remaining: TimeInterval = 30

    private var timer: Timer?

    var totalSeconds: TimeInterval { selectedDuration.seconds }

    var progress: Double {
        timerCalculateProgress(remaining: remaining, total: totalSeconds)
    }

    var displayTime: String {
        timerFormatTime(remaining)
    }


    func start() {
        guard state == .idle || state == .paused else { return }
        state = .running
        HapticManager.medium()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func pause() {
        guard state == .running else { return }
        timer?.invalidate()
        timer = nil
        state = .paused
        HapticManager.medium()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remaining = totalSeconds
        HapticManager.light()
    }

    func selectDuration(_ duration: TimerDuration) {
        guard state == .idle else { return }
        selectedDuration = duration
        remaining = duration.seconds
    }

    // Internal for testability
    func tick() {
        remaining -= 0.1
        if remaining <= 0 {
            remaining = 0
            timer?.invalidate()
            timer = nil
            state = .complete
            HapticManager.timerComplete()
        }
    }
}

// MARK: - TimerView

struct TimerView: View {
    var viewModel: TimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Duration picker — disabled when not idle
            Picker("Duration", selection: Binding(
                get: { viewModel.selectedDuration },
                set: { viewModel.selectDuration($0) }
            )) {
                ForEach(TimerDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.segmented)
            .buttonStyle(.borderless)
            .disabled(viewModel.state != .idle)

            // Progress ring + time label
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        viewModel.state == .complete ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)

                if viewModel.state == .complete {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Done!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text(viewModel.displayTime)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(viewModel.state == .paused ? .secondary : .primary)
                }
            }
            .frame(width: 140, height: 140)

            // Controls
            HStack(spacing: 24) {
                // Start / Pause
                Button {
                    if viewModel.state == .running {
                        viewModel.pause()
                    } else {
                        viewModel.start()
                    }
                } label: {
                    Image(systemName: viewModel.state == .running ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(viewModel.state == .complete ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.state == .complete)

                // Reset
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(viewModel.state == .idle ? AnyShapeStyle(Color.secondary.opacity(0.4)) : AnyShapeStyle(Color.secondary))
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.state == .idle)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    Form {
        Section("Training Timer") {
            TimerView(viewModel: TimerViewModel())
        }
    }
}
