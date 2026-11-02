import SwiftUI
import PomodoroCore

/// Редактор циклов: список пресетов слева, фазы выбранного пресета справа.
/// Каждой фазе можно задать тип, длительность и свою подпись
/// («работа», «созвон», «обед»…).
struct CycleEditorView: View {
    @ObservedObject var vm: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingID: UUID?

    var body: some View {
        NavigationSplitView {
            presetList
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            if let cycle = editingCycle {
                PhaseListView(
                    cycle: cycle,
                    onChange: { updated in
                        vm.store.update(updated)
                        if updated.id == vm.store.selectedCycleID { vm.storeDidChange() }
                    }
                )
            } else {
                Text("Выберите цикл")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 560, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { dismiss() }
            }
        }
        .onAppear { editingID = vm.store.selectedCycleID }
    }

    private var editingCycle: Cycle? {
        _ = vm.storeVersion // подписка на изменения
        return vm.store.cycles.first(where: { $0.id == editingID }) ?? vm.store.cycles.first
    }

    private var presetList: some View {
        List(selection: $editingID) {
            ForEach(vm.store.cycles) { cycle in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(cycle.name)
                            if cycle.isProtected {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .help("Встроенный цикл: редактировать можно, удалить нельзя")
                            }
                        }
                        Text(summary(for: cycle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if cycle.id == vm.store.selectedCycleID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .tag(cycle.id)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Сделать активным") { vm.selectCycle(id: cycle.id) }
                    Button("Дублировать") {
                        if let copy = vm.store.duplicate(cycle.id) {
                            editingID = copy.id
                            vm.storeDidChange()
                        }
                    }
                    if !cycle.isProtected && vm.store.cycles.count > 1 {
                        Button("Удалить", role: .destructive) {
                            vm.store.delete(cycle.id)
                            vm.storeDidChange()
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Тулбар внутри колонки NavigationSplitView не рендерится,
            // поэтому кнопка добавления — отдельной панелью снизу.
            HStack {
                Button {
                    let new = vm.store.add(Cycle(name: "Новый цикл", phases: [
                        Phase(kind: .focus, minutes: 25, title: "работа"),
                        Phase(kind: .shortBreak, minutes: 5, title: "перерыв"),
                    ]))
                    editingID = new.id
                    vm.storeDidChange()
                } label: {
                    Label("Новый цикл", systemImage: "plus")
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func summary(for cycle: Cycle) -> String {
        cycle.phases
            .map { "\(Int($0.duration / 60)) \($0.displayTitle)" }
            .joined(separator: " · ")
    }
}

/// Правая панель: редактирование фаз одного цикла.
private struct PhaseListView: View {
    let cycle: Cycle
    let onChange: (Cycle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Название цикла", text: binding(\.name))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Toggle("Повторять по кругу", isOn: binding(\.repeats))
                Spacer()
                Button("Активировать") {}
                    .hidden() // активация — через список слева
            }

            List {
                ForEach(cycle.phases) { phase in
                    if let idx = cycle.phases.firstIndex(where: { $0.id == phase.id }) {
                        PhaseRow(phase: phase) { updated in
                            var c = cycle
                            c.phases[idx] = updated
                            onChange(c)
                        } onDelete: {
                            var c = cycle
                            c.phases.remove(at: idx)
                            onChange(c)
                        }
                    }
                }
                .onMove { from, to in
                    var c = cycle
                    c.phases.move(fromOffsets: from, toOffset: to)
                    onChange(c)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            HStack {
                Menu("Добавить фазу") {
                    ForEach(PhaseKind.allCases, id: \.self) { kind in
                        Button(kind.defaultTitle) {
                            var c = cycle
                            c.phases.append(Phase(kind: kind, minutes: kind == .focus ? 25 : 5))
                            onChange(c)
                        }
                    }
                }
                Spacer()
                Text("Итого: \(Int(cycle.phases.reduce(0) { $0 + $1.duration } / 60)) мин")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Cycle, T>) -> Binding<T> {
        Binding(
            get: { cycle[keyPath: keyPath] },
            set: { newValue in
                var c = cycle
                c[keyPath: keyPath] = newValue
                onChange(c)
            }
        )
    }
}

/// Одна строка фазы: тип, длительность, подпись, удаление.
private struct PhaseRow: View {
    let phase: Phase
    let onChange: (Phase) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)

            Picker("", selection: Binding(
                get: { phase.kind },
                set: { var p = phase; p.kind = $0; onChange(p) }
            )) {
                ForEach(PhaseKind.allCases, id: \.self) { kind in
                    Text(kind.defaultTitle).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Stepper(value: Binding(
                get: { Int(phase.duration / 60) },
                set: { var p = phase; p.duration = TimeInterval(max($0, 1)) * 60; onChange(p) }
            ), in: 1...180) {
                Text("\(Int(phase.duration / 60)) мин")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .leading)
            }

            TextField("подпись (необязательно)", text: Binding(
                get: { phase.title },
                set: { var p = phase; p.title = $0; onChange(p) }
            ))
            .textFieldStyle(.roundedBorder)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
