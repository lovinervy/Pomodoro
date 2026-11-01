import SwiftUI
import AppKit

/// Системное окно настроек (Cmd+,).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("Общее", systemImage: "gear") }
            NotificationsSettingsTab()
                .tabItem { Label("Уведомления", systemImage: "bell") }
            OverlaySettingsTab()
                .tabItem { Label("Оверлей", systemImage: "macwindow.on.rectangle") }
        }
        .frame(width: 420, height: 240)
        .padding()
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.autoStartNextPhase) private var autoStart = true
    @AppStorage(AppSettings.showTimeInMenuBar) private var showTime = true

    var body: some View {
        Form {
            Toggle("Автоматически начинать следующую фазу", isOn: $autoStart)
            Text("Если выключено, после смены фазы таймер встаёт на паузу.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Показывать время в меню-баре", isOn: $showTime)
        }
        .formStyle(.grouped)
    }
}

private struct NotificationsSettingsTab: View {
    @AppStorage(AppSettings.notificationsEnabled) private var notifications = true
    @AppStorage(AppSettings.soundEnabled) private var sound = true
    @AppStorage(AppSettings.soundName) private var soundName = "Glass"

    var body: some View {
        Form {
            Toggle("Показывать уведомления о смене фазы", isOn: $notifications)

            Toggle("Звук при смене фазы", isOn: $sound)

            HStack {
                Picker("Звук:", selection: $soundName) {
                    ForEach(AppSettings.availableSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .disabled(!sound)
                Button {
                    NSSound(named: NSSound.Name(soundName))?.play()
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .disabled(!sound)
                .help("Прослушать")
            }
        }
        .formStyle(.grouped)
    }
}

private struct OverlaySettingsTab: View {
    @AppStorage("overlay.enabled") private var overlayEnabled = true
    @AppStorage(AppSettings.overlayOpacity) private var opacity = 0.92

    var body: some View {
        Form {
            Toggle("Плавающий оверлей при активном таймере", isOn: $overlayEnabled)
            Text("Чип-таймер и панель управления поверх всех окон, включая полноэкранный режим. Перетаскиваются мышью, позиции запоминаются.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Непрозрачность")
                Slider(value: $opacity, in: 0.3...1.0)
                Text("\(Int(opacity * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
            .disabled(!overlayEnabled)
        }
        .formStyle(.grouped)
    }
}
