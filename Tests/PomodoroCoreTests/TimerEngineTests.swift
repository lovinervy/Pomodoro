import Testing
import Foundation
@testable import PomodoroCore

/// Маленький цикл в секундах: фокус 3с, перерыв 2с, фокус 4с.
private func makeEngine(repeats: Bool = true) -> TimerEngine {
    let cycle = Cycle(name: "test", phases: [
        Phase(kind: .focus, duration: 3),
        Phase(kind: .shortBreak, duration: 2),
        Phase(kind: .focus, duration: 4),
    ], repeats: repeats)
    return TimerEngine(cycle: cycle)
}

@Test func initialState() {
    let engine = makeEngine()
    #expect(engine.state == .idle)
    #expect(engine.remaining == 3)
    #expect(engine.currentPhase.kind == .focus)
    #expect(engine.phaseIndex == 0)
}

@Test func tickCountsDownFromRealClock() {
    var engine = makeEngine()
    let t0 = Date()
    engine.start(at: t0)
    #expect(engine.tick(now: t0.addingTimeInterval(1.5)) == nil)
    #expect(abs(engine.remaining - 1.5) < 0.001)
    #expect(engine.state == .running)
}

@Test func phaseCompletionAdvances() throws {
    var engine = makeEngine()
    let t0 = Date()
    engine.start(at: t0)
    let event = engine.tick(now: t0.addingTimeInterval(3))
    guard case .phaseCompleted(let finished, let started) = event else {
        Issue.record("Ожидалось phaseCompleted, получено \(String(describing: event))")
        return
    }
    #expect(finished.kind == .focus)
    #expect(started.kind == .shortBreak)
    #expect(engine.phaseIndex == 1)
    #expect(abs(engine.remaining - 2) < 0.001)
}

@Test func overshootCarriesIntoNextPhase() {
    var engine = makeEngine()
    let t0 = Date()
    engine.start(at: t0)
    // Тик опоздал на 1.2с после конца фазы — перебор вычитается из следующей.
    _ = engine.tick(now: t0.addingTimeInterval(4.2))
    #expect(abs(engine.remaining - 0.8) < 0.001)
}

@Test func cycleRepeatsAndCountsLaps() throws {
    var engine = makeEngine()
    var t = Date()
    engine.start(at: t)
    // 3 + 2 + 4 = 9с на полный круг
    t = t.addingTimeInterval(3); _ = engine.tick(now: t)
    t = t.addingTimeInterval(2); _ = engine.tick(now: t)
    let event = engine.tick(now: t.addingTimeInterval(4))
    guard case .phaseCompleted = event else {
        Issue.record("Круг должен был замкнуться переходом фазы")
        return
    }
    #expect(engine.completedLaps == 1)
    #expect(engine.phaseIndex == 0)
    #expect(engine.state == .running)
}

@Test func nonRepeatingCycleFinishes() throws {
    var engine = makeEngine(repeats: false)
    var t = Date()
    engine.start(at: t)
    t = t.addingTimeInterval(3); _ = engine.tick(now: t)
    t = t.addingTimeInterval(2); _ = engine.tick(now: t)
    let event = engine.tick(now: t.addingTimeInterval(4))
    guard case .cycleFinished = event else {
        Issue.record("Ожидалось cycleFinished, получено \(String(describing: event))")
        return
    }
    #expect(engine.state == .idle)
}

@Test func pauseFreezesRemaining() {
    var engine = makeEngine()
    let t0 = Date()
    engine.start(at: t0)
    engine.pause(at: t0.addingTimeInterval(1))
    #expect(abs(engine.remaining - 2) < 0.001)
    #expect(engine.tick(now: t0.addingTimeInterval(100)) == nil)
    #expect(abs(engine.remaining - 2) < 0.001)
}

@Test func resumeContinuesFromPausedRemaining() {
    var engine = makeEngine()
    let t0 = Date()
    engine.start(at: t0)
    engine.pause(at: t0.addingTimeInterval(1))
    let t1 = t0.addingTimeInterval(60) // «прошла минута» в паузе
    engine.start(at: t1)
    _ = engine.tick(now: t1.addingTimeInterval(1.5))
    #expect(abs(engine.remaining - 0.5) < 0.001)
}

@Test func resetReturnsToPhaseStart() {
    var engine = makeEngine()
    let t0 = Date()
    engine.start(at: t0)
    _ = engine.tick(now: t0.addingTimeInterval(2))
    engine.reset()
    #expect(engine.state == .idle)
    #expect(engine.remaining == 3)
    #expect(engine.phaseIndex == 0)
}

@Test func skipJumpsToNextPhase() throws {
    var engine = makeEngine()
    let event = engine.skip()
    guard case .phaseCompleted(let finished, let started) = event else {
        Issue.record("Ожидалось phaseCompleted")
        return
    }
    #expect(finished.kind == .focus)
    #expect(started.kind == .shortBreak)
    #expect(engine.phaseIndex == 1)
    #expect(engine.remaining == 2)
}

@Test func skipAtEndOfNonRepeatingCycleFinishes() throws {
    var engine = makeEngine(repeats: false)
    _ = engine.skip() // -> break
    _ = engine.skip() // -> focus
    let event = engine.skip() // конец
    guard case .cycleFinished = event else {
        Issue.record("Ожидалось cycleFinished")
        return
    }
    #expect(engine.state == .idle)
}

@Test func roundCounting() {
    var engine = makeEngine()
    #expect(engine.currentRound == 1)
    #expect(engine.totalRounds == 2)
    _ = engine.skip()
    _ = engine.skip()
    #expect(engine.currentRound == 2)
}

@Test func standardCycleShape() {
    let cycle = Cycle.standard()
    #expect(cycle.phases.count == 8)
    #expect(cycle.phases[0].duration == 25 * 60)
    #expect(cycle.phases[1].duration == 5 * 60)
    #expect(cycle.phases[7].kind == .longBreak)
    #expect(cycle.phases[7].duration == 15 * 60)
}

@Test func setCycleResetsPosition() {
    var engine = makeEngine()
    _ = engine.skip()
    engine.setCycle(.standard())
    #expect(engine.phaseIndex == 0)
    #expect(engine.remaining == 25 * 60)
    #expect(engine.state == .idle)
}
