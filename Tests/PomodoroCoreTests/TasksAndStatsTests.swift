import Testing
import Foundation
@testable import PomodoroCore

// MARK: - Задачи

private func tempURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent(name)
}

@Test func taskStoreAddSelectPersist() {
    let url = tempURL("tasks.json")
    let store = TaskStore(fileURL: url)
    let task = store.add(title: "Написать отчёт", estimated: 3)
    store.select(task.id)

    let reloaded = TaskStore(fileURL: url)
    #expect(reloaded.tasks.count == 1)
    #expect(reloaded.selectedTask?.title == "Написать отчёт")
    #expect(reloaded.selectedTask?.estimatedPomodoros == 3)
}

@Test func taskStoreIncrementCompleted() {
    let url = tempURL("tasks.json")
    let store = TaskStore(fileURL: url)
    let task = store.add(title: "Задача")
    store.select(task.id)
    store.incrementCompletedForSelected()
    store.incrementCompletedForSelected()

    let reloaded = TaskStore(fileURL: url)
    #expect(reloaded.selectedTask?.completedPomodoros == 2)
}

@Test func taskStoreDeleteClearsSelection() {
    let store = TaskStore(fileURL: tempURL("tasks.json"))
    let task = store.add(title: "Временная")
    store.select(task.id)
    store.delete(task.id)
    #expect(store.tasks.isEmpty)
    #expect(store.selectedTask == nil)
}

@Test func taskEstimatedMinimumIsOne() {
    let task = PomodoroTask(title: "x", estimatedPomodoros: 0)
    #expect(task.estimatedPomodoros == 1)
}

// MARK: - Журнал сессий

private func makeRecord(
    kind: PhaseKind = .focus, title: String = "работа",
    planned: Int = 1500, actual: Int = 1500,
    outcome: SessionRecord.Outcome = .completed,
    endedAt: Date = Date()
) -> SessionRecord {
    SessionRecord(
        startedAt: endedAt.addingTimeInterval(-TimeInterval(actual)),
        endedAt: endedAt,
        taskTitle: "задача",
        phaseKind: kind, phaseTitle: title,
        plannedSeconds: planned, actualSeconds: actual,
        outcome: outcome
    )
}

@Test func sessionLogAppendAndRead() {
    let log = SessionLogStore(fileURL: tempURL("sessions.jsonl"))
    log.append(makeRecord(title: "работа"))
    log.append(makeRecord(kind: .shortBreak, title: "перерыв", planned: 300, actual: 300))

    let all = log.all()
    #expect(all.count == 2)
    #expect(all[0].phaseTitle == "работа")
    #expect(all[1].phaseKind == .shortBreak)
    #expect(all[1].plannedSeconds == 300)
}

@Test func sessionLogSkipsCorruptedLines() throws {
    let url = tempURL("sessions.jsonl")
    let log = SessionLogStore(fileURL: url)
    log.append(makeRecord())
    // Портим файл: добавляем мусорную строку.
    let handle = try FileHandle(forWritingTo: url)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("это не json\n".utf8))
    try handle.close()
    log.append(makeRecord())

    #expect(log.all().count == 2)
}

@Test func statsSummaryCountsCompletedFocus() {
    let now = Date()
    let records = [
        makeRecord(outcome: .completed, endedAt: now),                          // +1 фокус
        makeRecord(actual: 1200, outcome: .completed, endedAt: now),            // +1 фокус, 20 мин
        makeRecord(actual: 300, outcome: .skipped, endedAt: now),               // прерван
        makeRecord(kind: .shortBreak, outcome: .completed, endedAt: now),       // не фокус
        makeRecord(outcome: .completed, endedAt: now.addingTimeInterval(-90000)) // вчера+
    ]
    let today = DateInterval(start: Calendar.current.startOfDay(for: now), end: now)
    let summary = StatsSummary.make(from: records, in: today)
    #expect(summary.focusCount == 2)
    #expect(summary.focusMinutes == (1500 + 1200) / 60)
    #expect(summary.interruptedCount == 1)
}

// MARK: - Экспорт

@Test func csvExportFormat() {
    let r = makeRecord(title: "обед; с кофе")
    let csv = StatsExporter.csv(records: [r])
    let lines = csv.split(separator: "\n")
    #expect(lines.count == 2)
    #expect(lines[0] == "date_start;date_end;task;phase;planned_min;actual_min;outcome")
    // Подпись с точкой с запятой должна быть в кавычках.
    #expect(lines[1].contains("\"обед; с кофе\""))
    #expect(lines[1].contains("completed"))
}

@Test func xlsxExportProducesValidZip() throws {
    let url = tempURL("stats.xlsx")
    try StatsExporter.writeXLSX(records: [makeRecord(), makeRecord(title: "обед")], to: url)

    let data = try Data(contentsOf: url)
    #expect(data.count > 500)
    // ZIP начинается с PK\x03\x04.
    #expect(data[0] == 0x50) // P
    #expect(data[1] == 0x4B) // K
}
