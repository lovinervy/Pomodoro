import Foundation
import AppKit

/// Ключи и хелперы настроек. Храним в UserDefaults — для такого объёма самое то.
enum AppSettings {
    static let autoStartNextPhase = "settings.autoStartNextPhase"
    static let showTimeInMenuBar = "settings.showTimeInMenuBar"
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let soundEnabled = "settings.soundEnabled"
    static let soundName = "settings.soundName"
    static let overlayOpacity = "overlay.opacity"

    static func bool(_ key: String, default def: Bool = true) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? def
    }

    static var currentSoundName: String {
        UserDefaults.standard.string(forKey: soundName) ?? "Glass"
    }

    /// Проиграть выбранный в настройках звук.
    static func playCurrentSound() {
        guard bool(soundEnabled) else { return }
        NSSound(named: NSSound.Name(currentSoundName))?.play()
    }

    /// Системные звуки, доступные всегда.
    static let availableSounds = ["Glass", "Ping", "Pop", "Hero", "Blow", "Bottle", "Frog", "Morse", "Submarine", "Tink"]
}
