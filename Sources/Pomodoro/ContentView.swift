import SwiftUI
import PomodoroCore

struct ContentView: View {
    @EnvironmentObject private var vm: TimerViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showEditor = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text(vm.cycleName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openWindow(id: "tasks")
                } label: {
                    Image(systemName: "checklist")
                }
                .buttonStyle(.borderless)
                .help("Задачи")
                Button {
                    openWindow(id: "stats")
                } label: {
                    Image(systemName: "chart.bar")
                }
                .buttonStyle(.borderless)
                .help("Статистика")
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Редактор циклов")
            }

            Text(vm.phaseTitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let taskTitle = vm.activeTaskTitle {
                Label(taskTitle, systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: vm.engine.phaseProgress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: vm.engine.phaseProgress)
                Text(vm.remainingText)
                    .font(.system(size: 44, weight: .light, design: .monospaced))
            }
            .frame(width: 180, height: 180)

            Text("Помодоро \(vm.engine.currentRound) из \(vm.engine.totalRounds)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let next = vm.nextPhaseText {
                Text(next)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                Button(vm.isRunning ? "Пауза" : (vm.isIdle ? "Старт" : "Дальше")) {
                    vm.toggleStartPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Сброс", action: vm.reset)
                Button("Пропуск", action: vm.skip)
            }
        }
        .padding(28)
        .frame(minWidth: 320, minHeight: 400)
        .sheet(isPresented: $showEditor) {
            CycleEditorView(vm: vm)
        }
    }

    private var phaseColor: Color {
        switch vm.engine.currentPhase.kind {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
