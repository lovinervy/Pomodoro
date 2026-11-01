import SwiftUI
import Combine
import PomodoroCore

/// ViewModel: гоняет движок по системному таймеру 4 раза в секунду.
/// Пауза таймера = ноль CPU; сам движок остаётся чистым и тестируемым.
@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var engine: TimerEngine
    @Published private(set) var lastEvent: TimerEvent?

    let store: CycleStore
    let taskStore: TaskStore
    let sessionLog: SessionLogStore

    /// Триггер для перерисовки при изменении пресетов/задач.
    @Published private(set) var storeVersion = 0

    private let notifications: NotificationsManager?
    private var ticker: AnyCancellable?

    /// Когда началась текущая фаза (для журнала сессий).
    private var phaseStartedAt: Date?

    init(store: CycleStore = .makeDefault(),
         taskStore: TaskStore = .makeDefault(),
         sessionLog: SessionLogStore = .makeDefault(),
         notifications: NotificationsManager? = nil) {
        self.store = store
        self.taskStore = taskStore
        self.sessionLog = sessionLog
        self.notifications = notifications ?? NotificationsManager()
        self.engine = TimerEngine(cycle: store.selectedCycle)
    }

    // MARK: - Отображение

    var remainingText: String {
        let total = Int(engine.remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var phaseTitle: String { engine.currentPhase.displayTitle }

    var cycleName: String { engine.cycle.name }

    var activeTaskTitle: String? { taskStore.selectedTask?.title }

    /// «Далее: обед 30 мин» — подсказка о следующей фазе.
    var nextPhaseText: String? {
        let phases = engine.cycle.phases
        let nextIndex = engine.phaseIndex + 1
        let next: Phase?
        if nextIndex < phases.count {
            next = phases[nextIndex]
        } else if engine.cycle.repeats {
            next = phases.first
        } else {
            next = nil
        }
        guard let next else { return nil }
        return "Далее: \(next.displayTitle) \(Int(next.duration / 60)) мин"
    }

    var isRunning: Bool { engine.state == .running }
    var isIdle: Bool { engine.state == .idle }

    // MARK: - Управление таймером

    func toggleStartPause() {
        if isRunning {
            engine.pause(at: Date())
            stopTicker()
        } else {
            engine.start(at: Date())
            if phaseStartedAt == nil { phaseStartedAt = Date() }
            startTicker()
        }
    }

    func reset() {
        engine.reset()
        stopTicker()
        phaseStartedAt = nil
    }

    func skip() {
        let phase = engine.currentPhase
        let startedAt = phaseStartedAt
        let event = engine.skip()
        recordSkip(phase: phase, startedAt: startedAt)
        handle(event)
        if engine.isIdle {
            stopTicker()
            phaseStartedAt = nil
        } else {
            phaseStartedAt = Date()
        }
    }

    // MARK: - Циклы

    func selectCycle(id: UUID) {
        store.select(id)
        stopTicker()
        engine.setCycle(store.selectedCycle)
        phaseStartedAt = nil
        storeVersion += 1
    }

    /// Вызывается редактором после любого изменения пресетов.
    func storeDidChange() {
        // Если правили активный цикл — перечитываем его (таймер сбрасывается в начало).
        engine.setCycle(store.selectedCycle)
        stopTicker()
        phaseStartedAt = nil
        storeVersion += 1
    }

    // MARK: - Задачи

    func selectTask(id: UUID?) {
        taskStore.select(id)
        storeVersion += 1
    }

    /// Вызывается списком задач после любого изменения.
    func tasksDidChange() {
        storeVersion += 1
    }

    // MARK: - Журнал

    private func recordSkip(phase: Phase, startedAt: Date?) {
        guard let startedAt else { return } // фаза не была запущена — нечего писать
        sessionLog.append(SessionRecord(
            startedAt: startedAt, endedAt: Date(),
            taskID: taskStore.selectedTaskID, taskTitle: taskStore.selectedTask?.title,
            phaseKind: phase.kind, phaseTitle: phase.displayTitle,
            plannedSeconds: Int(phase.duration),
            actualSeconds: Int(Date().timeIntervalSince(startedAt)),
            outcome: .skipped
        ))
    }

    private func recordCompletion(phase: Phase) {
        guard let startedAt = phaseStartedAt else { return }
        sessionLog.append(SessionRecord(
            startedAt: startedAt, endedAt: Date(),
            taskID: taskStore.selectedTaskID, taskTitle: taskStore.selectedTask?.title,
            phaseKind: phase.kind, phaseTitle: phase.displayTitle,
            plannedSeconds: Int(phase.duration),
            actualSeconds: Int(phase.duration),
            outcome: .completed
        ))
        if phase.kind == .focus {
            taskStore.incrementCompletedForSelected()
            storeVersion += 1
        }
        phaseStartedAt = Date() // следующая фаза начинается сейчас
    }

    // MARK: - События движка

    private func handle(_ event: TimerEvent?) {
        guard let event else { return }
        lastEvent = event
        switch event {
        case .phaseCompleted(let finished, let started):
            recordCompletion(phase: finished)
            notifications?.phaseCompleted(finished: finished, started: started)
            // Если автопереход выключен — встаём на паузу в начале новой фазы.
            if !AppSettings.bool(AppSettings.autoStartNextPhase) {
                engine.pause(at: Date())
                stopTicker()
            }
        case .cycleFinished(let cycle):
            notifications?.cycleFinished(cycle)
            phaseStartedAt = nil
        }
    }

    // MARK: - Тикер

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self else { return }
                self.handle(self.engine.tick(now: now))
                if self.engine.isIdle { self.stopTicker() }
            }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
