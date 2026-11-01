import Testing
import Foundation
@testable import PomodoroCore

// MARK: - Подписи фаз

@Test func phaseDisplayTitleFallsBackToKind() {
    let phase = Phase(kind: .focus, minutes: 25)
    #expect(phase.displayTitle == "Фокус")
}

@Test func phaseDisplayTitleUsesCustomLabel() {
    let phase = Phase(kind: .focus, minutes: 20, title: "созвон")
    #expect(phase.displayTitle == "созвон")
}

@Test func phaseDisplayTitleTrimsWhitespace() {
    let phase = Phase(kind: .longBreak, minutes: 30, title: "  обед  ")
    #expect(phase.displayTitle == "обед")
}

@Test func phaseDisplayTitleTreatsBlankAsEmpty() {
    let phase = Phase(kind: .longBreak, minutes: 30, title: "   ")
    #expect(phase.displayTitle == "Длинный перерыв")
}

@Test func phaseDecodesWithoutTitle() throws {
    // Старое сохранение без поля title должно читаться.
    let json = #"{"id":"00000000-0000-0000-0000-000000000001","kind":"focus","duration":1500}"#
    let phase = try JSONDecoder().decode(Phase.self, from: Data(json.utf8))
    #expect(phase.title == "")
    #expect(phase.displayTitle == "Фокус")
}

// MARK: - Хранилище пресетов

private func tempStore() -> (CycleStore, URL) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("cycles.json")
    return (CycleStore(fileURL: url), url)
}

@Test func storeSeedsStandardCycleOnFirstLaunch() {
    let (store, _) = tempStore()
    #expect(store.cycles.count == 1)
    #expect(store.cycles[0].name == "Стандартный")
    #expect(store.selectedCycle == store.cycles[0])
}

@Test func storePersistsAcrossInstances() throws {
    let (store, url) = tempStore()
    var custom = Cycle(name: "Мой день", phases: [
        Phase(kind: .focus, minutes: 25, title: "работа"),
        Phase(kind: .shortBreak, minutes: 5, title: "перерыв"),
        Phase(kind: .focus, minutes: 20, title: "созвон"),
        Phase(kind: .longBreak, minutes: 30, title: "обед"),
    ])
    _ = store.add(custom)
    store.select(custom.id)

    // Новый экземпляр с тем же файлом видит всё сохранённое.
    let reloaded = CycleStore(fileURL: url)
    #expect(reloaded.cycles.count == 2)
    #expect(reloaded.selectedCycle.name == "Мой день")
    #expect(reloaded.selectedCycle.phases[2].displayTitle == "созвон")
    #expect(reloaded.selectedCycle.phases[3].duration == 30 * 60)
}

@Test func storeUpdatePersists() {
    let (store, url) = tempStore()
    var cycle = store.cycles[0]
    cycle.name = "Переименованный"
    cycle.phases[0].title = "глубокая работа"
    store.update(cycle)

    let reloaded = CycleStore(fileURL: url)
    #expect(reloaded.cycles[0].name == "Переименованный")
    #expect(reloaded.cycles[0].phases[0].displayTitle == "глубокая работа")
}

@Test func storeNeverDeletesLastCycle() {
    let (store, _) = tempStore()
    store.delete(store.cycles[0].id)
    #expect(store.cycles.count == 1)
}

@Test func storeDeleteReselectsRemaining() {
    let (store, url) = tempStore()
    let added = store.add(Cycle(name: "Второй", phases: [Phase(kind: .focus, minutes: 10)]))
    store.select(added.id)
    store.delete(added.id)

    let reloaded = CycleStore(fileURL: url)
    #expect(reloaded.cycles.count == 1)
    #expect(reloaded.selectedCycleID == reloaded.cycles[0].id)
}

@Test func storeDuplicateCreatesIndependentCopy() {
    let (store, _) = tempStore()
    let original = store.cycles[0]
    let copy = store.duplicate(original.id)
    #expect(copy != nil)
    #expect(copy?.name == "Стандартный (копия)")
    #expect(copy?.id != original.id)
    #expect(copy?.phases.map(\.id).allSatisfy { id in !original.phases.map(\.id).contains(id) } == true)
}
