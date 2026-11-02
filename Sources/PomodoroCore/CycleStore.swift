import Foundation

/// Хранилище пресетов циклов. Один маленький JSON-файл, атомарная запись.
/// URL внедряется снаружи — в приложении это Application Support, в тестах — временная папка.
public final class CycleStore {

    public private(set) var cycles: [Cycle] = []
    public private(set) var selectedCycleID: UUID?

    private let fileURL: URL

    public var selectedCycle: Cycle {
        if let id = selectedCycleID, let found = cycles.first(where: { $0.id == id }) {
            return found
        }
        return cycles.first ?? .standard()
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    /// Хранилище по умолчанию: ~/Library/Application Support/Pomodoro/cycles.json
    public static func makeDefault() -> CycleStore {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro", isDirectory: true)
        return CycleStore(fileURL: dir.appendingPathComponent("cycles.json"))
    }

    // MARK: - Операции

    public func select(_ id: UUID) {
        guard cycles.contains(where: { $0.id == id }) else { return }
        selectedCycleID = id
        save()
    }

    @discardableResult
    public func add(_ cycle: Cycle) -> Cycle {
        cycles.append(cycle)
        if cycles.count == 1 { selectedCycleID = cycle.id }
        save()
        return cycle
    }

    public func update(_ cycle: Cycle) {
        guard let idx = cycles.firstIndex(where: { $0.id == cycle.id }) else { return }
        cycles[idx] = cycle
        save()
    }

    public func delete(_ id: UUID) {
        // Последний цикл не удаляем — движку нужен хотя бы один.
        // Защищённый (встроенный «Стандартный») не удаляем никогда.
        guard cycles.count > 1,
              let target = cycles.first(where: { $0.id == id }),
              !target.isProtected else { return }
        cycles.removeAll { $0.id == id }
        if selectedCycleID == id { selectedCycleID = cycles.first?.id }
        save()
    }

    @discardableResult
    public func duplicate(_ id: UUID) -> Cycle? {
        guard let source = cycles.first(where: { $0.id == id }) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.name = source.name + " (копия)"
        copy.isProtected = false // копию встроенного цикла удалять можно
        copy.phases = source.phases.map { Phase(kind: $0.kind, duration: $0.duration, title: $0.title) }
        return add(copy)
    }

    // MARK: - Персистентность

    private struct Payload: Codable {
        var cycles: [Cycle]
        var selectedCycleID: UUID?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.cycles.isEmpty
        else {
            // Первый запуск: один стандартный пресет.
            let standard = Cycle.standard()
            cycles = [standard]
            selectedCycleID = standard.id
            save()
            return
        }
        cycles = payload.cycles
        selectedCycleID = payload.selectedCycleID
        // Миграция со старых версий: защищаем первый (зашитый) цикл,
        // если ни один не помечен защищённым.
        if !cycles.isEmpty && !cycles.contains(where: \.isProtected) {
            cycles[0].isProtected = true
            save()
        }
    }

    private func save() {
        let payload = Payload(cycles: cycles, selectedCycleID: selectedCycleID)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
