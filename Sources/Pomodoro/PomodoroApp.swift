import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var vm: TimerViewModel
    @StateObject private var overlay: OverlayController
    @AppStorage(AppSettings.showTimeInMenuBar) private var showTimeInMenuBar = true

    init() {
        let viewModel = TimerViewModel()
        _vm = StateObject(wrappedValue: viewModel)
        _overlay = StateObject(wrappedValue: OverlayController(vm: viewModel))

        // Отладка оверлеев: POMODORO_DEMO=1 запускает таймер сразу.
        if ProcessInfo.processInfo.environment["POMODORO_DEMO"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.toggleStartPause()
            }
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(vm)
        }
        .windowResizability(.contentSize)

        WindowGroup(id: "tasks") {
            TasksView(vm: vm)
        }
        .windowResizability(.contentMinSize)

        WindowGroup(id: "stats") {
            StatsView(vm: vm)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(vm)
                .environmentObject(overlay)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarIcon)
                if showTimeInMenuBar && !vm.isIdle {
                    Text(vm.remainingText)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private var menuBarIcon: String {
        switch vm.engine.currentPhase.kind {
        case .focus: return "timer"
        case .shortBreak, .longBreak: return "cup.and.saucer"
        }
    }
}
