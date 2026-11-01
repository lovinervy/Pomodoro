import SwiftUI
import PomodoroCore

/// Список задач: добавление, оценка в помодоро, привязка к текущей сессии.
struct TasksView: View {
    @ObservedObject var vm: TimerViewModel
    @State private var newTaskTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Новая задача…", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTask)
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            List {
                ForEach(vm.taskStore.tasks) { task in
                    TaskRow(
                        task: task,
                        isSelected: task.id == vm.taskStore.selectedTaskID,
                        onSelect: { vm.selectTask(id: task.id) },
                        onToggleDone: {
                            var t = task
                            t.isDone.toggle()
                            vm.taskStore.update(t)
                            vm.tasksDidChange()
                        },
                        onEstimate: { delta in
                            var t = task
                            t.estimatedPomodoros = max(1, t.estimatedPomodoros + delta)
                            vm.taskStore.update(t)
                            vm.tasksDidChange()
                        },
                        onDelete: {
                            vm.taskStore.delete(task.id)
                            vm.tasksDidChange()
                        }
                    )
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .frame(minWidth: 380, minHeight: 300)
        .onAppear { _ = vm.storeVersion }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let task = vm.taskStore.add(title: title)
        vm.selectTask(id: task.id)
        newTaskTitle = ""
    }
}

private struct TaskRow: View {
    let task: PomodoroTask
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleDone: () -> Void
    let onEstimate: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleDone) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: onSelect) {
                HStack {
                    Text(task.title)
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "timer")
                            .foregroundStyle(.red)
                            .help("Текущая задача")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "timer.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }

            Menu {
                Button("+1 к оценке") { onEstimate(1) }
                Button("−1 к оценке") { onEstimate(-1) }
                Divider()
                Button("Удалить", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.vertical, 2)
    }
}
