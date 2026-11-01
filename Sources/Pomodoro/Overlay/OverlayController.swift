import AppKit
import SwiftUI
import Combine

/// Хостинг-вью, с которого можно тянуть окно за любое место.
/// Без него SwiftUI-контент перехватывает мышь, и isMovableByWindowBackground не работает.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

/// Плавающее borderless-окно, которое держится поверх всего,
/// включая полноэкранные приложения, и не крадёт фокус.
final class OverlayPanel: NSPanel {

    /// true — окно тянется за любую точку (для чипа без кнопок).
    /// false — тянется только за области WindowDragArea (для панели с кнопками).
    var dragAnywhere = false

    /// Перехватываем события на уровне окна: надёжнее, чем полагаться на то,
    /// что SwiftUI-хостинг пропустит mouseDown вниз по иерархии.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let hit = contentView?.hitTest(event.locationInWindow)
            if dragAnywhere || hit is DragNSView {
                performDrag(with: event)
                return
            }
        }
        super.sendEvent(event)
    }

    init(autosaveName: String, defaultRect: NSRect, dragAnywhere: Bool = false) {
        self.dragAnywhere = dragAnywhere
        super.init(contentRect: defaultRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // тень рисует сам SwiftUI-слой
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        setFrameAutosaveName(autosaveName)
    }
}

/// Управляет двумя независимыми оверлеями: чип-таймер и панель управления.
/// Видимость: когда таймер активен (идёт или на паузе) И оверлей включён.
///
/// Панели создаются лениво, а показ/скрытие всегда уходит на следующий
/// виток runloop — иначе показ окна изнутри @Published-события падает
/// в AttributeGraph (показ окна во время обновления ViewGraph).
@MainActor
final class OverlayController: ObservableObject {

    /// Вкл/выкл оверлея (переключатель в меню-баре). Сохраняется между запусками.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            scheduleVisibilityUpdate()
        }
    }

    private static let enabledKey = "overlay.enabled"

    private weak var vm: TimerViewModel?
    private var chipPanel: OverlayPanel?
    private var controlPanel: OverlayPanel?
    private var timerActive = false
    private var cancellables: Set<AnyCancellable> = []

    init(vm: TimerViewModel) {
        self.vm = vm
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true

        vm.$engine
            .map { $0.state != .idle }
            .removeDuplicates()
            .sink { [weak self] active in
                guard let self else { return }
                self.timerActive = active
                self.scheduleVisibilityUpdate()
            }
            .store(in: &cancellables)

        // Подхватываем изменение переключателя из окна настроек.
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let stored = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
                if stored != self.isEnabled { self.isEnabled = stored }
            }
            .store(in: &cancellables)
    }

    /// Откладываем показ/скрытие на следующий виток runloop,
    /// чтобы не трогать окна внутри цикла обновления SwiftUI.
    private func scheduleVisibilityUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.applyVisibility()
        }
    }

    private func applyVisibility() {
        let visible = isEnabled && timerActive
        guard let vm else { return }
        if visible {
            let panels = panelsIfNeeded(vm: vm)
            panels.chip.orderFront(nil)
            panels.controls.orderFront(nil)
        } else {
            chipPanel?.orderOut(nil)
            controlPanel?.orderOut(nil)
        }
    }

    private func panelsIfNeeded(vm: TimerViewModel) -> (chip: OverlayPanel, controls: OverlayPanel) {
        if let chipPanel, let controlPanel { return (chipPanel, controlPanel) }

        let chip = OverlayPanel(
            autosaveName: "overlay.chip",
            defaultRect: Self.defaultRect(width: 150, height: 50, offsetY: -40),
            dragAnywhere: true
        )
        chip.contentView = DraggableHostingView(rootView: TimerChipView(vm: vm))

        let controls = OverlayPanel(
            autosaveName: "overlay.controls",
            defaultRect: Self.defaultRect(width: 150, height: 46, offsetY: -100)
        )
        controls.contentView = DraggableHostingView(rootView: ControlPanelView(vm: vm))

        chipPanel = chip
        controlPanel = controls
        return (chip, controls)
    }

    /// Дефолтная позиция — правый верхний угол основного экрана.
    private static func defaultRect(width: CGFloat, height: CGFloat, offsetY: CGFloat) -> NSRect {
        guard let screen = NSScreen.main?.visibleFrame else {
            return NSRect(x: 200, y: 600, width: width, height: height)
        }
        return NSRect(
            x: screen.maxX - width - 24,
            y: screen.maxY + offsetY - height,
            width: width, height: height
        )
    }
}
