import Foundation

/// События, которые движок сообщает наружу (UI, уведомления, статистика).
public enum TimerEvent: Equatable, Sendable {
    /// Фаза завершилась, началась следующая.
    case phaseCompleted(finished: Phase, started: Phase)
    /// Последняя фаза неповторяющегося цикла завершилась — всё, стоп.
    case cycleFinished(Cycle)
}

public enum TimerState: Equatable, Sendable {
    /// Не запущен, стоим в начале текущей фазы.
    case idle
    case running
    case paused
}

/// Движок помодоро-таймера. Чистая конечная машина:
/// не знает ни о таймерах, ни о часах — время приходит снаружи через `tick(now:)`,
/// поэтому движок полностью тестируем и не тратит ресурсы сам по себе.
public struct TimerEngine: Sendable {

    public private(set) var cycle: Cycle
    public private(set) var state: TimerState = .idle
    public private(set) var phaseIndex: Int = 0
    /// Сколько секунд осталось в текущей фазе.
    public private(set) var remaining: TimeInterval
    /// Сколько полных кругов цикла пройдено в текущей сессии.
    public private(set) var completedLaps: Int = 0

    /// Момент (в прошлом), когда текущий отрезок работы был запущен —
    /// нужен, чтобы считать остаток от реальных часов, а не от частоты тиков.
    private var segmentStart: Date?
    /// Остаток, зафиксированный на момент паузы/старта сегмента.
    private var segmentBaseRemaining: TimeInterval

    public init(cycle: Cycle) {
        precondition(!cycle.phases.isEmpty, "Цикл не может быть пустым")
        self.cycle = cycle
        self.remaining = cycle.phases[0].duration
        self.segmentBaseRemaining = cycle.phases[0].duration
    }

    public var currentPhase: Phase { cycle.phases[phaseIndex] }
    public var isIdle: Bool { state == .idle }

    /// Прогресс текущей фазы 0...1 (для кольца/полоски в UI).
    public var phaseProgress: Double {
        let total = currentPhase.duration
        guard total > 0 else { return 1 }
        return min(max(1 - remaining / total, 0), 1)
    }

    /// Номер текущего «помодоро» (фокуса) внутри круга, 1-based.
    public var currentRound: Int {
        cycle.phases[...phaseIndex].filter { $0.kind == .focus }.count
    }

    /// Сколько фокусов всего в одном круге цикла.
    public var totalRounds: Int {
        cycle.phases.filter { $0.kind == .focus }.count
    }

    // MARK: - Управление

    public mutating func start(at now: Date) {
        guard state != .running else { return }
        state = .running
        segmentStart = now
        segmentBaseRemaining = remaining
    }

    public mutating func pause(at now: Date) {
        guard state == .running else { return }
        _ = tick(now: now) // досчитать остаток до момента паузы
        state = .paused
        segmentStart = nil
    }

    /// Сброс к началу текущей фазы (не всего цикла).
    public mutating func reset() {
        state = .idle
        segmentStart = nil
        remaining = currentPhase.duration
        segmentBaseRemaining = remaining
    }

    /// Перемотать в самое начало цикла.
    public mutating func restartCycle() {
        phaseIndex = 0
        completedLaps = 0
        reset()
    }

    /// Пропустить текущую фазу и перейти к следующей (без событий завершения).
    @discardableResult
    public mutating func skip() -> TimerEvent? {
        let finished = currentPhase
        guard let next = advanceIndex() else {
            state = .idle
            segmentStart = nil
            return .cycleFinished(cycle)
        }
        remaining = next.duration
        segmentBaseRemaining = remaining
        if state == .running { segmentStart = segmentStart ?? Date() }
        return .phaseCompleted(finished: finished, started: next)
    }

    /// Сменить цикл на лету (сбрасывает позицию в начало нового цикла).
    public mutating func setCycle(_ newCycle: Cycle) {
        precondition(!newCycle.phases.isEmpty, "Цикл не может быть пустым")
        cycle = newCycle
        restartCycle()
    }

    // MARK: - Тик

    /// Единственный источник движения времени. Вызывается извне (Timer/дисплей-линк),
    /// `now` — реальные часы. Движок сам ничего не планирует и не жрёт CPU.
    @discardableResult
    public mutating func tick(now: Date) -> TimerEvent? {
        guard state == .running, let start = segmentStart else { return nil }
        remaining = max(segmentBaseRemaining - now.timeIntervalSince(start), 0)
        guard remaining <= 0 else { return nil }

        let finished = currentPhase
        guard let next = advanceIndex() else {
            state = .idle
            segmentStart = nil
            return .cycleFinished(cycle)
        }
        // Переносим «перебор» времени в следующую фазу, чтобы не копить дрейф.
        let overshoot = now.timeIntervalSince(start) - finished.duration
        remaining = max(next.duration - max(overshoot, 0), 0)
        segmentBaseRemaining = remaining
        segmentStart = now
        return .phaseCompleted(finished: finished, started: next)
    }

    // MARK: - Внутреннее

    /// Сдвиг индекса на следующую фазу. Возвращает nil, если цикл кончился и не повторяется.
    private mutating func advanceIndex() -> Phase? {
        if phaseIndex + 1 < cycle.phases.count {
            phaseIndex += 1
            return cycle.phases[phaseIndex]
        }
        if cycle.repeats {
            phaseIndex = 0
            completedLaps += 1
            return cycle.phases[0]
        }
        return nil
    }
}
