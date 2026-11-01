import Foundation

/// Тип фазы помодоро-цикла.
public enum PhaseKind: String, Codable, Equatable, Sendable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool { self != .focus }

    /// Название по умолчанию, если пользователь не задал свою подпись.
    public var defaultTitle: String {
        switch self {
        case .focus: return "Фокус"
        case .shortBreak: return "Перерыв"
        case .longBreak: return "Длинный перерыв"
        }
    }
}

/// Одна фаза цикла: тип + длительность + необязательная пользовательская подпись
/// («работа», «созвон», «обед»…).
public struct Phase: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var kind: PhaseKind
    /// Длительность в секундах.
    public var duration: TimeInterval
    /// Пользовательская подпись; пустая строка = показывать название по типу.
    public var title: String

    public init(id: UUID = UUID(), kind: PhaseKind, duration: TimeInterval, title: String = "") {
        self.id = id
        self.kind = kind
        self.duration = duration
        self.title = title
    }

    public init(kind: PhaseKind, minutes: Double, title: String = "") {
        self.init(kind: kind, duration: minutes * 60, title: title)
    }

    /// Подпись для показа: пользовательская, иначе по типу фазы.
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.defaultTitle : trimmed
    }

    // Обратная совместимость: в старых сохранениях поля title может не быть.
    private enum CodingKeys: String, CodingKey { case id, kind, duration, title }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(PhaseKind.self, forKey: .kind)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    }
}

/// Цикл — упорядоченный список фаз произвольной длины с подписями.
/// Примеры: стандартный 25/5 ×4 + длинный перерыв; произвольный
/// 25 «работа» / 5 «перерыв» / 20 «созвон» / 30 «обед».
public struct Cycle: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var phases: [Phase]
    /// Начинать цикл заново после последней фазы.
    public var repeats: Bool

    public init(id: UUID = UUID(), name: String, phases: [Phase], repeats: Bool = true) {
        self.id = id
        self.name = name
        self.phases = phases
        self.repeats = repeats
    }

    /// Классический помодоро: 4 фокуса по 25 мин с короткими перерывами 5 мин,
    /// после четвёртого — длинный перерыв.
    public static func standard(
        focusMinutes: Double = 25,
        shortBreakMinutes: Double = 5,
        longBreakMinutes: Double = 15,
        rounds: Int = 4
    ) -> Cycle {
        var phases: [Phase] = []
        for round in 1...max(rounds, 1) {
            phases.append(Phase(kind: .focus, minutes: focusMinutes, title: "работа"))
            let isLast = round == rounds
            phases.append(Phase(
                kind: isLast ? .longBreak : .shortBreak,
                minutes: isLast ? longBreakMinutes : shortBreakMinutes,
                title: isLast ? "" : "перерыв"
            ))
        }
        return Cycle(name: "Стандартный", phases: phases)
    }
}
