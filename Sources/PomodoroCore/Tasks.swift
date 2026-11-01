import Foundation

/// Задача, к которой привязываются помодоро.
public struct PomodoroTask: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    /// Оценка: сколько фокусов планируется.
    public var estimatedPomodoros: Int
    /// Сколько фокусов завершено.
    public var completedPomodoros: Int
    public var isDone: Bool

    public init(id: UUID = UUID(), title: String, estimatedPomodoros: Int = 1,
                completedPomodoros: Int = 0, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.estimatedPomodoros = max(estimatedPomodoros, 1)
        self.completedPomodoros = completedPomodoros
        self.isDone = isDone
    }
}

/// Хранилище задач. Один JSON-файл, атомарная запись, URL внедряется снаружи.
public final class TaskStore {

    public private(set) var tasks: [PomodoroTask] = []
    /// Задача, к которой привязаны новые сессии фокуса.
    public private(set) var selectedTaskID: UUID?

    private let fileURL: URL

    public var selectedTask: PomodoroTask? {
        tasks.first { $0.id == selectedTaskID }
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public static func makeDefault() -> TaskStore {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro", isDirectory: true)
        return TaskStore(fileURL: dir.appendingPathComponent("tasks.json"))
    }

    // MARK: - Операции

    @discardableResult
    public func add(title: String, estimated: Int = 1) -> PomodoroTask {
        let task = PomodoroTask(title: title, estimatedPomodoros: estimated)
        tasks.append(task)
        save()
        return task
    }

    public func update(_ task: PomodoroTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        save()
    }

    public func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        if selectedTaskID == id { selectedTaskID = nil }
        save()
    }

    public func select(_ id: UUID?) {
        if let id, !tasks.contains(where: { $0.id == id }) { return }
        selectedTaskID = id
        save()
    }

    /// Инкремент счётчика завершённых фокусов у выбранной задачи.
    public func incrementCompletedForSelected() {
        guard let id = selectedTaskID,
              let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].completedPomodoros += 1
        save()
    }

    // MARK: - Персистентность

    private struct Payload: Codable {
        var tasks: [PomodoroTask]
        var selectedTaskID: UUID?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        tasks = payload.tasks
        selectedTaskID = payload.selectedTaskID
    }

    private func save() {
        let payload = Payload(tasks: tasks, selectedTaskID: selectedTaskID)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
