import Foundation

/// Запись о прошедшей фазе: кто, когда, сколько, чем кончилась.
public struct SessionRecord: Codable, Equatable, Sendable, Identifiable {
    public enum Outcome: String, Codable, Sendable {
        case completed  // фаза дошла до конца
        case skipped    // пропущена
    }

    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var taskID: UUID?
    public var taskTitle: String?
    public var phaseKind: PhaseKind
    public var phaseTitle: String
    public var plannedSeconds: Int
    public var actualSeconds: Int
    public var outcome: Outcome

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date,
                taskID: UUID? = nil, taskTitle: String? = nil,
                phaseKind: PhaseKind, phaseTitle: String,
                plannedSeconds: Int, actualSeconds: Int, outcome: Outcome) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.phaseKind = phaseKind
        self.phaseTitle = phaseTitle
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.outcome = outcome
    }
}

/// Журнал сессий: JSONL (по записи на строку) — дописывается без перезаписи файла,
/// переживает обрыв на любой строке.
public final class SessionLogStore {

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func makeDefault() -> SessionLogStore {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro", isDirectory: true)
        return SessionLogStore(fileURL: dir.appendingPathComponent("sessions.jsonl"))
    }

    public func append(_ record: SessionRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: fileURL.path),
           let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.write(contentsOf: Data("\n".utf8))
        } else {
            try? (data + Data("\n".utf8)).write(to: fileURL, options: .atomic)
        }
    }

    /// Все записи; битые строки пропускаются.
    public func all() -> [SessionRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap { line in
            try? decoder.decode(SessionRecord.self, from: Data(line.utf8))
        }
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// Сводная статистика по журналу.
public struct StatsSummary: Equatable, Sendable {
    public var focusCount: Int          // завершённые фокусы
    public var focusMinutes: Int        // их суммарная фактическая длительность
    public var interruptedCount: Int    // пропущенные (прерванные) фокусы

    public init(focusCount: Int, focusMinutes: Int, interruptedCount: Int) {
        self.focusCount = focusCount
        self.focusMinutes = focusMinutes
        self.interruptedCount = interruptedCount
    }

    public static func make(from records: [SessionRecord], in interval: DateInterval) -> StatsSummary {
        var summary = StatsSummary(focusCount: 0, focusMinutes: 0, interruptedCount: 0)
        for record in records where record.phaseKind == .focus && interval.contains(record.endedAt) {
            switch record.outcome {
            case .completed:
                summary.focusCount += 1
                summary.focusMinutes += record.actualSeconds / 60
            case .skipped:
                summary.interruptedCount += 1
            }
        }
        return summary
    }
}
