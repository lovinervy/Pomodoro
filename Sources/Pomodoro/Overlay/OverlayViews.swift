import SwiftUI
import AppKit
import PomodoroCore

/// Маркер области, за которую OverlayPanel разрешает перетаскивание.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragNSView { DragNSView() }
    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

final class DragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func rightMouseDown(with event: NSEvent) {} // не всплывающее меню
}

/// Пастельная палитра оверлеев.
enum KawaiiPalette {
    static func background(for kind: PhaseKind) -> Color {
        switch kind {
        case .focus:      return Color(red: 1.00, green: 0.82, blue: 0.80) // мягкий коралл
        case .shortBreak: return Color(red: 0.80, green: 0.93, blue: 0.84) // мята
        case .longBreak:  return Color(red: 0.78, green: 0.88, blue: 0.97) // небо
        }
    }

    static func accent(for kind: PhaseKind) -> Color {
        switch kind {
        case .focus:      return Color(red: 0.90, green: 0.45, blue: 0.42)
        case .shortBreak: return Color(red: 0.36, green: 0.70, blue: 0.50)
        case .longBreak:  return Color(red: 0.42, green: 0.62, blue: 0.85)
        }
    }

    static let text = Color(red: 0.32, green: 0.24, blue: 0.24) // тёмный какао
}

/// Плавающий чип таймера: мордочка + время + тонкое кольцо прогресса.
struct TimerChipView: View {
    @ObservedObject var vm: TimerViewModel
    @AppStorage(AppSettings.overlayOpacity) private var opacity = 0.92

    private var mood: KawaiiMood {
        switch vm.engine.currentPhase.kind {
        case .focus: return .focus
        case .shortBreak: return .happy
        case .longBreak: return .sleepy
        }
    }

    var body: some View {
        let kind = vm.engine.currentPhase.kind
        ZStack {
            // Слой перетаскивания — самый нижний; контент событиям не прозрачен,
            // поэтому помечаем его allowsHitTesting(false), и хиты падают сюда.
            WindowDragArea()
            Capsule()
                .fill(KawaiiPalette.background(for: kind).opacity(opacity))
                .allowsHitTesting(false)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(KawaiiPalette.text.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: vm.engine.phaseProgress)
                        .stroke(KawaiiPalette.accent(for: kind),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: vm.engine.phaseProgress)
                    KawaiiFace(mood: mood)
                        .padding(5)
                }
                .frame(width: 34, height: 34)

                Text(vm.remainingText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(KawaiiPalette.text)
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 7)
            .allowsHitTesting(false)

            Capsule()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(Capsule())
        .contentShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .animation(.easeInOut(duration: 0.3), value: kind)
    }
}

/// Плавающая панель управления: круглые пастельные кнопки.
struct ControlPanelView: View {
    @ObservedObject var vm: TimerViewModel
    @AppStorage(AppSettings.overlayOpacity) private var opacity = 0.92

    var body: some View {
        let kind = vm.engine.currentPhase.kind
        ZStack {
            // Слой перетаскивания — нижний; кнопки выше и получают свои клики.
            WindowDragArea()
            Capsule()
                .fill(KawaiiPalette.background(for: kind).opacity(opacity))
                .allowsHitTesting(false)

            HStack(spacing: 10) {
                controlButton(
                    icon: vm.isRunning ? "pause.fill" : "play.fill",
                    tint: KawaiiPalette.accent(for: kind)
                ) { vm.toggleStartPause() }

                controlButton(icon: "forward.fill",
                              tint: KawaiiPalette.accent(for: kind)) { vm.skip() }

                controlButton(icon: "arrow.counterclockwise",
                              tint: KawaiiPalette.accent(for: kind)) { vm.reset() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Capsule()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(Capsule())
        .contentShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    private func controlButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
    }
}
