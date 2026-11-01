import Foundation

public enum StatsExporter {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    // MARK: - CSV

    public static func csv(records: [SessionRecord]) -> String {
        var lines = ["date_start;date_end;task;phase;planned_min;actual_min;outcome"]
        for r in records {
            let cells = [
                dateFormatter.string(from: r.startedAt),
                dateFormatter.string(from: r.endedAt),
                escape(r.taskTitle ?? ""),
                escape(r.phaseTitle),
                String(r.plannedSeconds / 60),
                String(format: "%.1f", Double(r.actualSeconds) / 60),
                r.outcome.rawValue,
            ]
            lines.append(cells.joined(separator: ";"))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ s: String) -> String {
        guard s.contains(";") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - XLSX

    /// Минимальный xlsx: это zip с XML внутри. Собираем XML сами,
    /// архивируем системным zip(1) — сторонних зависимостей нет.
    /// Строки пишем как inlineStr, чтобы не таскать sharedStrings.
    @discardableResult
    public static func writeXLSX(records: [SessionRecord], to fileURL: URL) throws {
        let header = ["date_start", "date_end", "task", "phase", "planned_min", "actual_min", "outcome"]
        var rows: [[String]] = [header]
        for r in records {
            rows.append([
                dateFormatter.string(from: r.startedAt),
                dateFormatter.string(from: r.endedAt),
                r.taskTitle ?? "",
                r.phaseTitle,
                String(r.plannedSeconds / 60),
                String(format: "%.1f", Double(r.actualSeconds) / 60),
                r.outcome.rawValue,
            ])
        }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pomodoro-xlsx-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        for sub in ["_rels", "xl", "xl/_rels", "xl/worksheets"] {
            try FileManager.default.createDirectory(at: tmp.appendingPathComponent(sub),
                                                    withIntermediateDirectories: true)
        }

        try contentTypes.write(to: tmp.appendingPathComponent("[Content_Types].xml"))
        try rootRels.write(to: tmp.appendingPathComponent("_rels/.rels"))
        try workbook.write(to: tmp.appendingPathComponent("xl/workbook.xml"))
        try workbookRels.write(to: tmp.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        try sheetXML(rows: rows).write(to: tmp.appendingPathComponent("xl/worksheets/sheet1.xml"))

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tmp
        process.arguments = ["-q", "-r", fileURL.path, "."]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func sheetXML(rows: [[String]]) -> String {
        var body = ""
        for (rowIndex, row) in rows.enumerated() {
            body += "<row r=\"\(rowIndex + 1)\">"
            for (colIndex, value) in row.enumerated() {
                body += "<c r=\"\(columnLetter(colIndex))\(rowIndex + 1)\" t=\"inlineStr\">"
                    + "<is><t>\(xmlEscape(value))</t></is></c>"
            }
            body += "</row>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData>\(body)</sheetData></worksheet>
        """
    }

    private static func columnLetter(_ index: Int) -> String {
        var n = index
        var result = ""
        repeat {
            result = String(UnicodeScalar(65 + n % 26)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Заготовки XML

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    </Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
    </Relationships>
    """

    private static let workbook = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
    <sheets><sheet name="Статистика" sheetId="1" r:id="rId1"/></sheets></workbook>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
    </Relationships>
    """
}

private extension String {
    func write(to url: URL) throws {
        try self.write(to: url, atomically: true, encoding: .utf8)
    }
}
