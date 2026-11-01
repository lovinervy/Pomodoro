import SwiftUI
import PomodoroCore

/// Выпадающая панель меню-бара.
struct MenuBarView: View {
    @EnvironmentObject private var vm: TimerViewModel
    @EnvironmentObject private var overlay: OverlayController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(phaseColor)
                    .frame(width: 8, height: 8)
                Text(vm.phaseTitle)
                    .font(.headline)
                Spacer()
                Text(vm.remainingText)
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
            }

            Text("\(vm.cycleName) · помодоро \(vm.engine.currentRound)/\(vm.engine.totalRounds)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button(vm.isRunning ? "Пауза" : "Старт") { vm.toggleStartPause() }
                Button("Пропуск") { vm.skip() }
                Button("Сброс") { vm.reset() }
            }

            Divider()

            Toggle("Плавающий оверлей", isOn: $overlay.isEnabled)

            Divider()

            Button("Открыть окно") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Выйти") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 260)
    }

    private var phaseColor: Color {
        switch vm.engine.currentPhase.kind {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
