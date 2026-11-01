import SwiftUI
import AppKit
import PomodoroCore

/// Статистика: сводка за сегодня/неделю, последние сессии, экспорт.
struct StatsView: View {
    @ObservedObject var vm: TimerViewModel
    /// Триггер перечитывания журнала.
    @State private var reloadToken = 0

    private var records: [SessionRecord] {
        _ = reloadToken
        return vm.sessionLog.all().sorted { $0.endedAt > $1.endedAt }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                summaryCard(title: "Сегодня", interval: todayInterval())
                summaryCard(title: "Неделя", interval: weekInterval())
            }

            HStack {
                Text("Последние сессии")
                    .font(.headline)
                Spacer()
                Button("Экспорт CSV") { export(format: .csv) }
                Button("Экспорт XLSX") { export(format: .xlsx) }
                Button {
                    reloadToken += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Обновить")
            }

            List(records.prefix(100)) { record in
                HStack {
                    Image(systemName: record.outcome == .completed ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(record.outcome == .completed ? .green : .orange)
                    Text(Self.timeFormatter.string(from: record.startedAt))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(record.phaseTitle)
                    if let task = record.taskTitle, !task.isEmpty {
                        Text("· \(task)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(record.actualSeconds / 60) мин")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding()
        .frame(minWidth: 460, minHeight: 380)
    }

    // MARK: - Сводки

    @ViewBuilder
    private func summaryCard(title: String, interval: DateInterval) -> some View {
        let summary = StatsSummary.make(from: records, in: interval)
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "timer.circle.fill")
                    .foregroundStyle(.red)
                Text("\(summary.focusCount)")
                    .font(.title2.bold())
                Text("(\(summary.focusMinutes) мин)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if summary.interruptedCount > 0 {
                Text("прервано: \(summary.interruptedCount)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func todayInterval() -> DateInterval {
        let start = Calendar.current.startOfDay(for: Date())
        return DateInterval(start: start, end: Date())
    }

    private func weekInterval() -> DateInterval {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? Calendar.current.startOfDay(for: Date())
        return DateInterval(start: start, end: Date())
    }

    // MARK: - Экспорт

    private enum ExportFormat { case csv, xlsx }

    private func export(format: ExportFormat) {
        let panel = NSSavePanel()
        let stamp = DateFormatter.fileStamp.string(from: Date())
        switch format {
        case .csv:
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "pomodoro-\(stamp).csv"
        case .xlsx:
            panel.allowedContentTypes = [.spreadsheet]
            panel.nameFieldStringValue = "pomodoro-\(stamp).xlsx"
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let all = vm.sessionLog.all().sorted { $0.startedAt < $1.startedAt }
        do {
            switch format {
            case .csv:
                try StatsExporter.csv(records: all).write(to: url, atomically: true, encoding: .utf8)
            case .xlsx:
                try StatsExporter.writeXLSX(records: all, to: url)
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}
